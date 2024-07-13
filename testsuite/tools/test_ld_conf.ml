(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*                        David Allsopp, Tarides                          *)
(*                                                                        *)
(*   Copyright 2025 David Allsopp Ltd.                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

open Environment.Import

(* Tests for the handling of the DLL search path. *)
type ld_conf_test = {
  description: string;
    (* Test description (displayed if it fails or in verbose mode) *)
  caml_ld_library_path: var_setting;
    (* [Set l] sets CAML_LD_LIBRARY_PATH to be the entries of [l], concatenated
       with the separator appropriate to the platform. Note that [Blank] and
       [Set []] both set CAML_LD_LIBRARY_PATH to [""] *)
  ocamllib: var_setting;
    (* [Set l] causes the entries of [l] to be written to an ld.conf in a
       directory whose location is put in OCAMLIB. [Empty] only sets OCAMLLIB to
       [""]. *)
  camllib: var_setting;
    (* As for ocamllib, but using the CAMLLIB environment variable directory.
       A different temporary directory is used from OCAMLLIB (i.e. both CAMLLIB
       and OCAMLLIB can be set). *)
  stdlib: string list;
    (* As for ocamllib and camllib, but for the ld.conf in the Standard Library
       directory (the file is erased if the list is empty). *)
  outcome: string list;
    (* The expect result from [ocamlrun -config] / [Dll.init_compile false] *)
}
and var_setting = Unset | Empty | Set of string list

let compile_ld_conf_test_programs (config : Installation.t) env =
  let write_ld_conf_test_driver () =
    Out_channel.with_open_text "test_install_script.ml" (fun oc ->
      output_string oc {|
(* Known issue: Sys.getenv processes blank environment variables differently
   from _wgetenv *)
let () =
  if Sys.win32 then
    assert (Sys.getenv_opt "CAMLLIB" <> Some ""
            && Sys.getenv_opt "OCAMLLIB" <> Some "")

let () =
  let print s =
    (* Known issue: ocamlrun -config suppresses blank lines on Windows *)
    if s <> "" then
      print_endline s
    else if not Sys.win32 then
      print_endline "."
  in
  Dll.init_compile false;
  List.iter print (Dll.search_path ())
|})
  in
  let compile_test_program mode files test_program description =
    (* The test driver simply calls Dll.init_compile to trigger the processing
       and then prints the resulting search path to standard output. *)
    let test_program =
      Environment.in_test_root env (Toolchain.exe test_program) in
    let compiler = Environment.tool_path env mode "ocamlc" "ocamlopt" in
    let args = [
      "-I"; "+compiler-libs";
      Environment.lib mode "ocamlcommon"; Environment.lib mode "ocamlbytecomp";
      "-o"; test_program; "test_install_script.ml"
    ] in
    let runtime =
      mode = Bytecode && Installation.ocamlc_fails_after_rename config in
    let stdlib = config.has_relative_libdir = None in
    Environment.run_process Execute ~runtime ~stdlib env compiler args;
    let files = test_program :: files in
    let files =
      if mode = Native then
        "test_install_script.cmx"
        :: ("test_install_script" ^ Config.ext_obj)
        :: files
      else
        "test_install_script.cmo" :: files
    in
    let runtime =
      mode = Bytecode
      && not config.target_launcher_searches_for_ocamlrun
      && config.has_relative_libdir = None in
    let run run_process test =
      let code, lines =
        run_process ~runtime test_program []
      in
      if code = 0 then
        let lines =
          (* Known issues:
             - Misc.split_path_contents ignores empty strings where
               caml_decompose_path does not
             - Sys.getenv can't return empty environment variables on Windows,
               but _wgetenv can
             - Windows strips out the blank entries in the search path
               (somewhat counterintuitively!) *)
          if not Sys.win32 && (test.caml_ld_library_path = Set []
                               || test.caml_ld_library_path = Empty) then
            "." :: lines
          else
            lines
        in
        description :: lines
      else
        Environment.fail_because "%s is expected to exit with code 0"
                                 test_program
    in
    run, files
  in
  let files = ["test_install_script.ml"; "test_install_script.cmi"] in
  let () = write_ld_conf_test_driver () in
  let byte, files =
    compile_test_program Bytecode files "test_ld_conf.byte" "ocamlc.byte"
  in
  if config.has_ocamlopt then
    let opt, files =
      compile_test_program Native files "test_ld_conf.opt" "ocamlc.opt"
    in
    [byte; opt], files
  else
    [byte], files

(* This test tests the processing of ld.conf by ocamlrun (which processes it in
   order to load stub libraries referenced by a bytecode image's DLLS section)
   and ocamlc (which processes it in order to determine the primitives made
   available by stub libraries referenced by .cma files). The test ensures that
   both implementations are producing the same results. *)
let run (config : Installation.t) env =
  let pp_path = Environment.pp_path env in
  print_endline "\nTesting processing of ld.conf";
  let remove_if_exists file =
    if Sys.file_exists file then
      Sys.remove file
  in
  (* ld.conf is picked up from $OCAMLLIB, $CAMLLIB or from the pre-configured
     default location of the standard library (this is why the test can only be
     performed in-prefix). During the test, temporary directories are created to
     be used for $OCAMLLIB and $CAMLLIB to point to if needed which can then
     have temporary ld.conf files placed in them. The ld.conf in libdir is
     backed up and restored after the test. *)
  let ocamlrun_config run_process _test =
    let ocamlrun = Environment.ocamlrun env in
    let code, lines =
      run_process ~runtime:false ocamlrun ["-config"] in
    if code = 0 then
      let strip s =
        let len = String.length s in
        if len < 2 || s.[0] <> ' ' || s.[1] <> ' ' then
          Environment.fail_because
            "Unexpected output from ocamlrun -config: %S" s
        else
          String.sub s 2 (len - 2)
      in
      let lines =
        List.rev lines
        |> List.take_while ((<>) "shared_libs_path:")
        |> List.rev_map strip
      in
      "ocamlrun -config" :: lines
    else
      Environment.fail_because
        "Unexpected exit code %d from ocamlrun -config" code
  in
  let programs, files = compile_ld_conf_test_programs config env in
  let programs = ocamlrun_config :: programs in
  let backed_up_ld_conf = Environment.in_libdir env "ld.conf.bak" in
  let libdir_ld_conf = Environment.in_libdir env "ld.conf" in
  let ocamllib_dir = Environment.in_test_root env "ocamllib" in
  let camllib_dir = Environment.in_test_root env "camllib" in
  let ocamllib_ld_conf = Filename.concat ocamllib_dir "ld.conf" in
  let camllib_ld_conf = Filename.concat camllib_dir "ld.conf" in
  let run_test test =
    Printf.printf "- %s\n" test.description;
    let () =
      if test.stdlib = [] then
        remove_if_exists libdir_ld_conf
      else
        Out_channel.with_open_bin libdir_ld_conf (fun oc ->
          output_string oc (String.concat "\n" test.stdlib))
    in
    let process_env dir ld_conf = function
    | Set dirs ->
        if dirs = [] && Sys.file_exists ld_conf then
          Sys.remove ld_conf
        else
          Out_channel.with_open_bin ld_conf (fun oc ->
            output_string oc (String.concat "\n" dirs));
        Some dir
    | Empty ->
        Some ""
    | Unset ->
        None
    in
    let caml_ld_library_path =
      match test.caml_ld_library_path with
      | Unset -> None
      | Empty -> Some []
      | Set l -> Some l
    in
    let ocamllib = process_env ocamllib_dir ocamllib_ld_conf test.ocamllib in
    let camllib = process_env camllib_dir camllib_ld_conf test.camllib in
    let run_process ~runtime program args =
      Environment.run_process_with_test_env
        Return ~runtime ~caml_ld_library_path ~ocamllib ~camllib env
          program args
    in
    match List.map (fun f -> f run_process test) programs with
    | [] -> assert false
    | (ocamlrun::rest) as results ->
        let pad_column l =
          let max =
            List.fold_left (fun a s -> Int.max a (String.length s)) 0 l
          in
          let f s = s ^ String.make (max - String.length s) ' ' ^ " | " in
          List.map f l
        in
        let display_results columns =
          assert (columns <> []);
          let columns =
            let format_string s =
              let s = Format.asprintf "%a" pp_path s in
              let s = Printf.sprintf "%S" s in
              String.sub s 1 (String.length s - 2)
            in
            List.map (fun column -> List.map format_string column) columns
          in
          let[@ocaml.warning "-8"] right :: rest = List.rev columns in
          let rec display rev_columns =
            let (row, _, finished), rev_columns =
              let f (row, rightmost, finished) = function
              | [] ->
                  assert false
              | hd::tl ->
                  let next =
                    if tl = [] then
                      if rightmost then
                        [""]
                      else
                        [String.make (String.length hd - 2) ' ' ^ "| "]
                    else
                      tl
                  in
                  (hd::row, false, finished && tl = []), next
              in
              List.fold_left_map f ([], true, true) rev_columns
            in
            Environment.display_output [String.concat "" row];
            if not finished then
              display rev_columns
          in
          display (right :: List.map pad_column rest)
        in
        if List.exists (fun r -> List.tl ocamlrun <> List.tl r) rest then begin
          display_results results;
          Environment.fail_because
            "All mechanisms should produce the same output"
        end else if List.tl ocamlrun <> test.outcome then begin
          display_results [ocamlrun; "Expected outcome"::test.outcome];
          Environment.fail_because "Output differs from the expected results"
        end else if Environment.verbose env then
          display_results (("Expected outcome"::test.outcome)::results)
  in
  let ensure_dir dir =
    if not (Sys.file_exists dir) then
      Sys.mkdir dir 0o775
    else if not (Sys.is_directory dir) then begin
      Sys.rmdir dir;
      Sys.mkdir dir 0o775
    end
  in
  let restore =
    let restored = ref false in
    fun () ->
      if not !restored then begin
        restored := true;
        Format.printf "Restoring %a to %a\n" pp_path backed_up_ld_conf
                                             pp_path libdir_ld_conf;
        remove_if_exists libdir_ld_conf;
        Sys.rename backed_up_ld_conf libdir_ld_conf
      end
  in
  let base =
    {description = "";
     caml_ld_library_path = Unset; ocamllib = Unset; camllib = Unset;
     stdlib = []; outcome = []}
  in
  let if_ld_conf_found outcome =
    (* ocamlrun can only find ld.conf after the prefix has been renamed if it's
       configured with --with-relative-libdir *)
    if Environment.is_renamed env && config.has_relative_libdir = None then
      []
    else
      outcome
  in
  (* Batch 1: various interesting kinds of line, tested when read through
     CAML_LD_LIBRARY_PATH and ld.conf *)
  let tests =
    let main, main_outcome, main_outcome_cr =
      let libdir =
        if Environment.is_renamed env then
          Environment.libdir env
        else
          Config.standard_library in
      let libdir =
        if config.has_relative_libdir = None then
          libdir
        else
          try Unix.realpath libdir
          with Invalid_argument _ -> libdir in
      let (/) = Filename.concat in
      let data = [
        (* Root directory (both forms) preserved *)
        "/", "/", None;
        "//", "//", None;
        (* Current and Parent directory names *)
        ".", libdir / "", None;
        "..", libdir / "..", None;
        (* Current and Parent directory names with OS-default trailing separator
           (i.e. ./ and ../ on Unix and .\ and ..\ on Windows) *)
        "." / "", libdir / "", None;
        ".." / "", libdir / ".." / "", None;
        (* "stublibs" relative to the Current and Parent directory (using OS-
           default separator) *)
        "." / "stublibs", libdir / "stublibs", None;
        ".." / "stublibs", libdir / ".." / "stublibs", None;
        (* Other cases - implicit and absolute entries, and entries beginning
           with the Current and Parent directory names *)
        "stublibs", "stublibs", None;
        ".stublibs", ".stublibs", None;
        "..stublibs", "..stublibs", None;
        libdir, libdir, None;
        "/lib/ocaml", "/lib/ocaml", Some "/lib/ocaml\r";
      ] in
      let fold (main, main_outcome, main_outcome_cr) (line, outcome, cr) =
        let cr = Option.value ~default:outcome cr in
        line::main, outcome::main_outcome, cr::main_outcome_cr
      in
      List.fold_left fold ([], [], []) (List.rev data)
    in
    let tests =
      (* Various test lines above all fed via ld.conf in the Standard Library *)
      let outcome =
        (* Known issue: Windows strips out the blank entries in the search path
           (somewhat counterintuitively!) *)
        if Sys.win32 then
          main_outcome
        else
          "." :: main_outcome
      in
      [{base with description = "Base ld.conf test";
                  stdlib = "" :: main;
                  outcome = if_ld_conf_found outcome}] in
    let tests =
      (* As first, but with the same entries in CAML_LD_LIBRARY_PATH too *)
      let stdlib =
        if Sys.win32 then
          (* Known issue: Windows ignores empty entries in the search path, and
             it's slightly easier to test this only once in this test *)
          main
        else
          "" :: main
      in
      (* Part of the outcome from ld.conf *)
      let outcome_ld_conf =
        if Sys.win32 then
          main_outcome
        else
          "." :: main_outcome
      in
      (* Part of the outcome from CAML_LD_LIBRARY_PATH *)
      let outcome_caml_ld_library_path =
        if Sys.win32 then
          (* No blank entry at the start: Windows returns the same entries *)
          main
        else
          (* Unix displays "." for the blank, but otherwise returns the same
             entries *)
          "." :: main
      in
      {base with description = "Base ld.conf + CAML_LD_LIBRARY_PATH";
                 caml_ld_library_path = Set stdlib;
                 stdlib;
                 outcome = outcome_caml_ld_library_path
                             @ if_ld_conf_found outcome_ld_conf} :: tests in
    let tests =
      (* As first, but with entries in CAML_LD_LIBRARY_PATH including quotes and
         separators. No effect on Unix, as the colon separator is always
         expressly prohibited in PATH-like environment variables, but the semi-
         colon separator in Windows PATH-like environment variables is permitted
         and quoting rules are actively used on Windows systems. *)
      let caml_ld_library_path, outcome_caml_ld_library_path =
        let entries = [
          (* Quote characters should be stripped (it's a common misconception on
             Windows systems, but space characters do not require quoting in
             PATH-like variables, but often are.
             Result should be: quoted *)
          {|"quoted"|}, [{|"quoted"|}];
          (* Quote characters should be stripped internally too.
             Result should be: quoteinentry *)
          {|quote"in"entry|}, [{|quote"in"entry|}];
          (* Quote characters should protect separators.
             Result should be: one;entry *)
          {|one";"entry|}, [{|one"|}; {|"entry|}];
          (* The final quote character is optional.
             Result should be: one;two;three *)
          {|one";"two";three|}, [{|one"|}; {|"two"|}; "three"];
        ] in
        let test, windows_outcome =
          List.split entries
        in
        if Sys.win32 then
          test, List.flatten windows_outcome
        else
          test, test
      in
      {base with description = "Base ld.conf + quoted CAML_LD_LIBRARY_PATH";
                 caml_ld_library_path = Set caml_ld_library_path;
                 stdlib = main;
                 outcome = outcome_caml_ld_library_path
                             @ if_ld_conf_found main_outcome} :: tests in
    let tests =
      (* As first, but with a CR at the end of each line *)
      let outcome =
        (* Known issue: Windows strips out the blank entries in the search
           path (somewhat counterintuitively!) *)
        if Sys.win32 then
          main_outcome_cr
        else
          "." :: main_outcome_cr
      in
      {base with description = "Base ld.conf with CRLF endings";
                 stdlib = List.map (Fun.flip (^) "\r") ("" :: main);
                 outcome = if_ld_conf_found outcome} :: tests in
    tests
  in
  (* Batch 2: effects of empty (vs unset) environment variables *)
  let tests =
    let tests =
      (* Empty CAML_LD_LIBRARY_PATH should add "." to the start of the search
         path *)
      let outcome_caml_ld_library_path =
        if Sys.win32 then
          []
        else
          ["."]
      in
      {base with description = "Empty CAML_LD_LIBRARY_PATH";
                 caml_ld_library_path = Empty;
                 stdlib = ["ld.conf"];
                 outcome = outcome_caml_ld_library_path
                             @ if_ld_conf_found ["ld.conf"]} :: tests in
    let tests =
      (* Embedded empty entries in CAML_LD_LIBRARY_PATH should add equivalent
         "." entries to the search path *)
      let outcome_caml_ld_library_path =
        if Sys.win32 then
          []
        else
          ["."; "."]
      in
      {base with description = "Embedded empty entry in CAML_LD_LIBRARY_PATH";
            caml_ld_library_path = Set [""; ""];
            stdlib = ["ld.conf"];
            outcome = outcome_caml_ld_library_path
                        @ if_ld_conf_found ["ld.conf"]} :: tests in
    let ld_conf_outcome = if_ld_conf_found ["masked-stdlib"] in
    let tests =
      (* An empty CAMLLIB shouldn't hide ld.conf in the Standard Library *)
      {base with description = "Empty CAMLLIB";
                 caml_ld_library_path = Set ["env"];
                 camllib = Empty;
                 stdlib = ["masked-stdlib"];
                 outcome = "env" :: ld_conf_outcome} :: tests in
    let tests =
      (* An empty OCAMLLIB shouldn't hide ld.conf in either the Standard Library
         or CAMLLIB\ld.conf *)
      {description = "Empty OCAMLLIB";
       caml_ld_library_path = Set ["env"];
       ocamllib = Empty;
       camllib = Set ["masked-camllib"];
       stdlib = ["masked-stdlib"];
       outcome = ["env"; "masked-camllib"] @ ld_conf_outcome} :: tests in
    tests
  in
  (* Batch 3: load priority, embedded NUL characters, EOL-at-EOF, etc. *)
  let tests =
    let ld_conf_outcome = if_ld_conf_found ["libdir"] in
    let tests =
      (* OCAMLLIB should have priority over CAMLLIB and the Standard Library *)
      {description = "$OCAMLLIB/ld.conf";
       caml_ld_library_path = Set ["env"];
       ocamllib = Set ["ocamllib\000"; "hidden"];
       camllib = Set ["camllib\000"; "hidden"];
       stdlib = ["libdir"];
       outcome = ["env"; "ocamllib"; "camllib"] @ ld_conf_outcome} :: tests in
    let tests =
      (* CAMLLIB should have priority over the Standard Library *)
      {base with description = "$CAMLLIB/ld.conf";
                 caml_ld_library_path = Set ["env"];
                 camllib = Set ["camllib\000"; "hidden"];
                 stdlib = ["libdir"];
                 outcome = ["env"; "camllib"] @ ld_conf_outcome} :: tests in
    let tests =
      (* EOL-at-EOF should not add a blank entry to the search path *)
      {base with description = "EOF-at-EOF";
            stdlib = (if Sys.win32 then ["libdir\r\n"] else ["libdir\n"]);
            outcome = ld_conf_outcome} :: tests in
    tests
  in
  ensure_dir ocamllib_dir;
  ensure_dir camllib_dir;
  Format.printf "Backing up %a to %a\n" pp_path libdir_ld_conf
                                        pp_path backed_up_ld_conf;
  Sys.rename libdir_ld_conf backed_up_ld_conf;
  at_exit restore;
  List.iter run_test (List.rev tests);
  remove_if_exists ocamllib_ld_conf;
  remove_if_exists camllib_ld_conf;
  Sys.rmdir ocamllib_dir;
  Sys.rmdir camllib_dir;
  restore ();
  List.iter Environment.erase_file files
