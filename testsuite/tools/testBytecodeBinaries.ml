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

(* Test for executable bit on files *)
let is_executable =
  if Sys.win32 then
    Fun.const true
  else
    fun binary ->
      try Unix.access binary [Unix.X_OK]; true
      with Unix.Unix_error _ -> false

(* Look for all executables in $bindir/flexlink* and $bindir/ocaml*. All the
   distribution binaries support the -vnum flag, so it's used as a check that
   the launchers are operating correctly. Some additional testing is done on
   Windows checking the behaviour of running foo versus foo.exe *)
let run config env =
  let bindir = Environment.bindir env in
  Format.printf "\nTesting bytecode binaries in %a\n"
                (Environment.pp_path env) bindir;
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
        match Environment.run_process ~fails env program ["-vnum"] with
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
              let (_exit_code, _output) =
                Environment.run_process
                  ~fails:true env program ~argv0:without_exe ["-M"] in ()
        | _ ->
            if not fails then
              Harness.fail_because "%s: not expected to have failed" program
  in
  let binaries = Sys.readdir bindir in
  Array.sort String.compare binaries;
  Array.iter test_binary binaries
