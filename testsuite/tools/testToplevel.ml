(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*            David Allsopp, University of Cambridge & Tarides            *)
(*                                                                        *)
(*   Copyright 2024 David Allsopp Ltd.                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

open Harness.Import

(* This test verifies that a series of libraries can be loaded in a toplevel.
   Any failures cause the script to be aborted. *)
let run config env mode =
  let toplevel = Environment.tool_path env mode "ocaml" "ocamlnat" in
  Format.printf "Testing loading of libraries in %a\n%!"
                (Environment.pp_path env) toplevel;
  let test_libraries_in_toplevel libraries =
    let has_c_stubs =
      (* Generate a test script for loading each library in a separate toplevel
         instance. *)
      Out_channel.with_open_text "test_install_script.ml" (fun oc ->
        let has_c_stubs =
          List.fold_left (fun c_bindings library ->
            (* Prior to #10476 (4.14.0) errors coming from directives didn't
               cause a non-zero exit code for a script (hence a failing #load
               isn't sufficient) - the script therefore attempts to "ignore" a
               known value in the library, which triggers an actual error. *)
            let symbol, archive, directory =
              match library with
              | "bigarray" ->
                  "Bigarray.kind_size_in_bytes", library, None
              | "dynlink" ->
                  if mode = Bytecode then
                    "Dynlink.loadfile", library, None
                  else
                    (* Prior to the removal of compiler plugins by #2276 in
                       OCaml 4.09.0, using Dynlink in ocamlnat was somewhat
                       ambiguous! *)
                    "Compdynlink.loadfile", library, Some "compiler-libs"
              | "graphics" ->
                  "Graphics.open_graph", library, None
              | "raw_spacetime_lib" ->
                  "Raw_spacetime_lib.Annotation.to_int", library, None
              | "str" ->
                  "Str.quote", library, None
              | "threads" ->
                  "Thread.self", library, Some "threads"
              | "unix" ->
                  "Unix.stat", library, None
              | "vmthreads" ->
                  "Thread.self", "threads", Some "vmthreads"
              | _ -> assert false
            in
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
                      Harness.fail_because
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
            let directory =
              Option.map (Printf.sprintf "#directory \"+%s\";;\n") directory
              |> Option.value ~default:""
            in
            Printf.fprintf oc
              "%s#load \"%s.%s\";;\n\
               if Obj.is_block (Obj.repr %s) then\n\
                 print_endline \"Loaded %s.%s\";;"
              directory archive ext symbol library ext;
            (c_bindings
             || (mode = Bytecode
                 && library <> "dynlink"
                 && library <> "bigarray"))) false libraries
        in
        Printf.fprintf oc "#quit;;\n";
        has_c_stubs)
    in
    let args =
      ["-noinit"; "-no-version"; "-noprompt"; "test_install_script.ml"]
    in
    let expected_exit_code =
      (* Systems configured with --disable-shared can't load bytecode libraries
         which need C stubs *)
      if Sys.cygwin && mode = Native && List.mem "unix" libraries
      || Sys.win32 && mode = Native && List.mem "threads" libraries
      || has_c_stubs && not Config.supports_shared_libraries then
        (* cf. ocaml/flexdll#146 - Cygwin's ocamlnat can't load unix.cmxs and
           the lines above will have triggered native Windows being unable to
           load threads.cmxs *)
        2
      else
        0
    in
    let exit_code, output =
      (* In the Renamed phase, the ocaml binary will only be able to start if
         the launcher searches for ocamlrun (as the Windows executable launcher
         does). CAML_LD_LIBRARY_PATH will need to be set if any of the libraries
         being loaded need C stubs. Finally, Config.standard_library will still
         point to the Original location, requiring OCAMLLIB to be set for the
         toplevel to start at all. *)
      Environment.run_process
        ~fails:(expected_exit_code <> 0)
        ~runtime:(mode = Bytecode && not config.launcher_searches_for_ocamlrun)
        ~stdlib:(config.has_relative_libdir = None) env toplevel args
    in
    Environment.display_output output;
    if exit_code <> expected_exit_code then
      Harness.fail_because "%s was expected to exit with code %d"
                           toplevel expected_exit_code;
    Sys.remove "test_install_script.ml"
  in
  let libraries =
    if mode = Bytecode then
      config.libraries
    else
      (* The vmthreads library is a bytecode-only library *)
      List.filter (fun l -> not (List.mem "vmthreads" l)) config.libraries
  in
  List.iter test_libraries_in_toplevel libraries
