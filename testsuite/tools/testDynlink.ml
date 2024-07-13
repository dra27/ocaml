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

open Environment.Import

(* This test verifies that a series of libraries can be loaded via Dynlink.
   Any failures will cause either an exception or a compilation error. *)
let run (config : Installation.t) env mode =
  Format.printf "\nTesting loading of libraries with %s dynlink\n"
                (if mode = Native then "native" else "bytecode");
  let test_program =
    Environment.in_test_root env (Toolchain.exe "test_script") in
  let compile_test_program () =
    Out_channel.with_open_text "test_install_script.ml" (fun oc ->
      Printf.fprintf oc {|
let load_library basename =
  let lib = Dynlink.adapt_filename (basename ^ ".cma") in
  let dir = Filename.concat %S basename in
  Dynlink.loadfile (Filename.concat dir lib);
  Printf.printf "Loaded %%s\n" lib

let () =
  let () = Dynlink.allow_unsafe_modules true in
  List.iter load_library (List.tl (Array.to_list Sys.argv))
|} (Environment.libdir env)
    );
    flush stdout;
    let compiler = Environment.tool_path env mode "ocamlc" "ocamlopt" in
    let args = [
      "-I"; "+dynlink"; Environment.lib mode "dynlink"; "-linkall";
      "-o"; test_program; "test_install_script.ml"
    ] in
    let files = [
      test_program;
      "test_install_script.ml";
      "test_install_script.cmi";
      "test_install_script.cm" ^ (if mode = Native then "x" else "o")
    ] in
    let files =
      if mode = Native then
        ("test_install_script" ^ Config.ext_obj)::files
      else
        files in
    let compile ?(custom = false) () =
      if Sys.file_exists test_program then
        Environment.erase_file test_program;
      let args = if custom then "-custom" :: args else args in
      let runtime =
        mode = Bytecode && Installation.ocamlc_fails_after_rename config in
      let stdlib = config.has_relative_libdir = None in
      Environment.run_process Execute ~runtime ~stdlib env compiler args in
    compile ();
    files, compile
  in
  let test_libraries_in_prog ?expected_exit_code env libraries =
    let has_c_stubs library = (mode = Bytecode && library <> "dynlink") in
    let has_c_stubs = List.exists has_c_stubs libraries in
    let runtime =
      mode = Bytecode
      && expected_exit_code = None
      && not config.target_launcher_searches_for_ocamlrun
      && config.has_relative_libdir = None
    in
    let stubs =
      has_c_stubs
      && expected_exit_code = None
      && Config.supports_shared_libraries
      && config.has_relative_libdir = None
    in
    let expected_exit_code =
      match expected_exit_code with
      | Some code -> code
      | None ->
          if (Sys.cygwin && mode = Native && List.mem "unix" libraries)
             || (not Config.supports_shared_libraries && has_c_stubs) then
            (* cf. ocaml/flexdll#146 - Cygwin's natdynlink can't load
                   unix.cmxs *)
            2
          else
            0
    in
    let exit_code, output =
      Environment.run_process Return
        ~fails:(expected_exit_code <> 0) ~runtime ~stubs env
        test_program libraries
    in
    Environment.display_output output;
    if exit_code <> expected_exit_code then
      Environment.fail_because "%s is expected to return with exit code %d"
                               test_program expected_exit_code;
  in
  let test_libraries_in_prog ?expected_exit_code env libraries =
    if mode = Native && List.mem "threads" libraries then
      let threads_plugin =
        Environment.in_libdir env (Filename.concat "threads" "threads.cmxs")
      in
      if Sys.file_exists threads_plugin then
        Environment.fail_because "threads.cmxs is not expected to exist"
      else
        ()
    else
      test_libraries_in_prog ?expected_exit_code env libraries
  in
  let not_dynlink l = not (List.mem "dynlink" l) in
  let files, re_compile = compile_test_program () in
  let expected_exit_code =
    (* Relocatable OCaml bytecode executables launched using the executable
       header require caml_executable_name, or they end up being accidentally
       relative, since the exec call leaves argv[0] as being the bytecode image
       itself. *)
    if mode = Bytecode && config.has_relative_libdir <> None
       && Toolchain.no_caml_executable_name
       && Environment.launched_via_stub test_program then
      Some 2
    else
      None in
  let libraries = List.filter not_dynlink config.libraries in
  let () =
    List.iter (test_libraries_in_prog ?expected_exit_code env) libraries;
    if expected_exit_code <> None then
      let () = re_compile ~custom:true () in
      List.iter (test_libraries_in_prog env) libraries
  in
  List.iter Environment.erase_file files
