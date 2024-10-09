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
let make_env ?(ocamllib=false) bindir libdir =
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
  let bindings =
    if ocamllib then
      ("OCAMLLIB=" ^ libdir) :: bindings
    else
      bindings
  in
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

(* This test verifies that a series of libraries can be loaded in a toplevel.
   Any failures cause the script to be aborted. *)
let load_libraries_in_toplevel env ?runtime toplevel ext libraries =
  Printf.printf "\nTesting loading of libraries in %s\n%!" toplevel;
  Out_channel.with_open_text "test_install_script.ml" (fun oc ->
    List.iter (fun library ->
      (* dynlink.cmxs does not exist *)
      let ext =
        if library = "dynlink" && ext = "cmxs" then
          "cmxa"
        else
          ext
      in
      Printf.fprintf oc
        "#directory \"+%s\";;\n\
         #load \"%s.%s\";;\n\
         print_endline \"  Loaded %s.%s\";;"
      library library ext library ext) libraries;
    Printf.fprintf oc "#quit;;\n");
  let pid =
    let executable, args =
      match runtime with
      | Some runtime ->
          runtime, [| runtime; toplevel; "-noinit"; "-no-version"; "-noprompt";
                  "test_install_script.ml" |]
      | _ -> toplevel, [| toplevel; "-noinit"; "-no-version"; "-noprompt";
                  "test_install_script.ml" |]
    in
    Unix.create_process_env
      executable args
      env Unix.stdin Unix.stdout Unix.stderr
  in
  let result = Unix.waitpid [] pid in
  Sys.remove "test_install_script.ml";
  match result with
  | (_, Unix.WEXITED 0) -> ()
  | _ -> exit 1

(* This test verifies that a series of libraries can be loaded via Dynlink.
   Any failures will cause either an exception or a compilation error. *)
let load_libraries_in_prog env ?runtime ?target_runtime libdir compiler
                           native_compiler ~native libraries =
  Out_channel.with_open_text "test_install_script.ml" (fun oc ->
    let emit_library library =
      if library <> "dynlink" (*&& (not native || library <> "threads")*) then
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
    let executable, args =
      match runtime with
      | Some runtime when not native_compiler ->
          (* XXX All the dupl, etc. *)
          runtime, [| runtime; compiler; "-I"; "+dynlink"; dynlink; "-linkall";
                            "-o"; test_program; "test_install_script.ml" |]
      | _ ->
          compiler, [| compiler; "-I"; "+dynlink"; dynlink; "-linkall";
                            "-o"; test_program; "test_install_script.ml" |]
    in
    Unix.create_process_env
      executable args env Unix.stdin Unix.stdout Unix.stderr
  in
  let () =
    match Unix.waitpid [] pid with
    | (_, Unix.WEXITED 0) -> ()
    | _ ->
        print_endline "Unexpected compiler error";
        exit 1
  in
  let pid =
    (* XXX Code dup with toplevels etc. *)
    let executable, args =
      match target_runtime with
      | None -> test_program, [| test_program |]
      | Some runtime -> runtime, [| runtime; test_program |]
    in
    Unix.create_process_env
      executable args env Unix.stdin Unix.stdout Unix.stderr
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

let classify_bytecode_image file =
  try
    In_channel.with_open_bin file (fun ic ->
      let start = really_input_string ic 2 in
      let is_RNTM = function
      | Bytesections.{name = Name.RNTM; _} -> true
      | _ -> false in
      let sections = Bytesections.(all (read_toc ic)) in
      if start = "#!" then
        `Shebang
      else if List.exists is_RNTM sections then
        `Launcher
      else
        `Custom)
  with End_of_file | Bytesections.Bad_magic_number ->
    `Bytecode_not_found

let print_process_status oc = function
| Unix.WEXITED n -> Printf.fprintf oc "exited with %d" n
| Unix.WSIGNALED _ -> output_string oc "signalled"
| Unix.WSTOPPED _ -> output_string oc "stopped"

(* This test verifies that a series of libraries can be loaded via Dynlink.
   Any failures will cause either an exception or a compilation error. *)
let test_bytecode_binaries ~full runtime_search env bindir =
  let test_binary binary =
    if String.starts_with ~prefix:"ocaml" binary
    || String.starts_with ~prefix:"flexlink" binary then
    let binary = Filename.concat bindir binary in
    if is_executable binary then
      match classify_bytecode_image binary with
      | `Bytecode_not_found -> ()
      | (`Shebang | `Launcher | `Custom) as kind ->
          Printf.printf "  Testing %s -vnum: %!" binary;
          try
            let pid =
              Unix.create_process_env binary [| binary; "-vnum" |]
              env Unix.stdin Unix.stdout Unix.stderr in
            let (_, result) = Unix.waitpid [] pid in
            let incorrect_status =
              if full then
                (* First time around, everything is supposed to work! *)
                result <> Unix.WEXITED 0
              else
                match kind with
                | `Custom ->
                    (* Executables compiled with -custom should work
                       regardless *)
                    result <> Unix.WEXITED 0
                | `Launcher ->
                    (* Second time around, the executable launchers should
                       fail *)
                    not runtime_search && result <> Unix.WEXITED 2
                | `Shebang ->
                    (* Second time around, the shebangs should all be broken so
                       Unix_error should already have been raised! *)
                    not runtime_search
            in
            if incorrect_status then begin
              Printf.eprintf "%s did not terminate as expected (%a)\n"
                             binary print_process_status result;
              exit 1
            end
          with Unix.Unix_error(_, "create_process", _) as e ->
            if full then
              raise e
            else
              Printf.printf "unable to run\n%!"
  in
  let binaries = Sys.readdir bindir in
  Printf.printf "\nTesting bytecode binaries in %s\n" bindir;
  Array.sort String.compare binaries;
  Array.iter test_binary binaries

let write_test_program description =
  Out_channel.with_open_text "test_install_script.ml" (fun oc ->
    Printf.fprintf oc {|
let state = bool_of_string Sys.argv.(1)

let is_directory dir =
  try Sys.is_directory dir
  with Sys_error _ -> false

let () =
  Printf.printf "  %s: %%s\n%%!" Config.standard_library;
  if is_directory Config.standard_library <> state then
    let () =
      Printf.eprintf "  *** Directory %%sfound!\n"
                     (if state then "not " else "")
    in
    exit 1
|} description)

let compile_with_options env compiler ~native ?runtime options
                         test_program description f =
  Printf.printf "  Compiling %s\n%!" description;
  write_test_program description;
  let test_program =
    Filename.concat (Unix.getcwd ()) (exe test_program) in
  let pid =
    let args =
      (compiler :: "-o" :: test_program :: "-I" :: "+compiler-libs" ::
       (if native then "ocamlcommon.cmxa" else "ocamlcommon.cma") ::
         "test_install_script.ml" :: options)
    in
    let executable, args =
      match runtime with
      | Some runtime ->
          runtime, runtime :: args
      | None ->
          compiler, args
    in
    Unix.create_process_env
      executable (Array.of_list args) env Unix.stdin Unix.stdout Unix.stderr
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

let compile_obj env standard_library compiler ~native ?runtime
                runtime_lib test_program description f =
  Printf.printf "  Compiling %s\n%!" description;
  write_test_program description;
  let test_program =
    Filename.concat (Unix.getcwd ()) (exe test_program) in
  let pid =
    let args = [
      compiler; "-o"; "test_install_ocaml" ^ Config.ext_obj;
      "-I"; "+compiler-libs"; "-output-obj";
      (if native then "ocamlcommon.cmxa" else "ocamlcommon.cma");
      "test_install_script.ml"
    ] in
    let executable, args =
      match runtime with
      | Some runtime ->
          runtime, runtime :: args
      | None ->
          compiler, args
    in
    Unix.create_process_env
      executable (Array.of_list args) env Unix.stdin Unix.stdout Unix.stderr
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
      \  return 0;\n\
       }\n");
  if Ccomp.compile_file ~standard_library "test_install_main.c" <> 0 then begin
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
        Config.native_c_libraries ^ " -lcomprmarsh "
          ^ Config.comprmarsh_c_libraries
      else
        Config.bytecomp_c_libraries in
    runtime_lib ^ " " ^ libraries
  in
  if Ccomp.call_linker Ccomp.Exe test_program objects flags <> 0 then begin
    print_endline "Unexpected linker error";
    exit 1
  end;
  List.iter Sys.remove files;
  Some (f test_program)

let compiler_where env ?runtime compiler =
  let from_compiler, stdout = Unix.pipe ~cloexec:true () in
  let executable, args =
    match runtime with
    | Some runtime ->
        runtime, [| runtime; compiler; "-where" |]
    | None ->
        compiler, [| compiler; "-where" |]
  in
  let pid =
    Unix.create_process_env
      executable args
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

let run_program env ?runtime test_program ~arg =
  let pid =
    try
      let pid =
        Unix.create_process_env
           test_program [| test_program; string_of_bool arg |]
                       env Unix.stdin Unix.stdout Unix.stderr
      in
      match runtime with
      | None -> pid
      | Some runtime ->
          (* We should get here if the program used the executable launcher, not
             a shebang *)
          let (_, result) = Unix.waitpid [] pid in
          if result <> Unix.WEXITED 2 then begin
            Printf.eprintf "%s did not terminate as expected (launcher %a)\n"
                           test_program print_process_status result;
            exit 1
          end;
          raise (Unix.Unix_error(Unix.ENOENT, "create_process", ""))
    with Unix.Unix_error(Unix.ENOENT, "create_process", _)
         when runtime <> None ->
      let runtime = Option.get runtime in
      Unix.create_process_env
         runtime [| runtime; test_program; string_of_bool arg |]
                     env Unix.stdin Unix.stdout Unix.stderr
  in
  let (_, result) = Unix.waitpid [] pid in
  if result <> Unix.WEXITED 0 then begin
    Printf.eprintf "%s did not terminate as expected (%a)\n"
                   test_program print_process_status result;
    exit 1
  end

(* XXX Code dup between these two paths *)
let compile_with_options ?(unix_only=false)
                         ?(supports_shared=true) ?(tendered=false)
                         ?(relative_libdir=false) ~full env
                         compiler ?(native_compiler=true) ~native ?runtime
                         options test_program description =
  if unix_only && Sys.win32 || not supports_shared
  || native && not native_compiler then
    None
  else
    let cont test_program ?runtime env ~arg =
      let runtime = if tendered then runtime else None in
      let arg = (relative_libdir && tendered) || arg in
      run_program env ?runtime test_program ~arg;
      if full then
        Some (fun ?runtime env ~arg ->
          let arg = (relative_libdir && tendered) || arg in
          let runtime = if tendered then runtime else None in
          run_program env ?runtime test_program ~arg;
          Sys.remove test_program;
          None)
      else
        (Sys.remove test_program; None)
    in
    compile_with_options
      env compiler ~native ?runtime options test_program description cont

let compile_obj ?(unix_only=false)
                ?(supports_shared=true) ~full env standard_library
                compiler ?(native_compiler=true) ~native ?runtime runtime_lib
                test_program description =
  if unix_only && Sys.win32 || not supports_shared
  || native && not native_compiler then
    None
  else
    let cont test_program ?runtime env ~arg =
      run_program env test_program ~arg;
      if full then
        Some (fun ?runtime env ~arg -> run_program env test_program ~arg;
        Sys.remove test_program;
        None)
      else
        (Sys.remove test_program; None)
    in
    compile_obj env standard_library compiler ~native ?runtime
                runtime_lib test_program description cont

(* This test verifies both that all compilation mechanisms are working and that
   each of these programs can correctly identify the Standard Library location.
   Any failures will cause either an exception or a compilation error. *)
let test_standard_library_location ~full env bindir libdir supports_shared
                                   native_compiler relative_libdir
                                   runtime_search runtime_search_target ocamlc
                                   ocamlopt =
  Printf.printf "\nTesting compilation mechanisms for %s\n%!" bindir;
  let runtime =
    if runtime_search || native_compiler then
      None
    else
      Some (exe (Filename.concat bindir "ocamlrun"))
  in
  let ocamlc_where = compiler_where env ?runtime ocamlc in
  let ocamlopt_where =
    if native_compiler then
      compiler_where env ocamlopt
    else
      "n/a"
  in
  Printf.printf "  ocamlc -where: %s\n  ocamlopt -where: %s\n%!"
                ocamlc_where ocamlopt_where;
  let unix_only = true in
  let tendered = true in
  (* With an absolute header, in bytecode-only mode, flexlink is a bytecode
     executable and cannot run in the second phase. *)
  let disabled_for_bytecode_only_windows =
    not full && Sys.win32 && not runtime_search && not native_compiler in
  let programs = List.filter_map Fun.id [
    (* XXX Shouldn't this more be that the test is expected to fail?? *)
    compile_with_options ~tendered ~relative_libdir ~full env ocamlc ?runtime
                         ~native:false
      [] "test_bytecode"
      "Bytecode (with tender)";
    compile_with_options ~full env ocamlc ?runtime ~native:false
      ~unix_only:disabled_for_bytecode_only_windows
      ["-custom"] "test_custom_static"
      "Bytecode (-custom static runtime)";
    compile_with_options
      ~unix_only ~supports_shared ~full env ocamlc ?runtime ~native:false
      ["-custom"; "-runtime-variant"; "_shared"] "test_custom_shared"
      "Bytecode (-custom shared runtime)";
    compile_obj ~full env libdir ocamlc ?runtime ~native:false
      "-lcamlrun" "test_output_obj_static"
      "Bytecode (-output-obj static runtime)";
    compile_obj
      ~unix_only ~supports_shared ~full env libdir ocamlc ?runtime ~native:false
      "-lcamlrun_shared" "test_output_obj_shared"
      "Bytecode (-output-obj shared runtime)";
    compile_with_options ~full env ocamlc ?runtime ~native:false
      ~unix_only:disabled_for_bytecode_only_windows
      ["-output-complete-exe"] "test_output_complete_exe_static"
      "Bytecode (-output-complete-exe static runtime)";
    compile_with_options
      ~unix_only ~supports_shared ~full env ocamlc ?runtime ~native:false
      ["-output-complete-exe"; "-runtime-variant"; "_shared"]
      "test_output_complete_exe_shared"
      "Bytecode (-output-complete-exe shared runtime)";
    compile_with_options ~full env ocamlopt ~native_compiler ~native:true
      [] "test_native_static"
      "Native (static runtime)";
    compile_obj ~full env libdir ocamlopt ~native_compiler ~native:true
      "-lasmrun" "test_native_output_obj_static"
      "Native (-output-obj static runtime)";
    compile_obj
      ~unix_only ~supports_shared ~full env libdir ocamlopt ~native_compiler
      ~native:true
      "-lasmrun_shared" "test_native_output_obj_shared"
      "Native (-output-obj shared runtime)";
  ] in
  let runtime =
    if runtime_search_target || full then
      None
    else
      Some (exe (Filename.concat bindir "ocamlrun"))
  in
  Printf.printf "Running programs\n%!";
  List.filter_map (fun f -> f ?runtime env ~arg:true) programs

(* XXX ~full is more the phase - have we renamed the root, etc. *)
let run_tests ~full env bindir libdir supports_shared test_ocamlnat
              native_compiler relative_libdir runtime_search
              runtime_search_target libraries =
  let libraries = sort_libraries libraries in
  let ocaml = exe (Filename.concat bindir "ocaml") in
  let ocamlnat = exe (Filename.concat bindir "ocamlnat") in
  let ocamlc = exe (Filename.concat bindir "ocamlc") in
  let ocamlopt = exe (Filename.concat bindir "ocamlopt") in
  let runtime =
    if full || runtime_search then
      None
    else
      Some (exe (Filename.concat bindir "ocamlrun"))
  in
  let target_runtime =
    if full || runtime_search_target then
      None
    else
      Some (exe (Filename.concat bindir "ocamlrun"))
  in
  if supports_shared then begin
    load_libraries_in_toplevel env ?runtime ocaml "cma" libraries end;
  if test_ocamlnat then
    load_libraries_in_toplevel env ocamlnat "cmxs" libraries;
  if supports_shared then
    load_libraries_in_prog env ?runtime ?target_runtime libdir ocamlc
      native_compiler ~native:false libraries;
  if native_compiler && supports_shared then
    load_libraries_in_prog env libdir ocamlopt native_compiler ~native:true
      libraries;
  (*if full then*)
    test_bytecode_binaries ~full runtime_search env bindir;
  test_standard_library_location
    ~full env bindir libdir supports_shared native_compiler relative_libdir
    runtime_search runtime_search_target ocamlc ocamlopt

let rec split_dir acc dir =
  let dirname = Filename.dirname dir in
  if dirname = dir then
    dir::acc
  else
    split_dir (Filename.basename dir :: acc) dirname

let join_dir = function
| dir::dirs -> List.fold_left Filename.concat dir dirs
| [] -> assert false

let rec split_to_prefix prefix bindir libdir =
  match bindir, libdir with
  | (dir1::bindir'), (dir2::libdir') ->
      if dir1 = dir2 then
        split_to_prefix (dir1::prefix) bindir' libdir'
      else
        join_dir (List.rev prefix), join_dir bindir, join_dir libdir
  | [], _
  | _, [] ->
      assert false

let () =
  Compmisc.init_path ();
  if Array.length Sys.argv < 4 then begin
    Printf.eprintf
      "Usage: test_install <bindir> <libdir> <yes|no> [<library1> ...]\n";
    exit 2
  end else
    let libraries =
      Array.to_list (Array.sub Sys.argv 9 (Array.length Sys.argv - 9)) in
    let bindir = Sys.argv.(1) in
    let libdir = Sys.argv.(2) in
    let supports_shared = bool_of_string Sys.argv.(3) in
    let test_ocamlnat = bool_of_string Sys.argv.(4) in
    let native_compiler = bool_of_string Sys.argv.(5) in
    let relative_libdir = bool_of_string Sys.argv.(6) in
    let runtime_search = bool_of_string Sys.argv.(7) in
    let runtime_search_target = bool_of_string Sys.argv.(8) in
    let env = make_env bindir libdir in
    let programs =
      run_tests
        ~full:true env bindir libdir supports_shared test_ocamlnat
          native_compiler relative_libdir runtime_search runtime_search_target
          libraries in
    let prefix, bindir_suffix, libdir_suffix =
      split_to_prefix [] (split_dir [] bindir) (split_dir [] libdir) in
    let new_prefix = prefix ^ ".new" in
    let bindir = Filename.concat new_prefix bindir_suffix in
    let libdir = Filename.concat new_prefix libdir_suffix in
    Printf.printf "\nRenaming %s to %s\n\n%!" prefix new_prefix;
    Sys.rename prefix new_prefix;
    at_exit (fun () ->
      flush stderr;
      flush stdout;
      Printf.printf "\nRestoring %s to %s\n" new_prefix prefix;
      Sys.rename new_prefix prefix);
    Printf.printf "Re-running test programs\n%!";
    (* On re-running the test programs, the Standard Library should _not_
       exist (because the programs were not compiled relocatably) *)
    let env = make_env bindir libdir in
    let runtime =
      if runtime_search_target then
        None
      else
        Some (exe (Filename.concat bindir "ocamlrun"))
    in
    List.iter (fun f -> assert (f ?runtime env ~arg:false = None)) programs;
    (*List.iter Sys.remove programs;*)
    let env = make_env ~ocamllib:(not relative_libdir) bindir libdir in
    Compmisc.init_path ~standard_library:libdir ();
    let programs =
      run_tests
        ~full:false env bindir libdir supports_shared test_ocamlnat
          native_compiler relative_libdir runtime_search runtime_search_target
          libraries
    in
    assert (programs = [])
