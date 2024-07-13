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

(* Parse command line. Result is the globally-immutable configuration and the
   directories to use for bindir and libdir in both phases of the test. *)
type config = {
  supports_shared_libraries: bool;
    (* $(SUPPORTS_SHARED_LIBRARIES) - Makefile.config *)
  has_ocamlnat: bool;
    (* $(INSTALL_OCAMLNAT) - Makefile.build_config *)
  has_ocamlopt: bool;
    (* $(NATIVE_COMPILER) - Makefile.config *)
  has_relative_libdir: bool;
    (* $(RELATIVE_LIBDIR) - Makefile.build_config *)
  libraries: string list
    (* Sorted basenames of libraries to test.
        Derived from $(OTHERLIBRARIES) - Makefile.config *)
}

(* bindir, libdir and config come from the command line. Validate that bindir
   and libdir exist and share a common prefix (i.e. there is some prefix /foo
   or C:\foo which they share) as otherwise it's not possible to rename the
   installation directory. prefix is thus the common prefix of bindir and libdir
   and [Filename.concat prefix bindir_suffix = bindir], etc.
   *)
let bindir, libdir, prefix, bindir_suffix, libdir_suffix,
    config, relocatable, target_relocatable =
  (* Map directory names for otherlibs to library names and sort them in a
     dependency-compatible order. *)
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
  in
  let show_summary = ref false in
  let bindir = ref "" in
  let libdir = ref "" in
  let config =
    ref {supports_shared_libraries = false; has_ocamlnat = false;
         has_ocamlopt = false; has_relative_libdir = false; libraries = []}
  in
  let check_exists r dir =
    if Sys.file_exists dir then
      if Sys.is_directory dir then
        if Filename.is_relative dir then
          raise (Arg.Bad (dir ^ ": is not an absolute path"))
        else
          r := dir
      else
        raise (Arg.Bad (dir ^ ": not a directory"))
    else
      raise (Arg.Bad (dir ^ ": directory not found"))
  in
  let supports_shared_libraries supports_shared_libraries () =
    config := {!config with supports_shared_libraries}
  in
  let has_ocamlnat has_ocamlnat () = config := {!config with has_ocamlnat} in
  let has_ocamlopt has_ocamlopt () = config := {!config with has_ocamlopt} in
  let has_relative_libdir has_relative_libdir () =
    config := {!config with has_relative_libdir}
  in
  let args = Arg.align [
    "--bindir", Arg.String (check_exists bindir), "\
<bindir>\tDirectory containing programs (must share a prefix with --libdir)";
    "--libdir", Arg.String (check_exists libdir), "\
<libdir>\tDirectory containing stdlib.cma (must share a prefix with --bindir)";
    "--summary", Arg.Set show_summary, "";
    "--with-shared", Arg.Unit (supports_shared_libraries true), "\
\tInstallation supports shared libraries (*.dll/*.so can be used from OCaml)";
    "--without-shared", Arg.Unit (supports_shared_libraries false), "";
    "--with-ocamlnat", Arg.Unit (has_ocamlnat true), "\
\tNative toplevel (ocamlnat) is installed in the directory given in --bindir";
    "--without-ocamlnat", Arg.Unit (has_ocamlnat false), "";
    "--with-ocamlopt", Arg.Unit (has_ocamlopt true), "\
\tNative compiler (ocamlopt) is installed in the directory given in --bindir";
    "--without-ocamlopt", Arg.Unit (has_ocamlopt false), "";
    "--with-relative-libdir", Arg.Unit (has_relative_libdir true), "\
\tCompiler was configured with --enable-relative";
    "--without-relative-libdir", Arg.Unit (has_relative_libdir false), "";
  ] in
  let libraries lib =
    config := {!config with libraries = lib::config.contents.libraries}
  in
  let usage = "\n\
Usage: test_install --bindir <bindir> --libdir <libdir> <options> [libraries]\n\
options are:" in
  let error fmt =
    let f msg =
      Printf.eprintf "%s: %s\n" Sys.executable_name msg;
      if not !show_summary then
        Arg.usage args usage;
      exit 2
    in
    Printf.ksprintf f fmt
  in
  let split_to_prefix bindir libdir =
    let rec split_dir acc dir =
      let dirname = Filename.dirname dir in
      if dirname = dir then
        dir::acc
      else
        split_dir (Filename.basename dir :: acc) dirname
    in
    let rec loop prefix bindir libdir =
      match bindir, libdir with
      | (dir1::bindir), (dir2::libdir) ->
          if dir1 = dir2 then
            loop (dir1::prefix) bindir libdir
          else begin
            match List.rev prefix with
            | [] | [_] ->
              (* The prefix is either the root directory (/, C:\, etc.) or, on
                 Windows, the two directories are actually on different drives
               *)
              error "\
directories given for --bindir and --libdir do not have a common prefix";
            | dir::dirs ->
                List.fold_left Filename.concat dir dirs,
                List.fold_left Filename.concat dir1 bindir,
                List.fold_left Filename.concat dir2 libdir
          end
      | [], _ ->
          error "directory given for --libdir inside that given for --bindir"
      | _, [] ->
          error "directory given for --bindir inside that given for --libdir"
    in
    loop [] (split_dir [] bindir) (split_dir [] libdir) in
  Arg.parse args libraries usage;
  let config =
    {!config with libraries = sort_libraries config.contents.libraries}
  in
  let {contents = bindir} = bindir in
  let {contents = libdir} = libdir in
  let relocatable = false in
  let target_relocatable = false in
  if bindir = "" || libdir = "" then
    let () = Arg.usage args usage in
    exit 2
  else
    let prefix, bindir_suffix, libdir_suffix = split_to_prefix bindir libdir in
    let style =
      if Sys.getenv_opt "GITHUB_ACTIONS" <> None
      || Sys.getenv_opt "APPVEYOR_BUILD_ID" <> None then
        Some Misc.Color.Always
      else
        None
    in
    Misc.Style.setup style;
    if Sys.file_exists (prefix ^ ".new") then
      error "can't rename %s to %s.new as the latter already exists!"
      prefix prefix;
    let no_markup ansi = { Misc.Style.ansi; text_close = ""; text_open = "" } in
    Misc.Style.(set_styles {
      warning = no_markup [Bold; FG Yellow];
      error = no_markup [Bold; FG Red];
      loc = no_markup [Bold; FG Blue];
      hint = no_markup [Bold; FG Green];
      inline_code = no_markup [FG Blue]});
    let summary =
      let choose b t f = (if b then t else f), true in
      let puzzle = [
        "native and ", config.has_ocamlopt;
        "bytecode", true;
        " only", not config.has_ocamlopt;
        " for ", true;
        choose config.supports_shared_libraries
               "shared and static linking"
               "static linking only";
        " with ocamlnat", config.has_ocamlnat
      ] in
      let summary =
        List.filter_map (fun (s, b) -> if b then Some s else None) puzzle
      in
      String.concat "" summary
    in
    if !show_summary then
      exit 0;
    Format.printf
      "@{<loc>Test Environment@}\n\
      \  @{<hint>prefix@} = %s\n\
      \  @{<hint>bindir@} = [$prefix/]%s\n\
      \  @{<hint>libdir@} = [$prefix/]%s\n\
       Compiler is " prefix bindir_suffix libdir_suffix;
    if relocatable then
      Format.printf "@{<hint>relocatable@}; binaries produced are "
    else
      Format.printf "@{<warning>not relocatable@}; binaries produced are ";
    if target_relocatable then
      Format.printf "@{<hint>relocatable@}\n"
    else
      Format.printf "@{<warning>not relocatable@}\n";
    Format.printf "Testing %s\n%!" summary;
    bindir, libdir, prefix, bindir_suffix, libdir_suffix,
    config, relocatable, target_relocatable

let test_root = Sys.getcwd ()

module Filename = struct
  include Filename

  let is_dir_sep =
    if Sys.win32 then
      function '\\' | '/' -> true | _ -> false
    else
      (=) '/'
end

module String = struct
  include String

  let remove_prefix ~prefix s =
    if starts_with ~prefix s then
      let l = String.length prefix in
      Some (String.sub s l (String.length s - l))
    else
      None

  let find s p =
    let max = length s - 1 in
    if max = -1 then
      None
    else
      let rec loop i =
        if p s.[i] then
          Some i
        else if i < max then
          loop (succ i)
        else
          None
      in
      loop 0
end

(* Jump through some mildly convoluted hoops to create diff'able output.
   [display_path path] applies the following transformations:
     - ["$bindir"] or ["$libdir"] if [path] is exactly [bindir_suffix] or
       [libdir_suffix] (this captures passing those two variabes to the test
       programs)
     - if [path] begins with [prefix] then the text is replaced with ["$prefix"]
       (which can create ["$prefix.new/"], etc.). Additionally, if the next part
       of [path] after the following directory separator is [bindir_suffix] or
       [libdir_suffix] then this is replaced with ["$bindir"] or ["$libdir"]
       (i.e. this can generate ["$prefix.new/$bindir"] but not
       ["$prefix.new/foo/$bindir"]
     - if [path] begins [test_root] (i.e. the current directory) then this
       is replaced with [Filename.current_dir_name] as long as [path] is either
       exactly [test_root] or [test_root] is followed by a directory separator
       (i.e. it generates ["./"] but never [".new/"])
   Both simpler and more convoluted ways of doing this are available. *)
let display_path f path =
  match String.remove_prefix ~prefix path with
  | Some remainder ->
      if remainder = "" then
        Format.pp_print_string f "$prefix"
      else begin
        match String.find remainder Filename.is_dir_sep with
        | None ->
            Format.fprintf f "$prefix%s" remainder
        | Some idx ->
            let suffix, path =
              let idx = idx + 1 in
              let suffix = String.sub remainder 0 idx in
              let path =
                String.sub remainder idx (String.length remainder - idx)
              in
              suffix, path
            in
            match String.remove_prefix ~prefix:bindir_suffix path with
            | Some path when path = "" || Filename.is_dir_sep path.[0] ->
                Format.fprintf f "$prefix%s$bindir%s" suffix path
            | _ ->
                match String.remove_prefix ~prefix:libdir_suffix path with
                | Some path when path = "" || Filename.is_dir_sep path.[0] ->
                    Format.fprintf f "$prefix%s$libdir%s" suffix path
                | _ ->
                    Format.pp_print_string f ("$prefix" ^ remainder)
      end
  | None ->
      match String.remove_prefix ~prefix:test_root path with
      | Some path when path = "" || Filename.is_dir_sep path.[0] ->
          Format.pp_print_string f (Filename.current_dir_name ^ path)
      | _ ->
          if path = libdir_suffix then
            Format.pp_print_string f "$libdir"
          else if path = bindir_suffix then
            Format.pp_print_string f "$bindir"
          else
            Format.pp_print_string f path

type bytecode_classification = [
| `Not_tendered_bytecode (* Produced by ocamlopt, -output-complete-exe, etc. *)
| `Shebang  (* Launched using #! header *)
| `Launcher (* Launched using the executable launcher *)
| `Custom   (* Compiled with -custom *)
]

let classify_bytecode_image file : bytecode_classification =
  try
    In_channel.with_open_bin file (fun ic ->
      let start = really_input_string ic 2 in
      let is_RNTM = function
      | Bytesections.{name = Name.RNTM; _} -> true
      | _ -> false
      in
      let sections = Bytesections.(all (read_toc ic)) in
      if start = "#!" then
        `Shebang
      else if List.exists is_RNTM sections then
        `Launcher
      else
        `Custom)
  with End_of_file | Bytesections.Bad_magic_number ->
    `Not_tendered_bytecode

let fail_because fmt =
  let f s =
    prerr_endline s;
    exit 1
  in
  Format.ksprintf f fmt

type _ output =
| Stdout : unit output
| Return : (int * string list) output

let print_process_status () = function
| Unix.WEXITED n -> "exited with " ^ string_of_int n
| Unix.WSIGNALED _ -> "signalled"
| Unix.WSTOPPED _ -> "stopped"

module Environment : sig
  type t

  val make : ?ocamllib:bool -> string -> string -> t

  val run_process :
    'a output
      -> ?runtime:string -> string -> string list -> ?no_stderr:bool -> t -> 'a

  val run_process_target :
    'a output
      -> ?runtime:string -> string -> string list -> ?no_stderr:bool -> t -> 'a
end = struct
  type t = {
    env: string array;
    serial: int;
    bindir: string;
    libdir: string;
    set_OCAMLLIB: bool;
  }

  module StringSet = Set.Make(String)

  (* List of environment variables to remove from the calling environment *)
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

    (* Tests whether the name of an environment variable is in fact PATH,
       masking the fact that environment variable names are case-insensitive on
       Windows. *)
  let is_path_env =
    if Sys.win32 then
      fun name -> String.lowercase_ascii name = "path"
    else
      String.equal "PATH"

  let environments = Hashtbl.create 15

  let ld_library_path_name =
    if Config.system = "macosx" then
      "DYLD_LIBRARY_PATH"
    else
      "LD_LIBRARY_PATH"

  (* Returns an environment where any variables in scrub have been removed and
     with effectively PATH=$bindir:$PATH and
     LD_LIBRARY_PATH=$libdir:$LD_LIBRARY_PATH on Unix or
     DYLD_LIBRARY_PATH=$libdir$:DYLD_LIBRARY_PATH on macOS or
     PATH=$bindir;$libdir;$PATH on Windows. *)
  let make ?(ocamllib=false) bindir libdir =
    let keep binding =
      let equals = String.index binding '=' in
      let name = String.sub binding 0 equals in
      let value =
        String.sub binding (equals + 1) (String.length binding - equals - 1)
      in
      if StringSet.mem name scrub then
        None
      else if is_path_env name then
        if Sys.win32 then
          if String.index_opt bindir ';' <> None then
            Some (Printf.sprintf "%s=\"%s\";%s" name bindir value)
          else
            Some (Printf.sprintf "%s=%s;%s" name bindir value)
        else
          Some (Printf.sprintf "%s=%s:%s" name bindir value)
      else if not Sys.win32 && name = ld_library_path_name then
        Some (Printf.sprintf "%s=%s:%s" name libdir value)
      else
        Some binding
    in
    let bindings = List.filter_map keep (Array.to_list (Unix.environment ())) in
    let bindings =
      if Sys.win32
      || List.exists (String.starts_with ~prefix:(ld_library_path_name ^ "="))
                     bindings then
        bindings
      else
        (ld_library_path_name ^ "=" ^ libdir)::bindings
    in
    let bindings =
      if ocamllib then begin
        assert (not relocatable);
        ("OCAMLLIB=" ^ libdir)::bindings
      end else
        bindings
    in
    let env = Array.of_list bindings in
    try {env; serial = Hashtbl.find environments env; bindir; libdir;
         set_OCAMLLIB = ocamllib}
    with Not_found ->
      let serial = Hashtbl.length environments + 1 in
      Hashtbl.add environments env serial;
      {env; serial; bindir; libdir;
       set_OCAMLLIB = ocamllib}

  let null = Unix.openfile Filename.null [Unix.O_WRONLY] 0o200

  let last_environment = ref (-1)

  (* [run_process output_mode ?runtime program args ?no_stderr env] executes
     [program] with [args] (note that [args] does not need to include [program]
     at its head). If [no_stderr = true], then standard error is suppressed,
     otherwise anything output on standard error is interleaved with standard
     output. If [runtime] is given, then it is the full path to ocamlrun. In
     this case, if program is a bytecode image, then program is expected to fail
     (either with ENOENT, for a #!-style launcher or with exit code 2) and
     [run_process] retries, explicitly passing [program] to [runtime]. If
     [output_mode] is [Stdout], then ultimately the process must terminate with
     exit code 0, or the test harness aborts. If [output_mode] is [Return], then
     the final exit code is returned, along with the lines of output from the
     process.
     Both the processes potentially launched by this function are displayed on
     the console. If the environment is different from the last time
     [run_process] was called then a summary of the changes in it are also
     displayed. *)
  let rec run_process_aux ~to_stdout ?runtime program args ?(no_stderr = false)
                          ({env; _} as environment) =
    flush stderr;
    flush stdout;
    let captured_output = "process-output" in
    let stdout, stderr =
      let flags = Unix.([O_RDWR; O_CREAT; O_TRUNC; O_CLOEXEC]) in
      let fd = Unix.openfile captured_output flags 0o600 in
      fd, fd
    in
    let stderr = if no_stderr || runtime <> None then null else stderr in
    let runtime, classification =
      match runtime with
      | None ->
          "", `Not_tendered_bytecode
      | Some runtime ->
          let classification = classify_bytecode_image program in
          let runtime =
            if classification = `Custom then
              ""
            else
              runtime
          in
          runtime, classification
    in
    let summarise f () =
      display_path f program;
      List.iter (fun x -> Format.pp_print_char f ' '; display_path f x) args;
      if not to_stdout then
        Format.pp_print_string f (" 1> " ^ captured_output);
      if no_stderr then
        Format.pp_print_string f (" 2>" ^ Filename.null)
    in
    let display_environment () =
      if environment.serial <> !last_environment then begin
        last_environment := environment.serial;
        (* For ease of diff'ing, the environment is displayed in Posix format
           and ignores the fact Windows doesn't set LD_LIBRARY_PATH *)
        Format.printf "\
@{<inline_code>> @}@{<loc>Environment@}\n\
@{<inline_code>> @}  @{<hint>PATH@}=%a:$PATH\n\
@{<inline_code>> @}  @{<hint>LD_LIBRARY_PATH@}=%a:$LD_LIBRARY_PATH\n"
                      display_path environment.bindir
                      display_path environment.libdir;
        if environment.set_OCAMLLIB then
          Format.printf "\
@{<inline_code>> @}  @{<warning>OCAMLLIB@}=%a:$OCAMLLIB\n" display_path libdir
      end
    in
    try
      let pid =
        Unix.create_process_env program (Array.of_list (program::args)) env
                                Unix.stdin stdout stderr
      in
      let (_, status) = Unix.waitpid [] pid in
      begin
        match status with
        | Unix.WEXITED n ->
            if n = 2 && (not to_stdout || classification = `Launcher) then
              Format.printf "@{<warning>%a@} <@{<warning>exit 2@}>\n%!"
                            summarise ()
            else if n = 0 then
              Format.printf "@{<inline_code>%a@}\n%!" summarise ()
            else
              Format.printf "@{<error>%a@} <@{<error>exit %d@}>\n%!"
                            summarise () n
        | _ ->
            Format.printf "@{<error>%a@}\n%!" summarise ()
      end;
      display_environment ();
      let result =
        let _ = Unix.lseek stdout 0 Unix.SEEK_SET in
        let lines =
          let ic = Unix.in_channel_of_descr stdout in
          In_channel.set_binary_mode ic false;
          if to_stdout then
            let format_line () = Format.printf "@{<inline_code>>@} %s\n%!" in
            let () = In_channel.fold_lines format_line () ic in
            []
          else
            In_channel.input_lines ic
        in
        Unix.close stdout;
        Sys.remove captured_output;
        lines in
      match status with
      | Unix.WEXITED n when runtime = "" && (n = 0 || not to_stdout) ->
          n, result
      | Unix.WEXITED 2 when classification = `Launcher ->
          run_process_aux ~to_stdout runtime (program::args) ~no_stderr
                          environment
      | status ->
          fail_because "%s did not terminate as expected (%a)"
                       program print_process_status status
    with Unix.(Unix_error(ENOENT, "create_process", _)) as e ->
      Format.printf "@{<warning>%a@} <@{<warning>exit 2@}>\n%!" summarise ();
      display_environment ();
      if classification = `Shebang || classification = `Launcher then
        run_process_aux ~to_stdout runtime (program::args) ~no_stderr
                        environment
      else if to_stdout then
        raise e
      else
        (2, [])

  let run_process : type s . guard:bool -> s output -> ?runtime:string -> string
                      -> string list -> ?no_stderr:bool -> t -> s =
    fun ~guard output ?runtime program args ?no_stderr env ->
      assert (runtime = None || not guard);
      match output with
      | Stdout ->
          run_process_aux ~to_stdout:true ?runtime program args ?no_stderr env
          |> ignore
      | Return ->
          run_process_aux ~to_stdout:false ?runtime program args ?no_stderr env

  let run_process_target output = run_process ~guard:target_relocatable output
  let run_process output = run_process ~guard:relocatable output
end

(* When compiling with -output-obj, any additional C flags specified in
   ocamlcommon.cmxa will be omitted and must be specified when linking. Read the
   C lib_ccobjs field from ocamlcommon.cmxa for these tests. *)
let ocamlcommon_native_c_libraries =
  if config.has_ocamlopt then
    let lib =
      Filename.(concat (concat libdir "compiler-libs") "ocamlcommon.cmxa")
    in
    In_channel.with_open_bin lib (fun ic ->
      try
        let magic =
          really_input_string ic (String.length Config.cmxa_magic_number)
        in
        if magic <> Config.cmxa_magic_number then
          fail_because "Wrong magic number in %s; expected %s but got %s"
                       lib Config.cmxa_magic_number magic;
        let {Cmx_format.lib_ccobjs = libs; lib_ccopts = opts} =
          (input_value ic : Cmx_format.library_infos)
        in
        if libs <> [] then
          String.concat " " (List.rev (libs @ opts))
        else
          ""
      with End_of_file ->
        fail_because "%s appears to be corrupted" lib)
  else
    ""

(* exe ["foo" = "foo.exe"] on Windows or ["foo"] otherwise. *)
let exe =
  if Sys.win32 then
    Fun.flip (^) ".exe"
  else
    Fun.id

type mode = Bytecode | Native

(* This test verifies that a series of libraries can be loaded in a toplevel.
   Any failures cause the script to be aborted. *)
let load_libraries_in_toplevel ~original env bindir mode libraries =
  let toplevel =
    match mode with
    | Bytecode -> "ocaml"
    | Native -> "ocamlnat"
  in
  let toplevel = Filename.concat bindir (exe toplevel) in
  Format.printf "\nTesting loading of libraries in %a\n%!"
                display_path toplevel;
  Out_channel.with_open_text "test_install_script.ml" (fun oc ->
    List.iter (fun library ->
      (* dynlink.cmxs does not exist, for obvious reasons, but we can check
         loading the library in ocamlnat "works". *)
      let ext =
        match mode with
        | Native ->
            if library = "dynlink" then
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
      library library ext library ext) libraries;
    Printf.fprintf oc "#quit;;\n");
  let args =
    ["-noinit"; "-no-version"; "-noprompt"; "test_install_script.ml"]
  in
  let runtime =
    if original || Sys.win32 || mode = Native then
      None
    else
      Some (Filename.concat bindir (exe "ocamlrun"))
  in
  Environment.run_process Stdout ?runtime toplevel args env;
  Sys.remove "test_install_script.ml"

(* This test verifies that a series of libraries can be loaded via Dynlink.
   Any failures will cause either an exception or a compilation error. *)
let load_libraries_in_prog ~original env bindir libdir mode libraries =
  Format.printf "\nTesting loading of libraries with %s dynlink\n"
                (if mode = Native then "native" else "bytecode");
  let ocamlrun = Some (Filename.concat bindir (exe "ocamlrun")) in
  Out_channel.with_open_text "test_install_script.ml" (fun oc ->
    let emit_library library =
      if library <> "dynlink" then
        let libdir = Filename.concat libdir library in
        let library = library ^ ".cma" in
        let lib = Filename.concat libdir library in
        Printf.fprintf oc
          "  Dynlink.loadfile (Dynlink.adapt_filename %S);\n\
          \  Printf.printf \"Loaded %%s\\n\" (Dynlink.adapt_filename %S);"
          lib library

    in
    Printf.fprintf oc
      "let () =\n\
      \  let () = Dynlink.allow_unsafe_modules true in\n";
    List.iter emit_library libraries;
  );
  flush stdout;
  let test_program = Filename.concat test_root (exe "test_install_script") in
  let () =
    let compiler, dynlink =
      match mode with
      | Bytecode -> "ocamlc", "dynlink.cma"
      | Native -> "ocamlopt", "dynlink.cmxa"
    in
    let compiler = Filename.concat bindir (exe compiler) in
    let runtime =
      if original || Sys.win32 || config.has_ocamlopt || mode = Native then
        None
      else
        ocamlrun
    in
    let args = [
      "-I"; "+dynlink"; dynlink; "-linkall";
      "-o"; test_program; "test_install_script.ml"
    ] in
    Environment.run_process Stdout ?runtime compiler args env
  in
  let runtime =
    if original || Sys.win32 || mode = Native then
      None
    else
      ocamlrun
  in
  let () = Environment.run_process_target Stdout ?runtime test_program [] env in
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
     files
  in
  List.iter Sys.remove files

let is_executable =
  if Sys.win32 then
    Fun.const true
  else
    fun binary ->
      try Unix.access binary [Unix.X_OK]; true
      with Unix.Unix_error _ -> false

(* This test verifies that a series of libraries can be loaded via Dynlink.
   Any failures will cause either an exception or a compilation error. *)
let test_bytecode_binaries ~original env bindir =
  let test_binary binary =
    if String.starts_with ~prefix:"ocaml" binary
    || String.starts_with ~prefix:"flexlink" binary then
    let binary = Filename.concat bindir binary in
    if is_executable binary then
      match classify_bytecode_image binary with
      | `Not_tendered_bytecode -> ()
      | `Shebang | `Launcher | `Custom ->
          match Environment.run_process Return binary ["-vnum"] env with
          | (0, output) ->
              let format_line = Format.printf "@{<inline_code>>@} %s\n%!" in
              List.iter format_line output
          | (2, _) when not original && not Sys.win32 ->
              ()
          | _ ->
              fail_because "it was broken"
  in
  let binaries = Sys.readdir bindir in
  Format.printf "\nTesting bytecode binaries in %a\n" display_path bindir;
  Array.sort String.compare binaries;
  Array.iter test_binary binaries

let write_test_program description =
  Out_channel.with_open_text "test_install_script.ml" (fun oc ->
    Printf.fprintf oc {|
let state = bool_of_string Sys.argv.(1)

let is_directory dir =
  try Sys.is_directory dir
  with Sys_error _ -> false

let display_lib =
  let dir = Config.standard_library in
  let dir =
    if String.starts_with ~prefix:Sys.argv.(2) dir then
      let l = String.length Sys.argv.(2) in
      "$prefix" ^ String.sub dir l (String.length dir - l)
    else
      dir
  in
  if String.ends_with ~suffix:Sys.argv.(3) dir then
    let l = String.length Sys.argv.(3) in
    String.sub dir 0 (String.length dir - l) ^ "$libdir"
  else
    dir

let () =
  Printf.printf "%s: %%s\n%%!" display_lib;
  if is_directory Config.standard_library <> state then
    let () =
      Printf.eprintf "  *** Directory %%sfound!\n"
                     (if state then "not " else "")
    in
    exit 1
|} description)

let run_program env ?runtime test_program ~arg =
  let args = [string_of_bool arg; prefix; libdir_suffix] in
  Environment.run_process_target Stdout ?runtime test_program args env

type compiler = C_ocamlc | C_ocamlopt
type runtime_mode = Shared | Static
type linkage =
| Default of compiler
| Custom of runtime_mode
| Output_obj of compiler * runtime_mode
| Output_complete_obj of compiler * runtime_mode
| Output_complete_exe of runtime_mode

let compile_test ~original env bindir =
  let runtime =
    if original || config.has_ocamlopt || Sys.win32 then
      None
    else
      Some (Filename.concat bindir (exe "ocamlrun"))
  in
  let ocamlc = Filename.concat bindir (exe "ocamlc") in
  let ocamlopt = Filename.concat bindir (exe "ocamlopt") in
  let main_object =
    Filename.concat (Filename.dirname Sys.executable_name)
                    ("main_in_c" ^ Config.ext_obj)
  in
  fun test test_program description ->
    let use_shared_runtime, needs_ocamlopt, options, main_in_c, clibs =
      match test with
      | Default C_ocamlc ->
          false, false, [], false, None
      | Default C_ocamlopt ->
          false, true, [], false, None
      | Custom Static ->
          false, false, ["-custom"], false, None
      | Custom Shared ->
          true, false, ["-custom"], false, None
      | Output_obj(C_ocamlc, Static) ->
          false, false, ["-output-obj"], true, None
      | Output_obj(C_ocamlc, Shared) ->
          true, false, ["-output-obj"], true, None
      | Output_obj(C_ocamlopt, Static) ->
          false, true, ["-output-obj"], true,
          Some ocamlcommon_native_c_libraries
      | Output_obj(C_ocamlopt, Shared) ->
          true, true, ["-output-obj"], true,
          Some ocamlcommon_native_c_libraries
      | Output_complete_obj(C_ocamlc, Static) ->
          false, false, ["-output-complete-obj"], true, None
      | Output_complete_obj(C_ocamlc, Shared) ->
          true, false, ["-output-complete-obj"], true, None
      | Output_complete_obj(C_ocamlopt, Static) ->
          false, true, ["-output-complete-obj"], true,
          Some Config.comprmarsh_c_libraries
      | Output_complete_obj(C_ocamlopt, Shared) ->
          true, true, ["-output-complete-obj"], true,
          Some Config.comprmarsh_c_libraries
      | Output_complete_exe Static ->
          false, false, ["-output-complete-exe"], false, None
      | Output_complete_exe Shared ->
          true, false, ["-output-complete-exe"], false, None
    in
    (* At present, shared runtime support is not available on Windows *)
    if use_shared_runtime
       && (Sys.win32 || not config.supports_shared_libraries)
    || needs_ocamlopt && not config.has_ocamlopt then
      None
    else
      let test_program = Filename.concat test_root (exe test_program) in
      let compiler = if needs_ocamlopt then ocamlopt else ocamlc in
      let compile_with_main_in_c output =
        let runtime_lib =
          let suffix = if use_shared_runtime then "_shared" else "" in
          if needs_ocamlopt then
            "-lasmrun" ^ suffix
          else
            "-lcamlrun" ^ suffix
        in
        let flags =
          let libraries =
            if needs_ocamlopt then
              [runtime_lib; Config.native_c_libraries]
            else
              [runtime_lib; Config.bytecomp_c_libraries]
          in
          let libraries =
            match clibs with
            | Some lib when lib <> "" -> lib::libraries
            | _ -> libraries
          in
          String.concat " " libraries
        in
        if Ccomp.call_linker Ccomp.Exe test_program
                             [output; main_object] flags <> 0 then
          fail_because "Unexpected linker error";
        Sys.remove output
      in
      let () =
        let output =
          if main_in_c then
            "test_install_ocaml" ^ Config.ext_obj
          else
            test_program
        in
        write_test_program description;
        let ocamlcommon =
          if needs_ocamlopt then "ocamlcommon.cmxa" else "ocamlcommon.cma"
        in
        let options =
          if use_shared_runtime && not main_in_c then
            "-runtime-variant" :: "_shared" :: options
          else
            options
        in
        let args =
          "-I" :: "+compiler-libs" :: ocamlcommon ::
          "-o" :: output ::
          "test_install_script.ml" :: options
        in
        let () = Environment.run_process Stdout ?runtime compiler args env in
        let files = [
          "test_install_script.ml";
          "test_install_script.cmi";
          "test_install_script.cm" ^ (if needs_ocamlopt then "x" else "o")
        ] in
        let files =
          if needs_ocamlopt then
            ("test_install_script" ^ Config.ext_obj)::files
          else
           files
        in
        List.iter Sys.remove files;
        if main_in_c then
          compile_with_main_in_c output
      in
      let rec run ~original ?runtime env ~arg =
        let runtime =
          if test = Default C_ocamlc && not Sys.win32 then
            runtime
          else
            None
        in
        let arg =
          (config.has_relative_libdir && test = Default C_ocamlc) || arg
        in
        run_program env ?runtime test_program ~arg;
        if original then
          Some (run ~original:false)
        else
          (Sys.remove test_program; None)
      in
      Some (run ~original)

let compiler_where env ?runtime compiler =
  match Environment.run_process Return ?runtime compiler ["-where"] env with
  | (0, [where]) -> where
  | _ ->
      fail_because "Unexpected response from %s -where" compiler

(* This test verifies both that all compilation mechanisms are working and that
   each of these programs can correctly identify the Standard Library location.
   Any failures will cause either an exception or a compilation error. *)
let test_standard_library_location ~original env bindir =
  Format.printf "\nTesting compilation mechanisms for %a\n%!"
                display_path bindir;
  let runtime =
    if original || config.has_ocamlopt || Sys.win32 then
      None
    else
      Some (Filename.concat bindir (exe "ocamlrun"))
  in
  let ocamlc = Filename.concat bindir (exe "ocamlc") in
  let ocamlopt = Filename.concat bindir (exe "ocamlopt") in
  let ocamlc_where = compiler_where env ?runtime ocamlc in
  let ocamlopt_where =
    if config.has_ocamlopt then
      compiler_where env ocamlopt
    else
      "n/a"
  in
  Format.printf "ocamlc -where: %a\nocamlopt -where: %a\n%!"
                display_path ocamlc_where display_path ocamlopt_where;
  let compile_test = compile_test ~original env bindir in
  let programs = List.filter_map Fun.id [
    compile_test (Default C_ocamlc)
      "byt_default" "with tender";
    compile_test (Custom Static)
      "custom_static" "-custom static runtime";
    compile_test (Custom Shared)
      "custom_shared" "-custom shared runtime";
    compile_test (Output_obj(C_ocamlc, Static))
      "byt_obj_static" "-output-obj static runtime";
    compile_test (Output_obj(C_ocamlc, Shared))
      "byt_obj_shared" "-output-obj shared runtime";
    compile_test (Output_complete_obj(C_ocamlc, Static))
      "byt_complete_obj_static" "-output-complete-obj static runtime";
    compile_test (Output_complete_obj(C_ocamlc, Shared))
      "byt_complete_obj_shared" "-output-complete-obj shared runtime";
    compile_test (Output_complete_exe Static)
      "byt_complete_exe_static" "-output-complete-exe static runtime";
    compile_test (Output_complete_exe Shared)
      "byt_complete_exe_shared" "-output-complete-exe shared runtime";
    compile_test (Default C_ocamlopt)
      "nat_default" "static runtime";
    compile_test (Output_obj(C_ocamlopt, Static))
      "nat_obj_static" "-output-obj static runtime";
    compile_test (Output_obj(C_ocamlopt, Shared))
      "nat_obj_shared" "-output-obj shared runtime";
    compile_test (Output_complete_obj(C_ocamlopt, Static))
      "nat_complete_obj_static" "-output-complete-obj static runtime";
    compile_test (Output_complete_obj(C_ocamlopt, Shared))
      "nat_complete_obj_shared" "-output-complete-obj shared runtime";
  ] in
  let runtime =
    if original then
      None
    else
      Some (Filename.concat bindir (exe "ocamlrun"))
  in
  Printf.printf "Running programs\n%!";
  List.filter_map (fun f -> f ?runtime env ~arg:true) programs

let run_tests ~original env bindir libdir libraries =
  if config.supports_shared_libraries then
    load_libraries_in_toplevel ~original env bindir Bytecode libraries;
  if config.has_ocamlnat then
    load_libraries_in_toplevel ~original env bindir Native libraries;
  if config.supports_shared_libraries then
    load_libraries_in_prog ~original env bindir libdir Bytecode libraries;
  if config.has_ocamlopt && config.supports_shared_libraries then
    load_libraries_in_prog ~original env bindir libdir Native libraries;
  test_bytecode_binaries ~original env bindir;
  test_standard_library_location ~original env bindir

let () =
  (* Run all tests in the supplied prefix *)
  Compmisc.init_path ();
  let env = Environment.make bindir libdir in
  let programs = run_tests ~original:true env bindir libdir config.libraries in
  (* Now rename the prefix, appending .new to the directory name *)
  let new_prefix = prefix ^ ".new" in
  let bindir = Filename.concat new_prefix bindir_suffix in
  let libdir = Filename.concat new_prefix libdir_suffix in
  Format.printf "\nRenaming %a to %a\n\n%!" display_path prefix
                                            display_path new_prefix;
  Sys.rename prefix new_prefix;
  at_exit (fun () ->
    flush stderr;
    flush stdout;
    Format.printf "\nRestoring %a to %a\n" display_path new_prefix
                                           display_path prefix;
    Sys.rename new_prefix prefix);
  (* Re-run the test programs compiled with the normal prefix *)
  Printf.printf "Re-running test programs\n%!";
  (* Finally re-run all of the tests with the new prefix *)
  let env = Environment.make bindir libdir in
  let runtime = Some (Filename.concat bindir (exe "ocamlrun")) in
  List.iter (fun f -> assert (f ?runtime env ~arg:false = None)) programs;
  let env =
    Environment.make ~ocamllib:(not config.has_relative_libdir) bindir libdir
  in
  Compmisc.reinit_path ~standard_library:libdir ();
  let programs = run_tests ~original:false env bindir libdir config.libraries in
  assert (programs = [])
