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

let run_tests ~sh (config : Installation.t) env =
  TestDynlink.run config env Bytecode;
  if config.has_ocamlopt && Config.supports_shared_libraries then
    TestDynlink.run config env Native;
  TestToplevel.run config env Bytecode;
  if config.has_ocamlnat then
    TestToplevel.run config env Native;
  Test_ld_conf.run config env;
  TestBytecodeBinaries.run config env;
  TestLinkModes.run ~sh config env

(*
(* Parse the command line, with the following results:
   - bindir, config, libdir and verbose come directly from the command line
   - prefix, bindir_suffix and libdir_suffix are derived from bindir and libdir.
     bindir and libdir must exist and share a common prefix (i.e. there must be
     some prefix /foo or C:\foo which they share) as otherwise it's not possible
     to rename the installation directory. prefix is thus the common prefix of
     bindir and libdir and [Filename.concat prefix bindir_suffix = bindir], etc.
   - relocatable and target_relocatable are respectively true if the compiler
     and the binaries the compiler produces are relocatable. At present, no
     compiler is either relocatable or can produce relocatable binaries *)
(* XXX Get these variables elsewhere, given the leaking of libdir in ld.conf *)
let _orig_bindir, _orig_libdir, prefix, bindir_suffix, libdir_suffix, config,
    test_root, test_root_logical, bytecode_shebangs_by_default, reproducible,
    pp_path, verbose =
*)
let () =
  let ~config, ~pwd, ~prefix, ~bindir:_, ~bindir_suffix, ~libdir,
      ~libdir_suffix, ~summarise_only, ~pp_path, ~verbose =
    match Installation.parse_cmdline Sys.argv with
    | Result.Error (code, msg) ->
        prerr_string msg;
        exit code
    | Result.Ok result ->
        result
  in
  (* The build directory may contain symlinks, and if this is so then the
     reproducibility test must search for both the logical (symlinks not
     resolved) and physical forms. This is particularly relevant on FreeBSD,
     where /home is a symlink to /usr/home and matters because OCaml's
     debugging information writes the physical directory where GCC/clang
     writes the logical directory. The logical version of the current working
     directory would normally just be [Sys.getenv "PWD"] but that can't be
     relied on coming from GNU make, because the invocation of the harness is
     passed through [sh -c] which correctly resets PWD to getcwd() (which is
     the physical version). The logical cwd is therefore passed using the
     --pwd argument from the Makefile. *)
  let test_root, test_root_logical =
    let cwd = Sys.getcwd () in
    (* --pwd is ignored on Windows, since Sys.getcwd is automatically the
       logical CWD. *)
    if Sys.win32 then
      cwd, Unix.realpath cwd
    else
      pwd, cwd
  in
  let pp_path = pp_path ~test_root in
  let test_root_logical =
    if test_root_logical = test_root then
      None
    else
      Some test_root_logical
  in
  let libraries = List.sort Stdlib.compare config.libraries in
  let libraries =
    let add_dependencies = function
    | ["systhreads"] -> ["unix"; "threads"]
    | x -> x
    in
    List.map add_dependencies libraries
  in
  let style =
    if Sys.getenv_opt "GITHUB_ACTIONS" <> None
    || Sys.getenv_opt "APPVEYOR_BUILD_ID" <> None then
      Some Misc.Color.Always
    else
      None
  in
  Misc.Style.setup style;
  let no_markup ansi = { Misc.Style.ansi; text_close = ""; text_open = "" } in
  Misc.Style.(set_styles {
    warning = no_markup [Bold; FG Yellow];
    error = no_markup [Bold; FG Red];
    loc = no_markup [Bold; FG Blue];
      hint = no_markup [Bold; FG Green];
      inline_code = no_markup [FG Blue]});
  let runtime_launch_info =
    let file = Filename.concat libdir "runtime-launch-info" in
    Bytelink.read_runtime_launch_info file in
  let header_size =
    let {Bytelink.buffer; executable_offset; _} = runtime_launch_info in
    String.length buffer - executable_offset in
  let bytecode_shebangs_by_default =
    runtime_launch_info.launcher <> Bytelink.Executable in
  let launcher_searches_for_ocamlrun = Sys.win32 in
  let target_launcher_searches_for_ocamlrun = Sys.win32 in
  let config =
    {config with Installation.libraries;
                 launcher_searches_for_ocamlrun;
                 target_launcher_searches_for_ocamlrun;
                 bytecode_shebangs_by_default}
  in
  let relocatable = false in
  let reproducible =
    relocatable
    && (not config.has_ocamlopt
        || not Toolchain.assembler_embeds_build_path
        || Config.as_has_debug_prefix_map && Config.architecture <> "riscv")
    && not Toolchain.linker_embeds_build_path
    && (not Toolchain.c_compiler_always_embeds_build_path
        || not Toolchain.c_compiler_debug_paths_can_be_absolute)
  in
  let target_relocatable = false in
  let summary =
    let choose b t f = (if b then t else f), true in
    let puzzle = [
      "native and ", config.has_ocamlopt;
      "bytecode", true;
      " only", not config.has_ocamlopt;
      " for ", true;
      choose Config.supports_shared_libraries
             "shared and static linking"
             "static linking only";
      " with ocamlnat", config.has_ocamlnat
    ] in
    let summary =
      List.filter_map (fun (s, b) -> if b then Some s else None) puzzle
    in
    String.concat "" summary
  in
  let pp_relocatable f b =
    Format.fprintf f "@{<%s>%srelocatable@}"
      (if b then "hint" else "warning")
      (if b then "" else "not ")
  in
  let pp_reproducible f b =
    if b then
      Format.fprintf f " and @{<hint>reproducible@}"
  in
  Format.printf
    "@{<loc>Test Environment@}\n\
    \    @{<hint>prefix@} = %s\n\
    \    @{<hint>bindir@} = [$prefix/]%s\n\
    \    @{<hint>libdir@} = [$prefix/]%s\n\
    \  - C compiler is %s [%s] for %s\n\
    \  - OCaml is %a%a; target binaries by default are %a\n\
    \  - Executable header size is %.2fKiB (%d bytes)\n\
    \  - Testing %s\n@?"
       prefix bindir_suffix libdir_suffix
       Config.c_compiler Config.c_compiler_vendor Config.target
       pp_relocatable relocatable pp_reproducible reproducible
       pp_relocatable target_relocatable
       (float_of_int header_size /. 1024.0) header_size summary;
  if summarise_only then
    exit 0;
  (* Run all tests in the supplied prefix *)
  Compmisc.init_path ();
  if verbose then
    Clflags.verbose := true;
  let make_env =
    Environment.make pp_path ~verbose ~test_root ~test_root_logical in
  let env = make_env ~phase:Original ~prefix ~bindir_suffix ~libdir_suffix in
  let sh =
     match Environment.run_process Return ~quiet:true env
                                   "sh" ["-c"; "command -v sh"] with
     | (0, [where]) -> where
     | _ ->
         Environment.fail_because "Unexpected response from command -v sh"
  in
  let () = TestRelocation.run ~reproducible config env in
  let run_tests =
    run_tests ~sh config in
  let programs = run_tests env in
  (* Now rename the prefix, appending .new to the directory name *)
  let new_prefix = prefix ^ ".new" in
(*
  let bindir = Filename.concat new_prefix bindir_suffix in
*)
  let libdir = Filename.concat new_prefix libdir_suffix in
  Format.printf "Renaming %a to %a\n\n%!" pp_path prefix
                                          pp_path new_prefix;
  Sys.rename prefix new_prefix;
  at_exit (fun () ->
    flush stderr;
    flush stdout;
    Format.printf "Restoring %a to %a\n" pp_path new_prefix
                                         pp_path prefix;
    Sys.rename new_prefix prefix);
  let env =
    make_env ~phase:Renamed ~prefix:new_prefix ~bindir_suffix ~libdir_suffix in
  (* Re-run the test programs compiled with the normal prefix *)
  Printf.printf "Re-running test programs\n%!";
  (* Finally re-run all of the tests with the new prefix *)
  List.iter
    (function `Some f -> assert (f env = `None) | `None -> ()) programs;
  Compmisc.reinit_path ~standard_library:libdir ();
  let programs = run_tests env in
  assert (List.for_all (function `None -> true | _ -> false) programs)
