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

let is_executable =
  if Sys.win32 then
    Fun.const true
  else
    fun binary ->
      try Unix.access binary [Unix.X_OK]; true
      with Unix.Unix_error _ -> false

(* XXX The comment here needs writing! *)
let run (config : Installation.t) env =
  let bindir = Environment.bindir env in
  Format.printf "\nTesting bytecode binaries in %a\n"
                (Environment.pp_path env) bindir;
  let exec_magic =
    let ocamlrun = Environment.ocamlrun env in
    Environment.run_process Return env ocamlrun ["-M"]
  in
  let test_binary binary =
    if String.starts_with ~prefix:"ocaml" binary
    || String.starts_with ~prefix:"flexlink" binary then
    let program = Filename.concat bindir binary in
    if is_executable program then
      let classification = Environment.classify_executable program in
      if classification <> Vanilla then
        let fails =
          (* After the prefix has been renamed, bytecode executables compiled
             with -custom will still work. Otherwise, the header needs to be
             able to search for ocamlrun and, if applicable, ocamlrun needs to
             be able to load C stubs (which will only happen if the runtime
             locates the Standard Library using a relative directory, so that it
             can find ld.conf) *)
          Environment.is_renamed env
          && match classification with
             | Tendered {dlls; _} ->
                 not config.launcher_searches_for_ocamlrun
                 || dlls && config.has_relative_libdir = None
             | _ ->
                 false
        in
        match Environment.run_process Return ~fails env program ["-vnum"] with
        | (0, output) when not fails ->
            Environment.display_output output;
            if Sys.win32 && Filename.extension binary = ".exe" then
              (* This additional part of the test ensures that the executable
                 launcher on Windows can correctly hand-over to ocamlrun on
                 Windows. The check is that a binary named ocamlc.byte.exe
                 can be invoked as ocamlc.byte. -M is used as a previous bug
                 caused ocamlc.byte to act solely as ocamlrun, the test being
                 that ocamlrun -M returning the runtime's magic number would
                 be likely distinct from the behaviour of any of the
                 distribution's tools when called with -M. *)
              let without_exe = Filename.remove_extension binary in
              let (this_exit_code, _) as this =
                let fails =
                  without_exe <> "ocamlmklib"
                  && not (String.contains without_exe '.')
                in
                Environment.run_process Return ~fails env
                                        program ~argv0:without_exe ["-M"]
              in
              if this_exit_code = 0 then
                if this = exec_magic then
                  let (that_exit_code, _) as that =
                    let fails = without_exe <> "ocamlmklib" in
                    Environment.run_process Return ~fails env
                                            program ~argv0:binary ["-M"]
                  in
                  if this = that then
                    Environment.fail_because
                      "Neither %s nor %s seem to load the bytecode image"
                      without_exe binary
                  else if that_exit_code = 0 then
                    Environment.fail_because
                      "%s is not expected to return with exit code 0"
                      binary
                  else if not (String.contains without_exe '.') then
                    Environment.fail_because
                      "%s is not expected to return the exec magic number!"
                      without_exe
                  else () (* Expected outcome was the exec magic number *)
                else if without_exe <> "ocamlmklib" then
                  Environment.fail_because
                    "%s is expected to return with a non-zero exit code"
                    without_exe
                else () (* Expected outcome is a zero exit code *)
              else if without_exe = "ocamlmklib" then
                Environment.fail_because
                  "%s is expected to return with exit code 0"
                  without_exe
              else () (* Expected outcome is a non-zero exit code *)
        | _ ->
            if not fails then
              Environment.fail_because "it was broken"
  in
  let binaries = Sys.readdir bindir in
  Array.sort String.compare binaries;
  Array.iter test_binary binaries
