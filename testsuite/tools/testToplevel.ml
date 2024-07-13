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

(* This test verifies that a series of libraries can be loaded in a toplevel.
   Any failures cause the script to be aborted. *)
let run (config : Installation.t) env mode =
  let toplevel = Environment.tool_path env mode "ocaml" "ocamlnat" in
  Format.printf "Testing loading of libraries in %a\n%!"
                (Environment.pp_path env) toplevel;
  let test_libraries_in_toplevel libraries =
    let has_c_stubs =
      Out_channel.with_open_text "test_install_script.ml" (fun oc ->
        let has_c_stubs =
          List.fold_left (fun c_bindings library ->
            let ext =
              match mode with
              | Native ->
                  if library = "dynlink" then
                    (* dynlink.cmxs does not exist, for obvious reasons, but we
                       can check loading the library in ocamlnat "works". *)
                    "cmxa"
                  else if library = "threads" then
                    let threads_plugin =
                      let plugin = Filename.concat "threads" "threads.cmxs" in
                      Environment.in_libdir env plugin
                    in
                    if Sys.file_exists threads_plugin then
                      Environment.fail_because
                        "threads.cmxs is not expected to exist"
                    else if Sys.win32 then
                      (* cf. note in ocaml/ocaml#13520 - threads.cmxa is
                         correctly compiled assuming winpthreads is statically
                         in the same image (so without defining
                         WINPTHREADS_USE_DLLIMPORT), but this is incorrect for
                         threads.cmxs, as threads.cmxs may load more than 2GiB
                         away from the main executable. For native Windows, it's
                         not possible to rely on ocamlnat's automatic
                         cmxa -> cmxs recompilation. *)
                      "cmxs"
                    else
                      (* cf. ocaml/ocaml#12250 - no threads.cmxs *)
                      "cmxa"
                  else
                    "cmxs"
              | Bytecode ->
                  "cma"
            in
            Printf.fprintf oc
              "#directory \"+%s\";;\n\
               #load \"%s.%s\";;\n\
               print_endline \"Loaded %s.%s\";;"
            library library ext library ext;
            (c_bindings
             || (library <> "dynlink" && mode = Bytecode))) false libraries
        in
        Printf.fprintf oc "#quit;;\n";
        has_c_stubs)
    in
    let args =
      ["-noinit"; "-no-version"; "-noprompt"; "test_install_script.ml"]
    in
    let expected_exit_code =
      if Sys.cygwin && mode = Native && List.mem "unix" libraries
      || Sys.win32 && mode = Native && List.mem "threads" libraries
      || has_c_stubs && not Config.supports_shared_libraries then
        (* cf. ocaml/flexdll#146 - Cygwin's ocamlnat can't load unix.cmxs and
           the lines above will have triggered native Windows being unable to
           load threads.cmxs *)
        125
      else
        0
    in
    let exit_code, output =
      Environment.run_process Return
        ~fails:(expected_exit_code <> 0)
        ~runtime:(mode = Bytecode && not config.launcher_searches_for_ocamlrun)
        ~stdlib:(config.has_relative_libdir = None) env toplevel args
    in
    Environment.display_output output;
    if exit_code <> expected_exit_code then
      Environment.fail_because "%s was expected to exit with code %d"
                               toplevel expected_exit_code;
    Sys.remove "test_install_script.ml"
  in
  List.iter test_libraries_in_toplevel config.libraries
