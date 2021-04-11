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

(* Compiler configuration, determined from the command line *)
type config = {
  supports_shared_libraries: bool;
    (* $(SUPPORTS_SHARED_LIBRARIES) - Makefile.config *)
  has_ocamlnat: bool;
    (* $(INSTALL_OCAMLNAT) - Makefile.build_config *)
  has_ocamlopt: bool;
    (* $(NATIVE_COMPILER) - Makefile.config *)
  has_relative_libdir: string option;
    (* $(LIBDIR_REL) - Makefile.build_config *)
  libraries: string list list
    (* Sorted list of basenames of libraries to test.
       Derived from $(OTHERLIBRARIES) - Makefile.config *)
}

(* XXX Misc.Stdlib.List.find_and_chop_longest_common_prefix ? *)
let split_to_common_prefix first second =
  let rec split_dir acc dir =
    let dirname = Filename.dirname dir in
    if dirname = dir then
      dir::acc
    else
      split_dir (Filename.basename dir :: acc) dirname
  in
  let rec loop prefix first second =
    match first, second with
    | (dir1::first), (dir2::second) ->
        if dir1 = dir2 then
          loop (dir1::prefix) first second
        else begin
          match List.rev prefix with
          | [] | [_] ->
              Result.error `Nothing_in_common
          | dir::dirs ->
              Result.ok (List.fold_left Filename.concat dir dirs,
                         List.fold_left Filename.concat dir1 first,
                         List.fold_left Filename.concat dir2 second)
        end
    | [], _ ->
        Result.error `Second_in_first
    | _, [] ->
        Result.error `First_in_second
  in
  loop [] (split_dir [] first) (split_dir [] second)

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
let bindir, libdir, prefix, bindir_suffix, libdir_suffix,
    config, relocatable, target_relocatable, verbose =
  let show_summary = ref false in
  let verbose = ref false in
  let bindir = ref "" in
  let libdir = ref "" in
  let config =
    ref {supports_shared_libraries = false; has_ocamlnat = false;
         has_ocamlopt = false; has_relative_libdir = None; libraries = []}
  in
  let check_exists r dir =
    if Sys.file_exists dir then
      if Sys.is_directory dir then
        if Filename.is_relative dir then
          raise (Arg.Bad (dir ^ ": is not an absolute path"))
        else
          r := Unix.realpath dir
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
  let relative_libdir relative_libdir =
    config := {!config with has_relative_libdir = Some relative_libdir} in
  let absolute_libdir () =
    config := {!config with has_relative_libdir = None} in
  let args = Arg.align [
    "--bindir", Arg.String (check_exists bindir), "\
<bindir>\tDirectory containing programs (must share a prefix with --libdir)";
    "--libdir", Arg.String (check_exists libdir), "\
<libdir>\tDirectory containing stdlib.cma (must share a prefix with --bindir)";
    "--summary", Arg.Set show_summary, "";
    "--verbose", Arg.Set verbose, "";
    "--with-shared", Arg.Unit (supports_shared_libraries true), "\
\tInstallation supports shared libraries (*.dll/*.so can be used from OCaml)";
    "--without-shared", Arg.Unit (supports_shared_libraries false), "";
    "--with-ocamlnat", Arg.Unit (has_ocamlnat true), "\
\tNative toplevel (ocamlnat) is installed in the directory given in --bindir";
    "--without-ocamlnat", Arg.Unit (has_ocamlnat false), "";
    "--with-ocamlopt", Arg.Unit (has_ocamlopt true), "\
\tNative compiler (ocamlopt) is installed in the directory given in --bindir";
    "--without-ocamlopt", Arg.Unit (has_ocamlopt false), "";
    "--with-relative-libdir", Arg.String relative_libdir, "\
\tCompiler was configured with --with-relative-libdir";
    "--without-relative-libdir", Arg.Unit absolute_libdir, "";
  ] in
  let libraries lib =
    config := {!config with libraries = [lib]::config.contents.libraries}
  in
  let usage = "\n\
Usage: test_install --bindir <bindir> --libdir <libdir> <options> [libraries]\n\
options are:" in
  let error fmt =
    let f msg =
      Printf.eprintf "%s: %s\n" Sys.argv.(0) msg;
      if not !show_summary then
        Arg.usage args usage;
      exit 2
    in
    Printf.ksprintf f fmt
  in
  Arg.parse args libraries usage;
  let config =
    let libraries = List.sort Stdlib.compare config.contents.libraries in
    let libraries =
      let add_dependencies = function
      | ["systhreads"] -> ["unix"; "threads"]
      | x -> x
      in
      List.map add_dependencies libraries
    in
    {!config with libraries}
  in
  let {contents = bindir} = bindir in
  let {contents = libdir} = libdir in
  let relocatable = false in
  let target_relocatable = false in
  if bindir = "" || libdir = "" then
    let () = Arg.usage args usage in
    exit 2
  else
    let prefix, bindir_suffix, libdir_suffix =
      match split_to_common_prefix bindir libdir with
      | Result.Ok r -> r
      | Result.Error `Nothing_in_common ->
          (* The prefix is either the root directory (/, C:\, etc.) or, on
             Windows, the two directories are actually on different drives *)
          error "\
directories given for --bindir and --libdir do not have a common prefix"
      | Result.Error `First_in_second ->
          error "directory given for --bindir inside that given for --libdir"
      | Result.Error `Second_in_first ->
          error "directory given for --libdir inside that given for --bindir"
    in
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
    if Sys.file_exists (Filename.concat libdir "ld.conf.bak") then
      error "can't backup ld.conf to ld.conf.bak as the latter already exists!";
    let no_markup ansi = { Misc.Style.ansi; text_close = ""; text_open = "" } in
    let header_size =
      In_channel.with_open_bin (Filename.concat libdir "runtime-launch-info") @@
        fun ic ->
          let meta =
            String.length (input_line ic) + String.length (input_line ic) + 2 in
          in_channel_length ic - meta in
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
    Format.printf "Executable header size: %.2fKiB (%d bytes)\n"
                  (float_of_int header_size /. 1024.0) header_size;
    Format.printf "Testing %s\n%!" summary;
    bindir, libdir, prefix, bindir_suffix, libdir_suffix,
    config, relocatable, target_relocatable, !verbose

(* display_path jumps through some mildly convoluted hoops to create something
   approaching diff'able output.
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
       is replaced with ["$PWD"] but unlike [prefix] either nothing must follow
       or the next character must be a directory separator. (i.e. it generates
       ["./"] but never [".new/"])
   Both simpler and more convoluted ways of doing this are available. On
   Windows, the comparisons treat forward and back slashes as being the same. *)

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

  let path_starts_with =
    if Sys.win32 then
      fun ~prefix s ->
        if String.length s < String.length prefix then
          false
        else
          let f = function '\\' -> '/' | c -> c in
          let prefix = String.map f prefix in
          let s = String.map f s in
          String.starts_with ~prefix s
    else
      String.starts_with

  let remove_prefix ~prefix s =
    if path_starts_with ~prefix s then
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

(* Full path to testsuite/in_prefix in the build tree (i.e. where the harness is
   executed from and where it places files.) *)
let test_root = Sys.getcwd ()

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
          Format.pp_print_string f ("$PWD" ^ path)
      | _ ->
          if String.remove_prefix ~prefix:libdir_suffix path = Some "" then
            Format.pp_print_string f "$libdir"
          else if String.remove_prefix ~prefix:bindir_suffix path = Some "" then
            Format.pp_print_string f "$bindir"
          else
            Format.pp_print_string f path

let display_path =
  if verbose then
    Format.pp_print_string
  else
    display_path

(* The execution and argv[0] tests need to know whether caml_executable_name is
   implemented for this platform (at present, Linux, macOS and native Windows
   are; *BSD and Cygwin are not) *)
external proc_self_exe : unit -> string option = "caml_sys_proc_self_exe"
let no_caml_executable_name = (proc_self_exe () = None)

(* [classify_executable file] determines if [file] is :
   - Tendered bytecode with an executable header
   - Scripted bytecode invoking ocamlrun with a #! header
   - Custom bytecode (produced with ocamlc -custom)
   - Native executables (vanilla ocamlopt or any of the caml_startup mechanisms
     via -output-obj, -output-complete-exe, etc.). The actual OCaml program may
     be bytecode (but it will have been embedded in a C object). *)
type executable =
| Tendered
| Shebang
| Custom
| Native

let classify_executable file =
  try
    In_channel.with_open_bin file (fun ic ->
      let start = really_input_string ic 2 in
      let is_RNTM = function
      | Bytesections.{name = Name.RNTM; _} -> true
      | _ -> false
      in
      let sections = Bytesections.(all (read_toc ic)) in
      if start = "#!" then
        Shebang
      else if List.exists is_RNTM sections then
        Tendered
      else
        Custom)
  with End_of_file | Bytesections.Bad_magic_number ->
    Native

(* Print a formatted message to [stderr] and [exit 1] *)
let fail_because fmt = Format.ksprintf (fun s -> prerr_endline s; exit 1) fmt

(* [string_of_process_status status] returns a loggable description of a
   [Unix.process_status] value. *)
let signal_of_int n =
  (* Perhaps Sys or Unix will acquire name_of_signal for Christmas *)
  if n = Sys.sigsegv then
    "SIGSEGV"
  else
    "OCaml signal number " ^ string_of_int n

let string_of_process_status = function
| Unix.WEXITED n -> "exited with " ^ string_of_int n
| Unix.WSIGNALED n -> "signalled with " ^ signal_of_int n
| Unix.WSTOPPED n -> "stopped with " ^ signal_of_int n

(* [Environment.run_process] either [Return]s the exit code and lines of output
   from running a command, or assumes it exits with code 0 and displays the
   output directory to [Stdout]. *)
type _ output =
| Stdout : unit output
| Return : (int * string list) output

module StringSet = Set.Make(String)

(* All process invocation is done via [Environment.run_process] and
   [Environment.run_process_target] which in particular abstracts and manages
   the environment ultimately passed to [Unix.create_process_env]. *)
module Environment : sig
  type t

  (* [make bindir libdir] creates a new environment where [bindir] will be in
     [PATH] and with [libdir] available for loading of shared libraries (i.e.
     with [LD_LIBRARY_PATH] / [DYLD_LIBRARY_PATH] set or updated).
     [~caml_ld_library_path], [~ocamllib] and [~camllib] can be used to set
     [CAML_LD_LIBRARY_PATH], [OCAMLLIB] and [CAMLLIB] (which are all unset
     otherwise). *)
  val make :
    ?caml_ld_library_path:string list -> ?ocamllib:string -> ?camllib:string
      -> string -> string -> t

  (* [run_process mode ?runtime ?no_stderr ?should_fail ?prefix_path_in_cwd
     ?argv0 program args environment] executes [program] with [args] in
     [environment]. If [mode] is [Stdout], then the output is displayed using
     [display_output] and the exit code of the process simply checked. If [mode]
     is [Return], then then the exit code and lines of output are instead
     returned as values.
     Unlike [Unix.create_process_env], [program] is automatically put at the
     start of [argv], unless [~argv0] is specified. stderr is included/displayed
     unless [~no_stderr] is [false]. Programs are assumed to exit with code 0
     unless [~should_fail] is [true]. If [mode] is [Stdout], the test terminates
     if the exit code is unexpected (when [mode] is [Return], [~should_fail]
     controls the formatting). If [~prefix_path_with_cwd] is [true] then the
     current directory (i.e. ["."]) is prepended to [PATH] (note that this is
     default behaviour on Windows with or without the entry).
     [runtime], if specified, should be the full path to [ocamlrun]. In this
     case, if program is a bytecode image, then program is expected to fail
     (for a #!-style launcher, either by Unix.create_process failing with ENOENT
     or with the process returning with exit code 127 or with exit code 2 for an
     executable "tendered" launcher) and [run_process] retries, explicitly
     passing [program] to [runtime].
     [run_process] always displays the command being executed on stdout and any
     changes to the environment since the previous call to [run_process]. *)
  val run_process :
    'a output
      -> ?runtime:string -> ?no_stderr:bool -> ?should_fail:bool
      -> ?prefix_path_with_cwd:bool -> ?argv0:string
      -> string -> string list -> t -> 'a

  (* [run_process_target] is the same [run_process], but where the executable
     being run has been produced by the compiler being tested. *)
  val run_process_target :
    'a output
      -> ?runtime:string -> ?no_stderr:bool -> ?should_fail:bool
      -> ?prefix_path_with_cwd:bool -> ?argv0:string
      -> string -> string list -> t -> 'a

  (* Formats and displays the output lines of program on stdout *)
  val display_output : string list -> unit

end = struct
  type t = {
    env: string array;
    serial: int;
    bindir: string;
    libdir: string;
    augmentations: (string * string) list;
  }

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

  (* Tests whether the name of an environment variable is in fact PATH, masking
     the fact that environment variable names are case-insensitive on
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
  let make ?caml_ld_library_path ?ocamllib ?camllib bindir libdir =
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
    let bindings, augmentations =
      match camllib with
      | Some binding ->
          ("CAMLLIB=" ^ binding)::bindings,
          [("CAMLLIB", binding)]
      | None ->
          bindings, []
    in
    let bindings, augmentations =
      match ocamllib with
      | Some binding ->
          ("OCAMLLIB=" ^ binding)::bindings,
          ("OCAMLLIB", binding)::augmentations
      | None ->
          bindings, augmentations
    in
    let bindings, augmentations =
      match caml_ld_library_path with
      | Some dirs ->
          let binding = String.concat (if Sys.win32 then ";" else ":") dirs in
          ("CAML_LD_LIBRARY_PATH=" ^ binding)::bindings,
          ("CAML_LD_LIBRARY_PATH", binding)::augmentations
      | None ->
          bindings, augmentations
    in
    let env = Array.of_list bindings in
    try {env; serial = Hashtbl.find environments env; bindir; libdir;
         augmentations}
    with Not_found ->
      let serial = Hashtbl.length environments + 1 in
      Hashtbl.add environments env serial;
      {env; serial; bindir; libdir; augmentations}

  let null = Unix.openfile Filename.null [Unix.O_WRONLY] 0o200

  let last_environment = ref (-1)

  let format_line () = Format.printf "@{<inline_code>>@} %s\n%!"

  let rec run_process_aux ~to_stdout ?runtime ?(no_stderr = false)
                          ?(should_fail = false) ?(prefix_path_with_cwd = false)
                          ?argv0 program args ({env; _} as environment) =
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
          "", Native
      | Some runtime ->
          let classification = classify_executable program in
          let runtime =
            if classification = Custom then
              ""
            else
              runtime
          in
          runtime, classification
    in
    let summarise f () =
      let () =
        match argv0 with
        | Some argv0 ->
            Format.pp_print_string f argv0;
            Format.pp_print_string f " (from ";
            display_path f program;
            Format.pp_print_char f ')'
        | None ->
            display_path f program
      in
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
        let print_augmentation (variable, binding) =
          Format.printf "@{<inline_code>> @}  @{<warning>%s@}=%a\n"
                        variable display_path binding
        in
        List.iter print_augmentation environment.augmentations;
      end
    in
    try
      let pid =
        let argv0 = Option.value ~default:program argv0 in
        let env =
          if Sys.win32 || not prefix_path_with_cwd then
            env
          else
            let add_cwd_to_path s =
              if String.starts_with ~prefix:"PATH=" s then
                "PATH=.:" ^ String.sub s 5 (String.length s - 5)
              else
                s
            in
            Array.map add_cwd_to_path env
        in
        Unix.create_process_env program (Array.of_list (argv0::args)) env
                                Unix.stdin stdout stderr
      in
      let (_, status) = Unix.waitpid [] pid in
      begin
        match status with
        | Unix.WEXITED n ->
            if n <> 0 && not to_stdout && not should_fail
               || n = 2 && classification = Tendered
               || n = 127 && classification = Shebang then
              Format.printf "@{<warning>%a@} <@{<warning>exit %d@}>\n%!"
                            summarise () n
            else if n <> 0 && should_fail then
              Format.printf "@{<inline_code>%a@} <@{<inline_code>exit %d@}>\n%!"
                            summarise () n
            else if n = 0 && not should_fail then
              Format.printf "@{<inline_code>%a@}\n%!" summarise ()
            else
              Format.printf "@{<error>%a@} <@{<error>exit %d@}>\n%!"
                            summarise () n
        | status ->
            Format.printf "@{<error>%a@} <@{<error>%s@}>\n%!"
                          summarise ()
                          (string_of_process_status status)
      end;
      display_environment ();
      let result =
        let _ = Unix.lseek stdout 0 Unix.SEEK_SET in
        let lines =
          let ic = Unix.in_channel_of_descr stdout in
          (* Some of the tests send lines of text which end with '\r'. On native
             Windows, this will _correctly_ cause "\r\r\n" to be be sent down
             the pipe and text mode will _correctly_ translate that to "\r\n"
             (and the caller receives a line ending with '\r').
             On Cygwin, where the process sending the text is a Unix process,
             the same text ending '\r' is just sent with "\r\n" which definitely
             does not want to be translated to just '\n'. Other Unix systems do
             not differentiate text and binary mode anyway, so the distinction
             is moot. *)
          In_channel.set_binary_mode ic Sys.cygwin;
          if to_stdout then
            let () = In_channel.fold_lines format_line () ic in
            []
          else
            In_channel.input_lines ic
        in
        Unix.close stdout;
        Sys.remove captured_output;
        lines in
      match status with
      | Unix.WEXITED n
        when runtime = "" && (n = 0 || not to_stdout) ->
          n, result
      | Unix.WEXITED n
        when n = 2 && classification = Tendered
             || n = 127 && classification = Shebang ->
          run_process_aux ~to_stdout runtime (program::args) ~no_stderr
                          ~prefix_path_with_cwd environment
      | Unix.WSIGNALED n
        when not to_stdout
             && n = Sys.sigsegv && Config.architecture = "s390x" ->
          (* cf. ocaml/ocaml#13693 - s390x executables might segfault, so this
             gets converted to Docker's exit code so it can be skipped *)
          (139, [])
      | status ->
          let display_argv0 =
            match argv0 with
            | Some argv0 -> Printf.sprintf "%s (from %s)" argv0 program
            | None -> program
          in
          fail_because "%s did not terminate as expected (%s)"
                       display_argv0 (string_of_process_status status)
    with Unix.(Unix_error(ENOENT, "create_process", _)) as e ->
      Unix.close stdout;
      Sys.remove captured_output;
      Format.printf "@{<warning>%a@} <@{<warning>exit 2@}>\n%!" summarise ();
      display_environment ();
      if classification = Shebang || classification = Tendered then
        run_process_aux ~to_stdout runtime (program::args) ~no_stderr
                        ~prefix_path_with_cwd environment
      else if to_stdout then
        raise e
      else
        (127, [])

  let run_process : type s . guard:bool -> s output -> ?runtime:string
                      -> ?no_stderr:bool -> ?should_fail:bool
                      -> ?prefix_path_with_cwd:bool -> ?argv0:string
                      -> string -> string list -> t -> s =
    fun ~guard output ?runtime ?no_stderr ?should_fail ?prefix_path_with_cwd
        ?argv0 program args env ->
      assert (runtime = None || not guard);
      match output with
      | Stdout ->
          run_process_aux ~to_stdout:true ?runtime ?no_stderr ?should_fail
                          ?prefix_path_with_cwd ?argv0 program args env
          |> ignore
      | Return ->
          run_process_aux ~to_stdout:false ?runtime ?no_stderr ?should_fail
                          ?prefix_path_with_cwd ?argv0 program args env

  let run_process_target output = run_process ~guard:target_relocatable output
  let run_process output = run_process ~guard:relocatable output
  let display_output output = List.iter (format_line ()) output
end

(* exe ["foo" = "foo.exe"] on Windows or ["foo"] otherwise. *)
let exe =
  if Sys.win32 then
    Fun.flip (^) ".exe"
  else
    Fun.id

(* launcher_searches_for_ocamlrun describes whether ocamlc emits an RNTM with
   the name of the runtime only, expecting the launcher in stdlib/header*.c to
   search PATH for it. Only native Windows has this behaviour at present. *)
let launcher_searches_for_ocamlrun = Sys.win32
let target_launcher_searches_for_ocamlrun = Sys.win32

(* linker_is_flexlink is true for Cygwin when shared library support is enabled
   and always true for native Windows. *)
let linker_is_flexlink =
  Sys.win32 || Sys.cygwin && config.supports_shared_libraries

(* ocamlc can be directly executed after renaming the prefix if native
   compilation is enabled (because ocamlc will be ocamlc.opt) or if the bytecode
   launcher searches for the runtime. *)
let ocamlc_executable_after_rename =
  config.has_ocamlopt || launcher_searches_for_ocamlrun

type mode = Bytecode | Native

(* This test verifies that a series of libraries can be loaded in a toplevel.
   Any failures cause the script to be aborted. *)
let load_libraries_in_toplevel ~original env bindir libdir mode libraries =
  let toplevel =
    match mode with
    | Bytecode -> "ocaml"
    | Native -> "ocamlnat"
  in
  let toplevel = Filename.concat bindir (exe toplevel) in
  Format.printf "%sTesting loading of libraries in %a\n%!"
                (if original then "\n" else "") display_path toplevel;
  let runtime =
    if mode = Native || original || launcher_searches_for_ocamlrun then
      None
    else
      Some (Filename.concat bindir (exe "ocamlrun"))
  in
  let test_libraries_in_toplevel libraries =
    Out_channel.with_open_text "test_install_script.ml" (fun oc ->
      List.iter (fun library ->
        let ext =
          match mode with
          | Native ->
              if library = "dynlink" then
                (* dynlink.cmxs does not exist, for obvious reasons, but we can
                   check loading the library in ocamlnat "works". *)
                "cmxa"
              else if library = "threads" then
                let threads_plugin =
                  Filename.(concat (concat libdir "threads") "threads.cmxs")
                in
                if Sys.file_exists threads_plugin then
                  fail_because "threads.cmxs is not expected to exist"
                else if Sys.win32 then
                  (* cf. note in ocaml/ocaml#13520 - threads.cmxa is correctly
                     compiled assuming winpthreads is statically in the same
                     image (so without defining WINPTHREADS_USE_DLLIMPORT), but
                     this is incorrect for threads.cmxs, as threads.cmxs may
                     load more than 2GiB away from the main executable. For
                     native Windows, it's not possible to rely on ocamlnat's
                     automatic cmxa -> cmxs recompilation. *)
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
        library library ext library ext) libraries;
      Printf.fprintf oc "#quit;;\n");
    let args =
      ["-noinit"; "-no-version"; "-noprompt"; "test_install_script.ml"]
    in
    let expected_exit_code =
      if Sys.cygwin && mode = Native && List.mem "unix" libraries
      || Sys.win32 && mode = Native && List.mem "threads" libraries then
        (* cf. ocaml/flexdll#146 - Cygwin's ocamlnat can't load unix.cmxs and
           the lines above will have triggered native Windows being unable to
           load threads.cmxs *)
        125
      else
        0
    in
    let exit_code, output =
      Environment.run_process Return ?runtime toplevel args env
    in
    Environment.display_output output;
    if exit_code <> expected_exit_code then
      fail_because "%s was expected to exit with code %d"
                   toplevel expected_exit_code;
    Sys.remove "test_install_script.ml"
  in
  List.iter test_libraries_in_toplevel libraries

(* This test verifies that a series of libraries can be loaded via Dynlink.
   Any failures will cause either an exception or a compilation error. *)
let load_libraries_in_prog ~original env bindir libdir mode libraries =
  Format.printf "\nTesting loading of libraries with %s dynlink\n"
                (if mode = Native then "native" else "bytecode");
  let libraries = List.filter (fun l -> not (List.mem "dynlink" l)) libraries in
  let ocamlrun = Some (Filename.concat bindir (exe "ocamlrun")) in
  let test_program = Filename.concat test_root (exe "test_install_script") in
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
|} libdir
    );
    flush stdout;
    let compiler, dynlink =
      match mode with
      | Bytecode -> "ocamlc", "dynlink.cma"
      | Native -> "ocamlopt", "dynlink.cmxa"
    in
    let compiler = Filename.concat bindir (exe compiler) in
    let runtime =
      if mode = Native || original || ocamlc_executable_after_rename then
        None
      else
        ocamlrun
    in
    let args = [
      "-I"; "+dynlink"; dynlink; "-linkall";
      "-o"; test_program; "test_install_script.ml"
    ] in
    Environment.run_process Stdout ?runtime compiler args env;
    let files = [
      test_program;
      "test_install_script.ml";
      "test_install_script.cmi";
      "test_install_script.cm" ^ (if mode = Native then "x" else "o")
    ] in
    if mode = Native then
      ("test_install_script" ^ Config.ext_obj)::files
    else
     files
  in
  let runtime =
    if mode = Native || original || target_launcher_searches_for_ocamlrun
       || config.has_relative_libdir <> None then
      None
    else
      ocamlrun
  in
  let test_libraries_in_prog libraries =
    if mode = Native && List.mem "threads" libraries then
      let threads_plugin =
        Filename.(concat (concat libdir "threads") "threads.cmxs")
      in
      if Sys.file_exists threads_plugin then
        fail_because "threads.cmxs is not expected to exist"
      else
        ()
    else
      let expected_exit_code =
        if Sys.cygwin && mode = Native && List.mem "unix" libraries then
          (* cf. ocaml/flexdll#146 - Cygwin's natdynlink can't load unix.cmxs *)
          2
        else
          0
      in
      let exit_code, output =
        Environment.run_process_target
          Return ?runtime test_program libraries env
      in
      Environment.display_output output;
      if exit_code <> expected_exit_code then
        fail_because "%s is expected to return with exit code %d"
                     test_program expected_exit_code;
  in
  let files = compile_test_program () in
  let not_dynlink l = not (List.mem "dynlink" l) in
  List.iter test_libraries_in_prog (List.filter not_dynlink libraries);
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
  Format.printf "\nTesting bytecode binaries in %a\n" display_path bindir;
  let exec_magic =
    let ocamlrun = Filename.concat bindir (exe "ocamlrun") in
    Environment.run_process Return ocamlrun ["-M"] env
  in
  let test_binary binary =
    if String.starts_with ~prefix:"ocaml" binary
    || String.starts_with ~prefix:"flexlink" binary then
    let program = Filename.concat bindir binary in
    if is_executable program then
      let classification = classify_executable program in
      match classification with
      | Native -> ()
      | Shebang | Tendered | Custom ->
          match Environment.run_process Return program ["-vnum"] env with
          | (0, output) ->
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
                let without_exe = Filename.chop_extension binary in
                let (this_exit_code, _) as this =
                  Environment.run_process Return program ~argv0:without_exe
                                                 ["-M"] env ~should_fail:true
                in
                if this_exit_code = 0 then
                  if this = exec_magic then
                    let (that_exit_code, _) as that =
                      Environment.run_process Return program ~argv0:binary
                                                     ["-M"] env
                                                     ~should_fail:true
                    in
                    if this = that then
                      fail_because
                        "Neither %s nor %s seem to load the bytecode image"
                        without_exe binary
                    else if that_exit_code = 0 then
                      fail_because
                        "%s is not expected to return with exit code 0"
                        binary
                    else if not (String.contains without_exe '.') then
                      fail_because
                        "%s is not expected to return the exec magic number!"
                        without_exe
                    else () (* Expected outcome was the exec magic number *)
                  else if without_exe <> "ocamlmklib" then
                    fail_because
                      "%s is expected to return with a non-zero exit code"
                      without_exe
                  else () (* Expected outcome is a zero exit code *)
                else if without_exe = "ocamlmklib" then
                  fail_because
                    "%s is expected to return with exit code 0"
                    without_exe
                else () (* Expected outcome is a non-zero exit code *)
          | (2, _)
            when not original && not launcher_searches_for_ocamlrun &&
                 classification = Tendered ->
              ()
          | (127, _) when not original && classification = Shebang ->
              ()
          | _ ->
              fail_because "it was broken"
  in
  let binaries = Sys.readdir bindir in
  Array.sort String.compare binaries;
  Array.iter test_binary binaries

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

let compile_ld_conf_test_programs ~original env bindir =
  let ocamlrun = Filename.concat bindir (exe "ocamlrun") in
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
    let test_program = Filename.concat test_root (exe test_program) in
    let compiler, cma_ext, runtime =
      if mode = Native then
        "ocamlopt", Fun.flip (^) ".cmxa", None
      else
        let runtime =
          if original || ocamlc_executable_after_rename then
            None
          else
            Some ocamlrun
        in
        "ocamlc", Fun.flip (^) ".cma", runtime
    in
    let compiler = Filename.concat bindir (exe compiler) in
    let args = [
      "-I"; "+compiler-libs"; cma_ext "ocamlcommon"; cma_ext "ocamlbytecomp";
      "-o"; test_program; "test_install_script.ml"
    ] in
    Environment.run_process Stdout ?runtime compiler args env;
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
      if mode = Native || original || target_launcher_searches_for_ocamlrun
         || config.has_relative_libdir <> None then
        None
      else
        Some ocamlrun
    in
    let run env test =
      let code, lines =
        Environment.run_process_target Return ?runtime test_program [] env
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
        fail_because "%s is expected to exit with code 0" test_program
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
let test_ld_conf ~original env bindir libdir =
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
  let ocamlrun_config env _test =
    let ocamlrun = Filename.concat bindir (exe "ocamlrun") in
    let code, lines = Environment.run_process Return ocamlrun ["-config"] env in
    if code = 0 then
      let strip s =
        let len = String.length s in
        if len < 2 || s.[0] <> ' ' || s.[1] <> ' ' then
          fail_because "Unexpected output from ocamlrun -config: %S" s
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
      fail_because "Unexpected exit code %d from ocamlrun -config" code
  in
  let programs, files = compile_ld_conf_test_programs ~original env bindir in
  let programs = ocamlrun_config :: programs in
  let backed_up_ld_conf = Filename.concat libdir "ld.conf.bak" in
  let libdir_ld_conf = Filename.concat libdir "ld.conf" in
  let ocamllib_dir = Filename.concat test_root "ocamllib" in
  let camllib_dir = Filename.concat test_root "camllib" in
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
    let env =
      Environment.make ?caml_ld_library_path ?ocamllib ?camllib bindir libdir
    in
    match List.map (fun f -> f env test) programs with
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
              let s = Format.asprintf "%a" display_path s in
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
          fail_because "All mechanisms should produce the same output"
        end else if List.tl ocamlrun <> test.outcome then begin
          display_results [ocamlrun; "Expected outcome"::test.outcome];
          fail_because "Output differs from the expected results"
        end else if verbose then
          display_results (("Expected outcome"::test.outcome)::results)
  in
  let ensure_dir dir =
    if not (Sys.file_exists dir) then
      Sys.mkdir dir 0o775
    else if not (Sys.is_directory dir) then begin
      Sys.remove dir;
      Sys.mkdir dir 0o775
    end
  in
  let restore =
    let restored = ref false in
    fun () ->
      if not !restored then begin
        restored := true;
        Format.printf "Restoring %a to %a\n" display_path backed_up_ld_conf
                                             display_path libdir_ld_conf;
        remove_if_exists libdir_ld_conf;
        Sys.rename backed_up_ld_conf libdir_ld_conf
      end
  in
  let base =
    {description = "";
     caml_ld_library_path = Unset; ocamllib = Unset; camllib = Unset;
     stdlib = []; outcome = []}
  in
  (* Batch 1: various interesting kinds of line, tested when read through
     CAML_LD_LIBRARY_PATH and ld.conf *)
  let tests =
    let main, main_outcome, main_outcome_cr =
      let (/) = Filename.concat in
      let libdir =
        if config.has_relative_libdir = None then
          Config.standard_library
        else
          libdir
      in
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
        "/lib/ocaml", "/lib/ocaml", Some "/lib/ocaml\r";
      ] in
      let fold (main, main_outcome, main_outcome_cr) (line, outcome, cr) =
        let cr = Option.value ~default:outcome cr in
        line::main, outcome::main_outcome, cr::main_outcome_cr
      in
      List.fold_left fold ([], [], []) (List.rev data)
    in
    let tests =
      let description = "Base ld.conf test" in
      (* Various test lines above all fed via ld.conf in the Standard Library.
         ocamlrun can't find ld.conf after the prefix has been renamed *)
      let outcome =
        if original || config.has_relative_libdir <> None then
          (* Known issue: Windows strips out the blank entries in the search
             path (somewhat counterintuitively!) *)
          if Sys.win32 then
            main_outcome
          else
            "." :: main_outcome
        else
          []
      in
      [{base with description; stdlib = "" :: main; outcome}] in
    let tests =
      let description = "Base ld.conf + CAML_LD_LIBRARY_PATH" in
      (* As first, but with the same entries in CAML_LD_LIBRARY_PATH too *)
      let stdlib =
        if Sys.win32 then
          (* Known issue: Windows ignores empty entries in the search path, and
             it's slightly easier to test this only once in this test *)
          main
        else
          "" :: main
      in
      (* Part of the outcome from ld.conf. ocamlrun can't find ld.conf after the
         prefix has been renamed *)
      let outcome_ld_conf =
        if original || config.has_relative_libdir <> None then
          if Sys.win32 then
            main_outcome
          else
            "." :: main_outcome
        else
          []
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
      {base with description; caml_ld_library_path = Set stdlib; stdlib;
       outcome = outcome_caml_ld_library_path @ outcome_ld_conf} :: tests in
    let tests =
      let description = "Base ld.conf + CAML_LD_LIBRARY_PATH with quoting" in
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
      let outcome =
        (* ocamlrun can't find ld.conf after the prefix has been renamed *)
        if original || config.has_relative_libdir <> None then
          outcome_caml_ld_library_path @ main_outcome
        else
          outcome_caml_ld_library_path
      in
      {base with description; caml_ld_library_path = Set caml_ld_library_path;
       stdlib = main; outcome} :: tests in
    let tests =
      let description = "Base ld.conf with CRLF endings" in
      (* As first, but with a CR at the end of each line *)
      let stdlib = List.map (Fun.flip (^) "\r") ("" :: main) in
      let outcome =
        if original || config.has_relative_libdir <> None then
          (* Known issue: Windows strips out the blank entries in the search
             path (somewhat counterintuitively!) *)
          if Sys.win32 then
            main_outcome_cr
          else
            "." :: main_outcome_cr
        else
          (* ocamlrun can't find ld.conf after the prefix has been renamed *)
          []
      in
      {base with description; stdlib; outcome} :: tests in
    tests
  in
  (* Batch 2: effects of empty (vs unset) environment variables *)
  let tests =
    let tests =
      let description = "Empty CAML_LD_LIBRARY_PATH" in
      (* Empty CAML_LD_LIBRARY_PATH should add "." to the start of the search
         path *)
      let outcome =
        (* ocamlrun can't find ld.conf after the prefix has been renamed *)
        if original || config.has_relative_libdir <> None then
          ["ld.conf"]
        else
          []
      in
      (* Effect of CAML_LD_LIBRARY_PATH *)
      let outcome =
        if Sys.win32 then
          outcome
        else
          "." :: outcome
      in
      {base with description; caml_ld_library_path = Empty;
       stdlib = ["ld.conf"]; outcome} :: tests in
    let outcome =
      (* ocamlrun can't find ld.conf after the prefix has been renamed *)
      if original || config.has_relative_libdir <> None then
        ["masked-stdlib"]
      else
        []
    in
    let tests =
      let description = "Embedded empty entry in CAML_LD_LIBRARY_PATH" in
      (* Embedded empty entries in CAML_LD_LIBRARY_PATH should add equivalent
         "." entries to the search path *)
      let outcome =
        (* ocamlrun can't find ld.conf after the prefix has been renamed *)
        if original || config.has_relative_libdir <> None then
          ["ld.conf"]
        else
          []
      in
      (* Effect of CAML_LD_LIBRARY_PATH *)
      let outcome =
        if Sys.win32 then
          outcome
        else
          "." :: "." :: outcome
      in
      {base with description; caml_ld_library_path = Set [""; ""];
       stdlib = ["ld.conf"]; outcome} :: tests in
    let tests =
      let description = "Empty CAMLLIB" in
      (* An empty CAMLLIB shouldn't hide ld.conf in the Standard Library *)
      {base with description;
       caml_ld_library_path = Set ["env"]; camllib = Empty;
       stdlib = ["masked-stdlib"]; outcome = "env" :: outcome} :: tests in
    let tests =
      let description = "Empty OCAMLLIB" in
      (* An empty OCAMLLIB shouldn't hide ld.conf in either the Standard Library
         or CAMLLIB\ld.conf *)
      {description; caml_ld_library_path = Set ["env"]; ocamllib = Empty;
       camllib = Set ["masked-camllib"]; stdlib = ["masked-stdlib"];
       outcome = "env" :: "masked-camllib" :: outcome} :: tests in
    tests
  in
  (* Batch 3: load priority, embedded NUL characters, EOL-at-EOF, etc. *)
  let tests =
    let outcome =
      (* ocamlrun can't find ld.conf after the prefix has been renamed *)
      if original || config.has_relative_libdir <> None then
        ["libdir"]
      else
        []
    in
    let tests =
      let description = "$OCAMLLIB/ld.conf" in
      (* OCAMLLIB should have priority over CAMLLIB and the Standard Library *)
      {description; caml_ld_library_path = Set ["env"];
       ocamllib = Set ["ocamllib\000"; "hidden"];
       camllib = Set ["camllib\000"; "hidden"]; stdlib = ["libdir"];
       outcome = "env" :: "ocamllib" :: "camllib" :: outcome} :: tests in
    let tests =
      (* CAMLLIB should have priority over the Standard Library *)
      let description = "$CAMLLIB/ld.conf" in
      {base with description; caml_ld_library_path = Set ["env"];
       camllib = Set ["camllib\000"; "hidden"]; stdlib = ["libdir"];
       outcome = "env" :: "camllib" :: outcome} :: tests in
    let tests =
      (* EOL-at-EOF should not add a blank entry to the search path *)
      let description = "EOL-at-EOF" in
      let stdlib =
        if Sys.win32 then
          ["libdir\r\n"]
        else
          ["libdir\n"]
      in
      let outcome =
        (* ocamlrun can't find ld.conf after the prefix has been renamed *)
        if original || config.has_relative_libdir <> None then
          ["libdir"]
        else
          []
      in
      {base with description; stdlib; outcome} :: tests in
    tests
  in
  ensure_dir ocamllib_dir;
  ensure_dir camllib_dir;
  Format.printf "Backing up %a to %a\n" display_path libdir_ld_conf
                                        display_path backed_up_ld_conf;
  Sys.rename libdir_ld_conf backed_up_ld_conf;
  at_exit restore;
  List.iter run_test (List.rev tests);
  remove_if_exists ocamllib_ld_conf;
  remove_if_exists camllib_ld_conf;
  Sys.rmdir ocamllib_dir;
  Sys.rmdir camllib_dir;
  restore ();
  List.iter Sys.remove files

let write_test_program description =
  Out_channel.with_open_text "test_install_script.ml" @@ fun oc ->
    Printf.fprintf oc {|
let expected_executable_name = Sys.argv.(2)
let expected_argv0 = Sys.argv.(3)
let state = bool_of_string Sys.argv.(4)
let prefix = Sys.argv.(5)
let libdir_suffix = Sys.argv.(6)

let is_directory dir =
  try (Unix.stat dir).Unix.st_kind = Unix.S_DIR
  with Unix.(Unix_error(ENOENT, _, _)) -> false

let display_lib =
  let dir = Config.standard_library in
  let f = function '\\' when Sys.win32 -> '/' | c -> c in
  let canonical_dir = String.map f dir in
  let dir =
    if String.starts_with ~prefix canonical_dir then
      let l = String.length prefix in
      "$prefix" ^ String.sub dir l (String.length dir - l)
    else
      dir
  in
  if String.ends_with ~suffix:libdir_suffix canonical_dir then
    let l = String.length libdir_suffix in
    String.sub dir 0 (String.length dir - l) ^ "$libdir"
  else
    dir

let () =
  let kind, kind_info =
    if Filename.is_implicit Sys.executable_name then
      "implicit", " (" ^ Sys.executable_name ^ ")"
    else if Filename.is_relative Sys.executable_name then
      "relative", " (" ^ Sys.executable_name ^ ")"
    else
      "absolute", ""
  in
  Printf.%sfprintf stdout
    "%s: %%s\n\
     Sys.executable_name is %%s%%s\n\
     Sys.argv.(0) = %%s\n%%!" display_lib kind kind_info Sys.argv.(0);
  if is_directory Config.standard_library <> state then begin
    Printf.eprintf "  *** Directory %%sfound!\n" (if state then "not " else "");
    exit 1
  end else if Sys.executable_name <> expected_executable_name then begin
    Printf.eprintf "  *** Sys.executable_name should be %%s but is %%s\n"
                   expected_executable_name Sys.executable_name;
    exit 1
  end else if Sys.argv.(0) <> expected_argv0 then begin
    Printf.eprintf "  *** Sys.argv.(0) should be %%s but is %%s\n"
                   expected_argv0 Sys.argv.(0);
    exit 1
  end
|} (if verbose then "" else "i") description

let usr_bin_sh =
  let env = Environment.make bindir libdir in
  match Environment.run_process Return "sh" ["-c"; "command -v sh"] env with
  | (0, [where]) -> where
  | _ ->
      fail_because "Unexpected response from command -v sh"

(* [run_program ?runtime test_program expected_executable_name
                ~prefix_path_with_cwd expected_exit_code argv0 expected_argv0
                ~may_segfault ~arg] executes [test_program]. [argv0], [?runtime]
   and [~prefix_path_with_cwd] are passed to [Environment.run_process_target].
   [~arg], [expected_executable_name] and [expected_argv0] are passed with the
   arguments to [test_program] and the resulting execution is checked against
   [expected_exit_code]. [~may_segfault] is an escape hatch used for s390x tests
   which fail on RHEL/Fedora at the moment.
*)
let run_program =
  let prefix, libdir_suffix =
    if Sys.win32 then
      let f = function '\\' -> '/' | c -> c in
      String.map f prefix, String.map f libdir_suffix
    else
      prefix, libdir_suffix
  in
  fun env ?runtime test_program expected_executable_name ~prefix_path_with_cwd
      expected_exit_code argv0 expected_argv0 ~may_segfault ~arg ->
    let args = [string_of_bool arg; prefix; libdir_suffix] in
    let argv0 =
      if argv0 = test_program then
        None
      else
        Some argv0
    in
    let args = "skip" :: expected_executable_name :: expected_argv0 :: args in
    let should_fail = (expected_exit_code <> 0) in
    let (exit_code, output) =
      Environment.run_process_target
        Return ?runtime test_program ?argv0 args ~prefix_path_with_cwd
        ~should_fail env
    in
    Environment.display_output output;
    if exit_code <> expected_exit_code
       && (not may_segfault || exit_code <> 139) then
      fail_because
        "%s is expected to return with exit code %d"
        test_program expected_exit_code

(* Describe the various ways in which executables can be produced by our two
   compilers... *)
type compiler = C_ocamlc | C_ocamlopt
type runtime_mode = Shared | Static
type linkage =
| Default of compiler
| Custom of runtime_mode
| Output_obj of compiler * runtime_mode
| Output_complete_obj of compiler * runtime_mode
| Output_complete_exe of runtime_mode

(* Each execution of a test program sets Sys.argv.(0) and may optionally require
   the current working directory (cwd - i.e. ".") to be added at the start of
   $PATH. *)
type execution = {
  argv0: string;
  prefix_path_with_cwd: bool;
}

(* Additionally, each execution is tagged with whether Sys.argv.(0) either
   doesn't exist or is not an OCaml program and what value it would be after
   being passed to caml_search_exe_in_path *)
type execution_properties = {
  argv0_not_ocaml: bool;
  argv0_resolved: string
}

(* Given an executable, execution and a platform's details, an outcome describes
   what is expected to happen when running the test - a test should either fail
   with a given non-zero exit code, or return with exit code 0 having verified
   that Sys.argv.(0) and Sys.executable_name match the stated values. *)
type outcome =
| Fail of int
| Success of {executable_name: string; argv0: string}

(* [compile_test ~original env bindir test test_program description] builds
   [test_program] to execute [test] using the compiler binaries in [bindir]
   executed in [env]. The compiler is invoked explicitly (PATH-resolution is not
   used). [~original] indicates whether the compiler is still in its original
   prefix (i.e. the prefix has not yet been renamed). *)
let compile_test ~original env bindir libdir =
  let runtime =
    (* ocamlopt is always executable after rename as it's ocamlopt.opt *)
    if original || ocamlc_executable_after_rename then
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
    (* Convert a test to the required properties needed to build and run it:
       - use_shared_runtime is true if -runtime-variant _shared is needed, etc.
       - needs_ocamlopt allows tests on bytecode-only builds to be skipped
       - options is a list of flags to be passed to the compiler
       - main_in_c is true if the compiler is expected to be a produce an
         intermediate object file which must then be linekd with the test
         harness's own main_in_c.o
       - compilation_exit_code, linker_exit_code and may_segfault allow known
         issues with the tests to be expressed, permitting the process to fail
         at either compilation, linking or execution time.
       - clibs prepends any additional C libraries which must be passed when
         linking (implies main_in_c is true) *)
    let use_shared_runtime, needs_ocamlopt, options, main_in_c,
        compilation_exit_code, linker_exit_code, may_segfault, clibs =
      let f ?(use_shared_runtime = false) ?(needs_ocamlopt = false)
            ?(calls_linker = needs_ocamlopt) ?(compilation_exit_code = 0)
            ?(linker_exit_code = 0) ?(may_segfault = false) ?clibs options =
        let main_in_c = clibs <> None in
        let clibs = Option.value ~default:[] clibs in
        let compilation_exit_code, linker_exit_code =
          (* If
             - the prefix has been renamed
             - the linker is needed
             - the linker is flexlink, not the C compiler
             - the system does support native compilation
             - the launcher does not search for ocamlrun
             Yours... is an error, my son! *)
          if not original && calls_linker && linker_is_flexlink &&
             not config.has_ocamlopt && not launcher_searches_for_ocamlrun then
            if main_in_c then
              compilation_exit_code, 2
            else
              2, linker_exit_code
          else
            compilation_exit_code, linker_exit_code
        in
        use_shared_runtime, needs_ocamlopt, options, main_in_c,
        compilation_exit_code, linker_exit_code, may_segfault, clibs
      in
      let fails_if ?(compilation_exit_code = 2) cond =
        if cond then
          compilation_exit_code
        else
          0
      in
      match test with
      | Default C_ocamlc ->
          f []
      | Default C_ocamlopt ->
          f ~needs_ocamlopt:true []
      | Custom Static ->
          f ~calls_linker:true ["-custom"]
      | Custom Shared ->
          (* Shared compilation isn't available on native Windows and fails on
             Cygwin *)
          let compilation_exit_code = fails_if (Sys.win32 || Sys.cygwin) in
          f ~calls_linker:true ~use_shared_runtime:true ~compilation_exit_code
            ["-custom"]
      | Output_obj(C_ocamlc, Static) ->
          f ~clibs:["-lunixbyt"] ["-output-obj"]
      | Output_obj(C_ocamlc, Shared) ->
          (* Shared compilation isn't available on native Windows and fails on
             Cygwin *)
          let linker_exit_code = fails_if (Sys.win32 || Sys.cygwin) in
          f ~use_shared_runtime:true ~clibs:["-lunixbyt"] ~linker_exit_code
            ["-output-obj"]
      | Output_obj(C_ocamlopt, Static) ->
          f ~needs_ocamlopt:true
            ~clibs:["-lcomprmarsh"; "-lunixnat"; Config.compression_c_libraries]
            ["-output-obj"]
      | Output_obj(C_ocamlopt, Shared) ->
          (* cf. ocaml/ocaml#13693 - on Fedora/RHEL, this executable
             segfaults *)
          let may_segfault = (Config.architecture = "s390x") in
          (* Shared compilation isn't available on native Windows and fails on
             Cygwin *)
          let linker_exit_code = fails_if (Sys.win32 || Sys.cygwin) in
          f ~needs_ocamlopt:true ~use_shared_runtime:true ~may_segfault
            ~clibs:["-lcomprmarsh"; "-lunixnat"; Config.compression_c_libraries]
            ~linker_exit_code ["-output-obj"]
      | Output_complete_obj(C_ocamlc, Static) ->
          (* At the moment, the partial linker will pass -lws2_32 and -ladvapi32
             on to the partial linker on mingw-w64 which causes a failure. Until
             this is fixed, pass the libraries manually, using -noautolink. *)
          f ~clibs:[]
            ["-output-complete-obj"; "-noautolink"; "-cclib"; "-lunixbyt"]
      | Output_complete_obj(C_ocamlc, Shared) ->
          (* The partial linker doesn't correctly process
             -runtime-variant _shared, as the .so gets passed to the partial
             linker. On macOS, this causes a warning; on other systems, it's an
             error. *)
          let compilation_exit_code = fails_if (Config.system <> "macosx") in
          (* Shared compilation isn't available on native Windows and fails on
             Cygwin *)
          let linker_exit_code = fails_if (Sys.win32 || Sys.cygwin) in
          f ~use_shared_runtime:true ~clibs:[] ~compilation_exit_code
            ~linker_exit_code ["-output-complete-obj"]
      | Output_complete_obj(C_ocamlopt, Static) ->
          let linker_exit_code =
            (* cf. ocaml/ocaml#13692 - linking fails on ppc64 *)
            if Config.architecture = "power" then
              1
            else
              0
          in
          (* At the moment, the partial linker will pass -lzstd to ld -r which
             will (normally) fail). Until this is done, pass the libraries
             manually, using -noautolink. *)
          f ~needs_ocamlopt:true ~clibs:[Config.compression_c_libraries]
            ~linker_exit_code
            ["-output-complete-obj"; "-noautolink"; "-cclib"; "-lunixnat";
                                                    "-cclib"; "-lcomprmarsh"]
      | Output_complete_obj(C_ocamlopt, Shared) ->
          (* ocamlopt doesn't correctly implement -runtime-variant _shared *)
          let compilation_exit_code = fails_if true in
          f ~needs_ocamlopt:true ~use_shared_runtime:true
            ~compilation_exit_code ~clibs:[Config.compression_c_libraries]
            ["-output-complete-obj"; "-noautolink"; "-cclib"; "-lunixnat";
                                                    "-cclib"; "-lcomprmarsh"]
      | Output_complete_exe Static ->
          f ~calls_linker:true ["-output-complete-exe"]
      | Output_complete_exe Shared ->
          (* Shared compilation isn't available on native Windows and fails on
             Cygwin *)
          let compilation_exit_code = fails_if (Sys.win32 || Sys.cygwin) in
          f ~calls_linker:true ~use_shared_runtime:true ~compilation_exit_code
            ["-output-complete-exe"]
    in
    if use_shared_runtime && not config.supports_shared_libraries
    || needs_ocamlopt && not config.has_ocamlopt then
      (* This test cannot be compiled because OCaml has been configured without
         required support *)
      None
    else
      let test_program_path = Filename.concat test_root (exe test_program) in
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
          clibs @ libraries
        in
        let exit_code =
          let summarise f () =
            List.iter (fun x -> Format.pp_print_char f ' '; display_path f x)
                      (test_program_path :: output :: main_object :: flags)
          in
          Format.printf "@{<inline_code>$CC -o%a@}\n%!" summarise ();
          Ccomp.call_linker Ccomp.Exe test_program_path [output; main_object]
                            (String.concat " " flags)
        in
        if exit_code <> linker_exit_code then
          fail_because "Linker returned with exit code %d instead of %d"
                       exit_code linker_exit_code
        else if exit_code <> 0 then
          false
        else begin
          Sys.remove output;
          true
        end
      in
      let output =
        if main_in_c then
          "test_install_ocaml" ^ Config.ext_obj
        else
          test_program_path
      in
      write_test_program description;
      let ocamlcommon, unix =
        if needs_ocamlopt then
          "ocamlcommon.cmxa", "unix.cmxa"
        else
          "ocamlcommon.cma", "unix.cma"
      in
      let options =
        if use_shared_runtime then
          "-runtime-variant" :: "_shared" :: options
        else
          options
      in
      let options =
        if original && config.has_relative_libdir = None then
          let new_libdir = Filename.concat (prefix ^ ".new") libdir_suffix in
          let stdlib_default = "standard_library_default=" ^ new_libdir in
          let options = "-set-runtime-default" :: stdlib_default :: options in
          if test = Default C_ocamlc then (* XXX Temp *)
            "-dllpath" :: (Filename.concat libdir "stublibs") :: options
          else
            options
        else
          options
      in
      let args =
        "-I" :: "+compiler-libs" :: ocamlcommon ::
        "-I" :: "+unix" :: unix ::
        "-o" :: output ::
        "test_install_script.ml" :: options
      in
      let args =
        if verbose then
          "-verbose" :: args
        else
          args
      in
      let exit_code =
        let exit_code, output =
          Environment.run_process Return ?runtime compiler args env
        in
        Environment.display_output output;
        exit_code
      in
      if exit_code <> compilation_exit_code then
        fail_because "%s is expected to return with exit code %d"
                     compiler compilation_exit_code
      else if exit_code <> 0 then
        (* Nothing to run because compilation of the test is known to fail *)
        None
      else
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
        if main_in_c && not (compile_with_main_in_c output) then
          (* Nothing to run because linking the test is known to fail *)
          None
        else
          let executable = classify_executable test_program_path in
          (* Each test is compiled twice - in the original prefix
             (~original:true) and in the renamed prefix (~original:false).
             Additionally, the tests compiled in the original prefix are
             _executed_ a second time after the prefix has been renamed, which
             is what this slightly convoluted run function sets up *)
          let rec run ~original ?runtime env ~arg =
            (* Bytecode executables with absolute headers will need to be
               invoked via ocamlrun after the prefix has been renamed. *)
            let runtime =
              if (not original && config.has_relative_libdir = None || not arg)
              && (executable = Shebang || executable = Tendered)
              && not target_launcher_searches_for_ocamlrun then
                runtime
              else
                None
            in
            (* Each executable is invoked with six different values of
               Sys.argv.(0):
               1. "test-prog";  a non-existent command
               2. "sh"; a command which will resolve in PATH
               3. "./exe-name"; a relative invocation of the executable
               4. "exe-name"; an implicit invocation where "." is not in PATH
               5. "exe-name"; an implicit invocation but with "." in PATH
               6. "/../exe-name"; an absolute invocation of the executable
               In each instance, the executable is passed additional arguments:
                 1: "skip" - this argument is designed to be an implicit
                    filename which won't resolve in PATH (since some invocations
                    with Sys.argv.(0) will effectively attempt to execute
                    Sys.argv.(1))
                 2: The expected value of Sys.executable_name
                 3: The expected value of Sys.argv.(0)
                 4. true/false depending on whether Config.standard_library
                    should exist
                 5. The prefix (used to display names as $prefix/)
                 6. The libdir (used to allow $prefix/$libdir)
               The test program returns exit code 1 if:
                 - Sys.executable_name doesn't equal Sys.argv.(2)
                 - Sys.argv.(0) doesn't equal Sys.argv.(3)
                 - Config.standard_library exists when it shouldn't (or vice
                   versa) *)
            let tests =
              let test_program_relative =
                Filename.concat Filename.current_dir_name test_program
              in [
              (* Run 0 - Sys.argv.(0) is /path/to/test_program (absolute) *)
              {argv0 = test_program_path; prefix_path_with_cwd = false},
              {argv0_not_ocaml = false; argv0_resolved = test_program_path};
              (* Run 1 - Sys.argv.(0) = "test-prog" *)
              {argv0 = "test-prog"; prefix_path_with_cwd = false},
              {argv0_not_ocaml = true; argv0_resolved = "test-prog"};
              (* Run 2 - Sys.argv.(0) = "sh" *)
              {argv0 = "sh"; prefix_path_with_cwd = false},
              {argv0_not_ocaml = true; argv0_resolved = usr_bin_sh};
              (* Run 3 - Sys.argv.(0) is ./test_program (relative) *)
              {argv0 = test_program_relative; prefix_path_with_cwd = false},
              {argv0_not_ocaml = false; argv0_resolved = test_program_relative};
              (* Run 4 - Sys.argv.(0) is test_program (implicit, without
                         PATH) *)
              {argv0 = test_program; prefix_path_with_cwd = false},
              {argv0_not_ocaml = false; argv0_resolved = test_program};
              (* Run 5 - Sys.argv.(0) is test_program (implicit, with PATH) *)
              {argv0 = test_program; prefix_path_with_cwd = true},
              {argv0_not_ocaml = false; argv0_resolved = test_program_relative}
            ] in
            let runs =
              let test_with_outcome (({argv0; _} as test), properties) =
                let {argv0_not_ocaml; argv0_resolved} = properties in
                let outcome =
                  (* If runtime has been specified, this program is going to be
                     executed as ocamlrun test_program_path ... *)
                  if runtime <> None then
                    Success {executable_name = test_program_path;
                             argv0 = test_program_path}
                  else
                    match executable with
                    | Shebang ->
                        (* Likewise, shebang executables, regardless of the
                           input argv[0], will just see test_program_path *)
                        Success {executable_name = test_program_path;
                                 argv0 = test_program_path}
                    | Tendered ->
                        if argv0_not_ocaml then
                          if Sys.win32 then
                            (* stdlib/headernt.c will find ocamlrun (because it
                               effectively uses caml_executable_name) but fails
                               to hand off the bytecode image, which causes
                               ocamlrun to exit with code 127 *)
                            Fail 127
                          else
                            (* stdlib/header.c will fail to find ocamlrun,
                               because it never uses caml_executable_name and so
                               will either fail to find the executable or will
                               identify that it is not a bytecode executable.
                               Somewhat confusingly, it exits with code 2 *)
                            Fail 2
                        else if Sys.win32 then
                          (* stdlib/headernt.c correctly preserves argv[0] *)
                          Success {executable_name = test_program_path; argv0}
                        else
                          (* stdlib/header.c does not preserve argv[0] *)
                          Success {executable_name = argv0_resolved;
                                   argv0 = argv0_resolved}
                    | Custom ->
                        if no_caml_executable_name then
                          if argv0_not_ocaml then
                            (* -custom executables are ocamlrun, but will be
                               unable to launch the bytecode image without
                               caml_executable_name. ocamlrun exits with
                               code 127 in this situation *)
                            Fail 127
                          else
                            Success {executable_name = argv0_resolved; argv0}
                        else
                          if Sys.win32 || argv0_not_ocaml then
                            (* SearchPath will resolve the relative/implicit
                               arguments to absolute paths *)
                            Success {executable_name = test_program_path; argv0}
                          else
                            Success {executable_name = argv0_resolved; argv0}
                    | Native ->
                        if no_caml_executable_name then
                          Success {executable_name = argv0_resolved; argv0}
                        else
                          Success {executable_name = test_program_path; argv0}
                in
                test, outcome
              in
              List.map test_with_outcome tests
            in
            let execute ({argv0; prefix_path_with_cwd}, outcome) =
              let expected_executable_name, expected_exit_code, expected_argv0 =
                match outcome with
                | Fail code -> "", code, ""
                | Success {executable_name; argv0} -> executable_name, 0, argv0
              in
              run_program env ?runtime test_program_path ~prefix_path_with_cwd
                          expected_executable_name expected_exit_code
                          argv0 expected_argv0 ~may_segfault ~arg
            in
            List.iter execute runs;
            print_newline ();
            if original then
              Some (run ~original:false)
            else
              (Sys.remove test_program_path; None)
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
let test_standard_library_location ~original env bindir libdir =
  Format.printf "\nTesting compilation mechanisms for %a\n%!"
                display_path bindir;
  let ocamlc = Filename.concat bindir (exe "ocamlc") in
  let ocamlopt = Filename.concat bindir (exe "ocamlopt") in
  let ocamlc_where =
    let runtime =
      if original || ocamlc_executable_after_rename then
        None
      else
        Some (Filename.concat bindir (exe "ocamlrun"))
    in
    compiler_where env ?runtime ocamlc in
  let ocamlopt_where =
    if config.has_ocamlopt then
      compiler_where env ocamlopt
    else
      "n/a"
  in
  Format.printf "ocamlc -where: %a\nocamlopt -where: %a\n%!"
                display_path ocamlc_where display_path ocamlopt_where;
  let compile_test = compile_test ~original env bindir libdir in
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
  (* The test programs compiled before the prefix renamed and re-executed after
     it is renamed which means that the runtime location is passed to each test.
     Each test individually determines if the runtime is actually passed to the
     invocation of the executable. *)
  let runtime =
    if original || target_launcher_searches_for_ocamlrun then
      None
    else
      Some (Filename.concat bindir (exe "ocamlrun"))
  in
  Printf.printf "Running programs\n%!";
  let arg = config.has_relative_libdir <> None || not original in
  List.filter_map (fun f -> f ?runtime env ~arg) programs

let utf_16le_of_utf_8 s =
  let s = Misc.Stdlib.String.to_utf_8_seq s in
  let utf_16le_length =
    Seq.fold_left (fun acc u -> acc + Uchar.utf_16_byte_length u) 0 s in
  let b = Bytes.create utf_16le_length in
  ignore (Seq.fold_left (fun i u -> i + Bytes.set_utf_16le_uchar b i u) 0 s);
  Bytes.unsafe_to_string b

let rec matches_at file search i j =
  let c1 = Bigarray.Array1.unsafe_get file i in
  let c2 = String.unsafe_get search j in
  (c1 = c2 || Sys.win32 && c1 = '\\' && c2 = '/')
    && (j = 0 || matches_at file search (i - 1) (j - 1))

let matches_at file file_len i s =
  let s_len = String.length s in
  if i + s_len > file_len then
    false
  else
    matches_at file s (i + s_len - 1) (s_len - 1)

type location = Build | Prefix | Relative
and encoding = UTF_8 | UTF_16

module LocationSet = Set.Make(struct
  type t = location
  let compare = Stdlib.compare
end)

let rec contains file file_len tests i seen =
  if i = file_len then
    seen
  else
    let c = Bigarray.Array1.unsafe_get file i in
    let seen =
      if c = '/' || Sys.win32 && c = '\\' then
        let check_for ((seen, unmatched) as acc) (t, s, always_test) =
          if (unmatched || always_test) && matches_at file file_len i s then
            t::seen, false
          else
            acc in
        fst (List.fold_left check_for (seen, true) tests)
      else
        seen in
    contains file file_len tests (i + 1) seen

let read_file file =
  In_channel.with_open_bin file @@ fun ic ->
    let len = in_channel_length ic in
    let content = Bigarray.Array1.create Bigarray.Char Bigarray.c_layout len in
    if In_channel.really_input_bigarray ic content 0 len = None then
      fail_because "Error reading %s" file;
    content, len

let clang_cl = String.starts_with ~prefix:"clang-cl" Config.c_compiler

let test_relocation prefix bindir libdir =
  let build_root = Filename.dirname (Filename.dirname test_root) in
  Printf.printf "\nChecking installed files for\n\
                  \  Installation Prefix: %s\n\
                  \  Build Root: %s\n%!" prefix build_root;
  let relative_libdir, build_root, prefix =
    let relative = Option.map ((^) "/") config.has_relative_libdir in
    if Sys.win32 then
      let normalise s =
        let s =
          if String.length s > 2
             && Char.Ascii.is_letter s.[0] && s.[1] = ':' then
            String.sub s 2 (String.length s - 2)
          else
            s in
        String.map (function '\\' -> '/' | c -> c) s in
      Option.map normalise relative, normalise build_root, normalise prefix
    else
      relative, build_root, prefix in
  let prefix_in_build =
    split_to_common_prefix prefix build_root = Result.Error `First_in_second in
  let tests = [
    (Prefix, UTF_8), prefix, true;
    (Prefix, UTF_16), utf_16le_of_utf_8 prefix, true;
    (Build, UTF_8), build_root, not prefix_in_build;
    (Build, UTF_16), utf_16le_of_utf_8 build_root, not prefix_in_build;
  ] in
  let tests =
    match relative_libdir with
    | Some relative_libdir ->
        ((Relative, UTF_8), relative_libdir, true) ::
        ((Relative, UTF_16), utf_16le_of_utf_8 relative_libdir, true) :: tests
    | None ->
        tests in
  let in_unexpected_state file file_rel rules =
    let content, content_len = read_file file in
    let seen = contains content content_len tests 0 [] in
    let gather acc (d, _, _) =
      if List.mem d seen then
        match d with
        | Build, UTF_8 ->
            LocationSet.add Build acc, Some "Build directory (in UTF-8)"
        | Build, UTF_16 ->
            LocationSet.add Build acc, Some "Build directory (in UTF-16)"
        | Prefix, UTF_8 ->
            LocationSet.add Prefix acc, Some "Installation prefix (in UTF-8)"
        | Prefix, UTF_16 ->
            LocationSet.add Prefix acc, Some "Installation prefix (in UTF-16)"
        | Relative, UTF_8 ->
            LocationSet.add Relative acc, Some "Relative prefix (in UTF-8)"
        | Relative, UTF_16 ->
            LocationSet.add Relative acc, Some "Relative prefix (in UTF-16)"
      else
        acc, None in
    let seen, hits = List.fold_left_map gather LocationSet.empty tests in
    let expected = rules file in
    if LocationSet.equal seen expected then
      false
    else
      let string_of_location = function
      | Build -> "Build directory"
      | Prefix -> "Installation prefix"
      | Relative -> "Relative prefix" in
      let hits =
        let hits = List.filter_map Fun.id hits in
        if hits = [] then
          "is relocatable"
        else
          "contains the " ^ String.concat " & " hits in
      let expected =
        let expected = LocationSet.elements expected in
        if expected = [] then
          "be relocatable"
        else
          let expected = List.map string_of_location expected in
          "contain the " ^ String.concat " & " expected in
      Printf.eprintf "%s: expected to %s, but it %s\n" file_rel expected hits;
      true
  in
  let rec scan failed dir rel h rules =
    match Unix.readdir h with
    | entry ->
        let failed =
          if entry <> Filename.current_dir_name
             && entry <> Filename.parent_dir_name then
            let entry_rel = Filename.concat rel entry in
            let entry = Filename.concat dir entry in
            match Unix.lstat entry with
            | {Unix.st_kind = S_DIR; _} ->
                scan failed entry entry_rel (Unix.opendir entry) rules
            | {Unix.st_kind = S_REG; _} ->
                in_unexpected_state entry entry_rel rules || failed
            | _ ->
                failed
          else
            failed in
        scan failed dir rel h rules
    | exception End_of_file ->
        Unix.closedir h;
        failed in
  let bindir_rules file =
    let basename = Filename.basename file in
    let basename =
      Filename.chop_suffix_opt ~suffix:".exe" basename
      |> Option.value ~default:basename in
    let basename_without_type =
      Filename.chop_suffix_opt ~suffix:".opt" basename
      |> Option.value ~default:basename in
    let basename_without_type =
      Filename.chop_suffix_opt ~suffix:".byte" basename
      |> Option.value ~default:basename_without_type in
    let classification = classify_executable file in
    if classification = Tendered && basename <> "ocaml" then
      if not launcher_searches_for_ocamlrun
         || (config.has_relative_libdir = None
             && basename_without_type <> "flexlink"
             && basename_without_type <> "ocamllex") then
        LocationSet.singleton Prefix
      else
        LocationSet.empty
    else if classification = Shebang && basename <> "ocaml" then
      LocationSet.singleton Prefix
    else if basename = "default.manifest"
            || basename = "default_amd64.manifest" then
      LocationSet.empty
    else
      let prefix =
        if config.has_relative_libdir = None
             && basename <> "ocamlyacc"
             && basename_without_type <> "ocamllex"
             && basename_without_type <> "flexlink"
           || basename = "ocaml" && not launcher_searches_for_ocamlrun then
          LocationSet.singleton Prefix
        else
          LocationSet.empty in
      if Config.ccomp_type = "msvc"
           && basename <> "ocaml"
           && (not (List.mem "ocamlrund" (String.split_on_char '-' basename))
                 || clang_cl) then
        prefix
      else if config.has_relative_libdir = None
              || (Config.system = "macosx" || not Config.c_has_debug_prefix_map)
                   && basename <> "ocaml" then
        LocationSet.add Build prefix
      else
        prefix
  in
  let libdir_files_with_prefix =
    let (/) = Filename.concat in
    let files = [
      "Makefile.config";
    ] in
    let files =
      if config.has_relative_libdir <> None then
        if launcher_searches_for_ocamlrun then
          files
        else
          "expunge" :: files
      else
        "expunge" ::
        "runtime-launch-info" ::
        ("compiler-libs" / "ocamlcommon.cma") ::
        ("compiler-libs" / "ocamlcommon" ^ Config.ext_lib) ::
        ("compiler-libs" / "config.cmx") ::
        files in
    let files =
      if config.has_relative_libdir = None &&
           Config.compression_c_libraries = "" then
        "compiler-libs" / "config.cmt" ::
        "compiler-libs" / "config_main.cmt" ::
        files
      else
        files in
    StringSet.of_list (List.map (Filename.concat libdir) files) in
  let libdir_files_with_relative_prefix =
    if config.has_relative_libdir = None then
      StringSet.empty
    else
      let files = ["Makefile.config"] in
      StringSet.of_list (List.map (Filename.concat libdir) files) in
  let libdir_exts_with_build =
    let exts =
      if config.has_relative_libdir <> None then
        []
      else
        [".cmo"; ".cma"] in
    let exts =
      if (not Sys.win32 && Config.system <> "macosx"
          && (not Config.c_has_debug_prefix_map
              || config.has_relative_libdir = None))
         || Config.ccomp_type = "msvc" then
        Config.ext_obj :: exts
      else
        exts in
    let exts =
      if Config.ccomp_type = "msvc"
         || (config.has_relative_libdir <> None
               && Config.system <> "macosx") then
        exts
      else
        Config.ext_dll :: ".cmxs" :: exts in
    let exts =
      if config.has_relative_libdir = None
         && Config.compression_c_libraries = "" then
        ".cmti" :: ".cmt" :: exts
      else
        exts in
    StringSet.of_list exts in
  let libdir_rules file =
    if Sys.cygwin && Filename.basename (Filename.dirname file) = "flexdll" then
      LocationSet.empty
    else
      let file =
        Filename.chop_suffix_opt ~suffix:".exe" file
        |> Option.value ~default:file in
      let ext = Filename.extension file in
      let build =
        if StringSet.mem ext libdir_exts_with_build then
          LocationSet.singleton Build
        else if config.has_relative_libdir <> None
                  && Config.c_has_debug_prefix_map then
          LocationSet.empty
        else if ext = Config.ext_lib then
          if clang_cl then
            if String.starts_with ~prefix:"libasmrun" (Filename.basename file)
               || (Sys.file_exists
                     (Filename.remove_extension file ^ ".cmxa")) then
              LocationSet.singleton Build
            else
              LocationSet.empty
          else if (not Sys.win32 && Config.system <> "macosx")
                  || Config.ccomp_type = "msvc"
                  || not (Sys.file_exists
                            (Filename.remove_extension file ^ ".cmxa")) then
            LocationSet.singleton Build
          else
            LocationSet.empty
        else
          LocationSet.empty in
      let build_and_prefix =
        if StringSet.mem file libdir_files_with_prefix then
          LocationSet.add Prefix build
        else
          build in
      if StringSet.mem file libdir_files_with_relative_prefix then
        LocationSet.add Relative build_and_prefix
      else
        build_and_prefix
  in
  let failed =
    scan false bindir "$bindir" (Unix.opendir bindir) bindir_rules in
  let failed =
    scan failed libdir "$libdir" (Unix.opendir libdir) libdir_rules in
  if failed then
    fail_because "Installed files don't match expectation"

let run_tests ~original env bindir libdir libraries =
  if config.supports_shared_libraries then
    load_libraries_in_toplevel ~original env bindir libdir Bytecode libraries;
  if config.has_ocamlnat then
    load_libraries_in_toplevel ~original env bindir libdir Native libraries;
  if config.supports_shared_libraries then
    load_libraries_in_prog ~original env bindir libdir Bytecode libraries;
  if config.has_ocamlopt && config.supports_shared_libraries then
    load_libraries_in_prog ~original env bindir libdir Native libraries;
  test_ld_conf ~original env bindir libdir;
  test_bytecode_binaries ~original env bindir;
  test_standard_library_location ~original env bindir libdir

let () =
  (* Run all tests in the supplied prefix *)
  Compmisc.init_path ();
  if verbose then
    Clflags.verbose := true;
  let env = Environment.make bindir libdir in
  let programs = run_tests ~original:true env bindir libdir config.libraries in
  let () = test_relocation prefix bindir libdir in
  (* Now rename the prefix, appending .new to the directory name *)
  let new_prefix = prefix ^ ".new" in
  let bindir = Filename.concat new_prefix bindir_suffix in
  let libdir = Filename.concat new_prefix libdir_suffix in
  Format.printf "Renaming %a to %a\n\n%!" display_path prefix
                                          display_path new_prefix;
  Sys.rename prefix new_prefix;
  at_exit (fun () ->
    flush stderr;
    flush stdout;
    Format.printf "Restoring %a to %a\n" display_path new_prefix
                                         display_path prefix;
    Sys.rename new_prefix prefix);
  (* Re-run the test programs compiled with the normal prefix *)
  Printf.printf "Re-running test programs\n%!";
  (* Finally re-run all of the tests with the new prefix *)
  let caml_ld_library_path =
    assert (not relocatable);
    Some [Filename.concat libdir "stublibs"]
  in
  let ocamllib =
    if config.has_relative_libdir = None then Some libdir else None in
  let env = Environment.make ?caml_ld_library_path bindir libdir in
  let runtime =
    if target_launcher_searches_for_ocamlrun then
      None
    else
      Some (Filename.concat bindir (exe "ocamlrun"))
  in
  let re_run f =
    assert (f ?runtime env ~arg:(config.has_relative_libdir = None) = None) in
  List.iter re_run programs;
  let env =
    Environment.make ?ocamllib bindir libdir
  in
  Compmisc.reinit_path ~standard_library:libdir ();
  let programs = run_tests ~original:false env bindir libdir config.libraries in
  assert (programs = [])
