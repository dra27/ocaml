(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*                        David Allsopp, Tarides                          *)
(*                                                                        *)
(*   Copyright 2024 David Allsopp Ltd.                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

module StringSet = Set.Make(String)

let exe =
  if Sys.win32 then
    Fun.flip (^) ".exe"
  else
    Fun.id

let is_path =
  if Sys.win32 then
    fun name -> String.lowercase_ascii name = "path"
  else
    String.equal "PATH"

let scrub =
  StringSet.of_list [
    "BUILD_PATH_PREFIX_MAP";
    "CAMLLIB";
    "CAMLRUNPARAM";
    "CAML_LD_LIBRARY_PATH";
    "OCAMLLIB";
    "OCAMLPARAM";
    "OCAMLRUNPARAM";
    "OCAMLTOP_INCLUDE_PATH";
    "OCAML_RUNTIME_EVENTS_DIR";
    "OCAML_RUNTIME_EVENTS_PRESERVE";
    "OCAML_RUNTIME_EVENTS_START";
  ]

(* Returns an environment where any variables in scrub have been removed and
   with effectively PATH=$bindir:$PATH and
   LD_LIBRARY_PATH=$libdir:$LD_LIBRARY_PATH on Unix or
   PATH=$bindir;$libdir;$PATH on Windows. *)
let make_env bindir libdir =
  let keep binding =
    let equals = String.index binding '=' in
    let name = String.sub binding 0 equals in
    let value =
      String.sub binding (equals + 1) (String.length binding - equals - 1) in
    if StringSet.mem name scrub then
      None
    else if is_path name then
      if Sys.win32 then
        if String.index_opt bindir ';' <> None then
          Some (Printf.sprintf "%s=\"%s\";%s" name bindir value)
        else
          Some (Printf.sprintf "%s=%s;%s" name bindir value)
      else
        Some (Printf.sprintf "%s=%s:%s" name bindir value)
    else if not Sys.win32 && name = "LD_LIBRARY_PATH" then
      Some (Printf.sprintf "%s=%s:%s" name libdir value)
    else
      Some binding
  in
  let bindings =
    List.filter_map keep (Array.to_list (Unix.environment ())) in
  let bindings =
    if Sys.win32
    || List.exists (String.starts_with ~prefix:"LD_LIBRARY_PATH=") bindings then
      bindings
    else
      ("LD_LIBRARY_PATH=" ^ libdir)::bindings in
  Array.of_list bindings

(* Return the list of otherlibs in a dependency-compatible order *)
let sort_libraries libraries =
  let compare l r =
    if l = "unix" && r = "threads" then
      -1
    else if l = "threads" && r = "unix" then
      1
    else
      String.compare l r
  in
  List.map (function "systhreads" -> "threads" | lib -> lib) libraries
  |> List.sort compare

let load_libraries_in_toplevel env toplevel ext libraries =
  Printf.printf "\nTesting loading of libraries in %s\n%!" toplevel;
  Out_channel.with_open_text "test_install_script.ml" (fun oc ->
    List.iter (fun library ->
      Printf.fprintf oc
        "#directory \"+%s\";;\n\
         #load \"%s.%s\";;\n\
         print_endline \"  Loaded %s.%s\";;"
      library library ext library ext) libraries;
    Printf.fprintf oc "#quit;;\n");
  let pid =
    Unix.create_process_env
      toplevel [| toplevel; "-noinit"; "-no-version"; "-noprompt";
                  "test_install_script.ml" |]
      env Unix.stdin Unix.stdout Unix.stderr
  in
  let result = Unix.waitpid [] pid in
  Sys.remove "test_install_script.ml";
  match result with
  | (_, Unix.WEXITED 0) -> ()
  | _ -> exit 1

let load_libraries_in_prog env libdir compiler ~native libraries =
  Out_channel.with_open_text "test_install_script.ml" (fun oc ->
    let emit_library library =
      if library <> "dynlink" && (not native || library <> "threads") then
        let libdir = Filename.concat libdir library in
        let library = library ^ ".cma" in
        let lib = Filename.concat libdir library in
        Printf.fprintf oc
          "  Dynlink.loadfile (Dynlink.adapt_filename %S);\n\
          \  Printf.printf \"  Loaded %%s\\n\" (Dynlink.adapt_filename %S);"
          lib library

    in
    Printf.fprintf oc
      "let () =\n\
      \  let () = Dynlink.allow_unsafe_modules true in\n\
      \  print_endline \"\\nTesting loading of libraries with %s dynlink.\";\n"
      (if native then "native" else "bytecode");
    List.iter emit_library libraries;
  );
  flush stdout;
  let test_program =
    Filename.concat (Unix.getcwd ()) (exe "test_install_script") in
  let pid =
    let dynlink = if native then "dynlink.cmxa" else "dynlink.cma" in
    Unix.create_process_env
      compiler [| compiler; "-I"; "+dynlink"; dynlink; "-linkall";
                            "-o"; test_program; "test_install_script.ml" |]
      env Unix.stdin Unix.stdout Unix.stderr
  in
  let () =
    match Unix.waitpid [] pid with
    | (_, Unix.WEXITED 0) -> ()
    | _ ->
        print_endline "Unexpected compiler error";
        exit 1
  in
  let pid =
    Unix.create_process_env
      test_program [| test_program |] env Unix.stdin Unix.stdout Unix.stderr
  in
  let (_, result) = Unix.waitpid [] pid in
  let files = [
    test_program;
    "test_install_script.ml";
    "test_install_script.cmi";
    "test_install_script.cm" ^ (if native then "x" else "o")
  ] in
  let files =
    if native then
      ("test_install_script" ^ Config.ext_obj) :: files
    else
     files in
  List.iter Sys.remove files;
  if result <> Unix.WEXITED 0 then
    exit 1

let is_executable =
  if Sys.win32 then
    Fun.const true
  else
    fun binary ->
      try Unix.access binary [Unix.X_OK]; true
      with Unix.Unix_error _ -> false

let is_bytecode file =
  In_channel.with_open_bin file (fun ic ->
    let len = in_channel_length ic in
    if len >= String.length Config.exec_magic_number then begin
      seek_in ic (len - String.length Config.exec_magic_number);
      input_line ic = Config.exec_magic_number
    end else
      false)

let test_bytecode_binaries env bindir =
  let test_binary binary =
    if String.starts_with ~prefix:"ocaml" binary
    || String.starts_with ~prefix:"flexlink" binary then
    let binary = Filename.concat bindir binary in
    if is_executable binary && is_bytecode binary then begin
      Printf.printf "  Testing %s -vnum: %!" binary;
      let pid =
        Unix.create_process_env binary [| binary; "-vnum" |]
        env Unix.stdin Unix.stdout Unix.stderr in
      if not (snd (Unix.waitpid [] pid) = Unix.WEXITED 0) then
        exit 1
    end
  in
  let binaries = Sys.readdir bindir in
  Printf.printf "\nTesting bytecode binaries in %s\n" bindir;
  Array.sort String.compare binaries;
  Array.iter test_binary binaries

let compile_with_options env compiler ~native options
                         test_program description f =
  Printf.printf "  Compiling %s\n%!" description;
  Out_channel.with_open_text "test_install_script.ml" (fun oc ->
    Printf.fprintf oc
      "let () =\n\
      \  Printf.printf \"  %s: %%s\\n\" Config.standard_library\n" description);
  let test_program =
    Filename.concat (Unix.getcwd ()) (exe test_program) in
  let pid =
    let args = Array.of_list
      (compiler :: "-o" :: test_program :: "-I" :: "+compiler-libs" ::
       (if native then "ocamlcommon.cmxa" else "ocamlcommon.cma") ::
         "test_install_script.ml" :: options)
    in
    Unix.create_process_env
      compiler args env Unix.stdin Unix.stdout Unix.stderr
  in
  let () =
    match Unix.waitpid [] pid with
    | (_, Unix.WEXITED 0) -> ()
    | _ ->
        print_endline "Unexpected compiler error";
        exit 1
  in
  let files = [
    "test_install_script.ml";
    "test_install_script.cmi";
    "test_install_script.cm" ^ (if native then "x" else "o")
  ] in
  let files =
    if native then
      ("test_install_script" ^ Config.ext_obj) :: files
    else
     files in
  List.iter Sys.remove files;
  Some (f test_program)

let compile_obj env compiler ~native runtime test_program description f =
  Printf.printf "  Compiling %s\n%!" description;
  Out_channel.with_open_text "test_install_script.ml" (fun oc ->
    Printf.fprintf oc
      "let () =\n\
      \  Printf.printf \"  %s: %%s\\n\" Config.standard_library\n" description);
  let test_program =
    Filename.concat (Unix.getcwd ()) (exe test_program) in
  let pid =
    let args = [|
      compiler; "-o"; "test_install_ocaml" ^ Config.ext_obj;
      "-I"; "+compiler-libs"; "-output-obj";
      (if native then "ocamlcommon.cmxa" else "ocamlcommon.cma");
      "test_install_script.ml"
    |] in
    Unix.create_process_env
      compiler args env Unix.stdin Unix.stdout Unix.stderr
  in
  let () =
    match Unix.waitpid [] pid with
    | (_, Unix.WEXITED 0) -> ()
    | _ ->
        print_endline "Unexpected compiler error";
        exit 1
  in
  Out_channel.with_open_text "test_install_main.c" (fun oc ->
    output_string oc
      "#define CAML_INTERNALS\n\
       #include <caml/callback.h>\n\
       \n\
       int main_os(int argc, char_os **argv)\n\
       {\n\
      \  caml_startup(argv);\n\
      \  caml_shutdown();\n\
       }\n");
  if Ccomp.compile_file "test_install_main.c" <> 0 then begin
    print_endline "Unexpected C compiler error";
    exit 1
  end;
  let files = [
    "test_install_script.ml";
    "test_install_script.cmi";
    "test_install_script.cm" ^ (if native then "x" else "o");
    "test_install_ocaml" ^ Config.ext_obj;
    "test_install_main.c";
    "test_install_main" ^ Config.ext_obj
  ] in
  let files =
    if native then
      ("test_install_script" ^ Config.ext_obj) :: files
    else
     files in
  let objects = [
    "test_install_ocaml" ^ Config.ext_obj;
    "test_install_main" ^ Config.ext_obj
  ] in
  let flags =
    let libraries =
      if native then
        Config.native_c_libraries ^ " " ^ Config.comprmarsh_c_libraries
      else
        Config.bytecomp_c_libraries in
    runtime ^ " -lcomprmarsh " ^ libraries
  in
  if Ccomp.call_linker Ccomp.Exe test_program objects flags <> 0 then begin
    print_endline "Unexpected linker error";
    exit 1
  end;
  List.iter Sys.remove files;
  Some (f test_program)

let compiler_where env compiler =
  let from_compiler, stdout = Unix.pipe ~cloexec:true () in
  let pid =
    Unix.create_process_env
      compiler [| compiler; "-where" |]
      env Unix.stdin stdout Unix.stderr
  in
  let ic = Unix.in_channel_of_descr from_compiler in
  In_channel.set_binary_mode ic false;
  let where = input_line ic in
  Unix.close from_compiler;
  if snd (Unix.waitpid [] pid) = Unix.WEXITED 0 then
    where
  else begin
    Printf.eprintf "Unexpected response from %s -where\n" compiler;
    exit 1
  end

let run_program env test_program =
  let pid =
    Unix.create_process_env
      test_program [| test_program |] env Unix.stdin Unix.stdout Unix.stderr
  in
  let (_, result) = Unix.waitpid [] pid in
  if result <> Unix.WEXITED 0 then begin
    Printf.eprintf "%s did not terminate as expected\n" test_program;
    exit 1
  end

let compile_with_options ?(unix_only=false) env
                         compiler ~native options test_program description =
  if unix_only && Sys.win32 then
    None
  else
    let cont test_program () =
      run_program env test_program;
      Some test_program
    in
    compile_with_options
      env compiler ~native options test_program description cont

let compile_obj ?(unix_only=false) env
                compiler ~native runtime test_program description =
  if unix_only && Sys.win32 then
    None
  else
    let cont test_program () =
      run_program env test_program;
      Some test_program
    in
    compile_obj env compiler ~native runtime test_program description cont

let test_standard_library_location env bindir libdir ocamlc ocamlopt =
  Printf.printf "\nTesting compilation mechanisms for %s\n%!" bindir;
  let ocamlc_where = compiler_where env ocamlc in
  let ocamlopt_where = compiler_where env ocamlopt in
  Printf.printf "  ocamlc -where: %s\n  ocamlopt -where: %s\n%!"
                ocamlc_where ocamlopt_where;
  let unix_only = true in
  let programs = List.filter_map Fun.id [
    compile_with_options env ocamlc ~native:false
      [] "test_bytecode"
      "Bytecode (with tender)";
    compile_with_options env ocamlc ~native:false
      ["-custom"] "test_custom_static"
      "Bytecode (-custom static runtime)";
    compile_with_options ~unix_only env ocamlc ~native:false
      ["-custom"; "-runtime-variant"; "_shared"] "test_custom_shared"
      "Bytecode (-custom shared runtime)";
    compile_obj env ocamlc ~native:false
      "-lcamlrun" "test_output_obj_static"
      "Bytecode (-output-obj static runtime)";
    compile_obj ~unix_only env ocamlc ~native:false
      "-lcamlrun_shared" "test_output_obj_shared"
      "Bytecode (-output-obj shared runtime)";
    compile_with_options env ocamlc ~native:false
      ["-output-complete-exe"] "test_output_complete_exe_static"
      "Bytecode (-output-complete-exe static runtime)";
    compile_with_options ~unix_only env ocamlc ~native:false
      ["-output-complete-exe"; "-runtime-variant"; "_shared"]
      "test_output_complete_exe_shared"
      "Bytecode (-output-complete-exe shared runtime)";
    compile_with_options env ocamlopt ~native:true
      [] "test_native_static"
      "Native (static runtime)";
    compile_obj env ocamlopt ~native:true
      "-lasmrun" "test_native_output_obj_static"
      "Native (-output-obj static runtime)";
    compile_obj ~unix_only env ocamlopt ~native:true
      "-lasmrun_shared" "test_native_output_obj_shared"
      "Native (-output-obj shared runtime)";
  ] in
  Printf.printf "Running programs\n%!";
  List.filter_map (fun f -> f ()) programs

let run_tests env bindir libdir libraries =
  let libraries = sort_libraries libraries in
  let ocaml = exe (Filename.concat bindir "ocaml") in
  let ocamlnat = exe (Filename.concat bindir "ocamlnat") in
  let ocamlc = exe (Filename.concat bindir "ocamlc") in
  let ocamlopt = exe (Filename.concat bindir "ocamlopt") in
  load_libraries_in_toplevel env ocaml "cma" libraries;
  load_libraries_in_toplevel env ocamlnat "cmxa" libraries;
  load_libraries_in_prog env libdir ocamlc ~native:false libraries;
  load_libraries_in_prog env libdir ocamlopt ~native:true libraries;
  test_bytecode_binaries env bindir;
  test_standard_library_location env bindir libdir ocamlc ocamlopt

let () =
  Compmisc.init_path ();
  if Array.length Sys.argv < 3 then begin
    Printf.eprintf "Usage: test_install <bindir> <libdir> [<library1> ...]\n";
    exit 2
  end else
    let libraries =
      Array.to_list (Array.sub Sys.argv 3 (Array.length Sys.argv - 3)) in
    let bindir = Sys.argv.(1) in
    let libdir = Sys.argv.(2) in
    let env = make_env bindir libdir in
    let programs = run_tests env bindir libdir libraries in
    List.iter Sys.remove programs
