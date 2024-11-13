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

(* Full path to testsuite/in_prefix in the build tree (i.e. where the harness is
   executed from and where it places files.) *)
let test_root = Sys.getcwd ()

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
  has_runtime_search: bool option;
    (* Not yet implemented; always None. *)
  libraries: string list list
    (* Sorted list of basenames of libraries to test.
       Derived from $(OTHERLIBRARIES) - Makefile.config *)
}

(* Split a directory into a list of directory portions, removing all the
   separators. The path can be constructed by folding [Filename.concat] over the
   list.

   e.g. [split_dir [] "/usr/local/bin" = ["/"; "/usr"; "local"; "bin"]] *)
let rec split_dir acc dir =
  let dirname = Filename.dirname dir in
  if dirname = dir || dirname = Filename.current_dir_name then
    (* Deal with the oddity that [Filename.dirname "C:/" = "C:/"] (i.e. that
       the terminating slash remains and so reconstituting the path will end
       up with one slash at the start and then backslashes). *)
    if Sys.win32 && dir.[String.length dir - 1] = '/' then
      (String.sub dir 0 (String.length dir - 1) ^ "\\")::acc
    else
      dir::acc
  else
    split_dir (Filename.basename dir :: acc) dirname

(* XXX Misc.Stdlib.List.find_and_chop_longest_common_prefix ? *)
let split_to_common_prefix first second =
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

(* XXX Other things will go in here from below, too) *)
module Toolchain = struct
  let is_clang =
    List.mem "clang" (String.split_on_char '-' Config.c_compiler_vendor)

  let is_clang_assembler =
    (* The clang-cl build of the MSVC port still has to MASM at present *)
    is_clang && Config.ccomp_type <> "msvc"

  (* Determine two properties of the way programs are linked w.r.t. debug
     information: does debug information use absolute paths, and is (some) debug
     information in .o files always transferred to the resulting executable,
     even if it is not linked with -g. These are properties of the platform, so
     there should be no file-specific references in these definitions. *)
  let (~absolute_paths:c_compiler_debug_paths_can_be_absolute,
       ~implicit_debug_info:linker_propagates_debug_information,
       ~embeds:c_compiler_always_embeds_build_path,
       ~asmrun_assembled_with_cc) =
    if Config.ccomp_type = "msvc" then
      (* The MSVC port calls the linker directly, and debugging information is
         not propagated. At present, building with clang-cl also uses the
         Microsoft Linker. clang-cl, however, embeds relative paths in objects
         (for reasons which are not entirely clear) *)
      (~absolute_paths:(not is_clang),
       ~implicit_debug_info:false,
       ~embeds:true,
       ~asmrun_assembled_with_cc:false)
    else
      (~absolute_paths:true,
       ~implicit_debug_info:true,
       ~embeds:false,
       ~asmrun_assembled_with_cc:true)

  let assembler_embeds_build_path =
    not (String.starts_with ~prefix:"mingw" Config.system)
    && not is_clang_assembler

  let linker_embeds_build_path =
    Config.system = "macosx"
end

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
let orig_bindir, orig_libdir, prefix, bindir_suffix, libdir_suffix, config,
    test_root, test_root_logical, bytecode_shebangs_by_default, reproducible,
    verbose =
  let show_summary = ref false in
  let verbose = ref false in
  let test_root = ref test_root in
  let test_root_logical = ref None in
  let bindir = ref "" in
  let libdir = ref "" in
  let config =
    ref {supports_shared_libraries = false; has_ocamlnat = false;
         has_ocamlopt = false; has_relative_libdir = None;
         has_runtime_search = None; libraries = []}
  in
  let process_pwd dir =
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
    if Sys.win32 then
      (* --pwd is ignored on Windows, since Sys.getcwd is automatically the
         logical CWD. *)
      let test_root_physical = Unix.realpath !test_root in
      if test_root_physical <> !test_root then begin
        test_root_logical := Some !test_root;
        test_root := test_root_physical
      end else ()
    else if dir <> !test_root then
      test_root_logical := Some dir
  in
  let check_exists ~absolute r dir =
    if Filename.is_relative dir then
      if absolute then
        raise (Arg.Bad (dir ^ ": is not an absolute path"))
      else
        r := dir
    else if Sys.file_exists dir then
      if Sys.is_directory dir then
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
  let parse_search = function
  | "enable" -> true
  | "always" -> false
  | _ ->
      raise (Arg.Bad
        "--with-runtime-search: argument should be either enable or always")
  in
  let has_runtime_search arg =
    let has_runtime_search = Option.map parse_search arg in
    config := {!config with has_runtime_search}
  in
  let args = Arg.align [
    "--pwd", Arg.String process_pwd, "\
<pwd>\tCurrent working directory to use";
    "--bindir", Arg.String (check_exists ~absolute:true bindir), "\
<bindir>\tDirectory containing programs (must share a prefix with --libdir)";
    "--libdir", Arg.String (check_exists ~absolute:false libdir), "\
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
    "--with-runtime-search",
      Arg.String (fun s -> has_runtime_search (Some s)), "\
\tCompiler bytecode binaries can search for their runtimes";
    "--without-runtime-search",
      Arg.Unit (fun () -> has_runtime_search None), "";
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
  if bindir = "" || libdir = "" then
    let () = Arg.usage args usage in
    exit 2
  else
    let prefix, bindir_suffix, libdir, libdir_suffix, has_relative_libdir =
      if Filename.is_relative libdir then
        if Filename.is_implicit libdir then begin
          Printf.eprintf "%s: is not an explicit-relative path" libdir;
          exit 2
        end else
          let has_relative_libdir = Some libdir in
          let rec trim_dir bindir_suffix = function
          | bindir_tl::bindir_rev, libdir_hd::libdir
            when libdir_hd = Filename.parent_dir_name ->
              trim_dir (bindir_tl::bindir_suffix) (bindir_rev, libdir)
          | bindir_rev, libdir ->
              match List.rev bindir_rev with
              | hd::tl ->
                  let prefix = List.fold_left Filename.concat hd tl in
                  prefix, String.concat Filename.dir_sep bindir_suffix,
                  List.fold_left Filename.concat prefix libdir,
                  String.concat Filename.dir_sep libdir,
                  has_relative_libdir
              | [] ->
                  (* This should also have been rejected by configure *)
                  error "\
directories given for --bindir and --libdir do not have a common prefix" in
          trim_dir [] (List.rev (split_dir [] bindir), split_dir [] libdir)
      else
        match split_to_common_prefix bindir libdir with
        | Result.Ok (prefix, bindir_suffix, libdir_suffix) ->
            prefix, bindir_suffix, libdir, libdir_suffix, None
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
    if config.has_runtime_search <> None then
      error "--with-runtime-search is not implemented!";
    let no_markup ansi = { Misc.Style.ansi; text_close = ""; text_open = "" } in
    let runtime_launch_info =
      let file = Filename.concat libdir "runtime-launch-info" in
      Bytelink.read_runtime_launch_info file in
    let header_size =
      let {Bytelink.buffer; executable_offset; _} = runtime_launch_info in
      String.length buffer - executable_offset in
    let config = {config with has_relative_libdir} in
    let relocatable = false in
    let reproducible =
      relocatable
      && (not config.has_ocamlopt
          || not Toolchain.assembler_embeds_build_path
          || Config.as_has_debug_prefix_map)
      && not Toolchain.linker_embeds_build_path
      && (not Toolchain.c_compiler_always_embeds_build_path
          || not Toolchain.c_compiler_debug_paths_can_be_absolute)
    in
    let target_relocatable = false in
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
    if !show_summary then
      exit 0;
    bindir, Filename.concat prefix libdir_suffix, prefix, bindir_suffix,
    libdir_suffix, config, !test_root, !test_root_logical,
    (runtime_launch_info.launcher <> Bytelink.Executable), reproducible,
    !verbose

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
   - Vanilla executables (vanilla ocamlopt or any of the caml_startup mechanisms
     via -output-obj, -output-complete-exe, etc.). The actual OCaml program may
     be bytecode (but it will have been embedded in a C object). *)
type launch_mode = Header_exe | Header_shebang
type executable =
| Tendered of (header:launch_mode * dlls:bool)
| Custom
| Vanilla

let classify_executable file =
  try
    In_channel.with_open_bin file (fun ic ->
      let start = really_input_string ic 2 in
      let is_RNTM = function
      | Bytesections.{name = Name.RNTM; _} -> true
      | _ -> false
      in
      let is_DLLS = function
      | Bytesections.{name = Name.DLLS; len} when len > 0 -> true
      | _ -> false
      in
      let sections = Bytesections.(all (read_toc ic)) in
      if start = "#!" then
        Tendered(~header:Header_shebang, ~dlls:(List.exists is_DLLS sections))
      else if List.exists is_RNTM sections then
        Tendered(~header:Header_exe, ~dlls:(List.exists is_DLLS sections))
      else
        Custom)
  with End_of_file | Bytesections.Bad_magic_number ->
    Vanilla

let is_shebang program =
  if Filename.is_relative program then
    false
  else
    match classify_executable program with
    | Tendered(~header:Header_shebang, ~dlls:_) -> true
    | _ -> false

let[@ocaml.warning "-32"] launched_via_stub program =
  match classify_executable program with
  | Tendered(~header:Header_exe, ~dlls:_) -> true
  | _ -> false

(* Belt-and-braces file removal function - allow up to 30 seconds for
   Windows Defender and other nonsense *)
let rec erase_file retries path =
  try Sys.remove path
  with Sys_error _ when Sys.win32 ->
    (* Deal with read-only attribute on Windows. Ignore any error from chmod
       so that the message always come from Sys.remove *)
    let () = try Unix.chmod path 0o666 with Sys_error _ -> () in
    try Sys.remove path
    with Sys_error _ when retries > 0 ->
      Unix.sleep 1;
      erase_file (pred retries) path

let erase_file path = erase_file 30 path

(* Print a formatted message to [stderr] and [exit 1] *)
let fail_because fmt = Format.ksprintf (fun s -> prerr_endline s; exit 1) fmt

(* [string_of_process_status status] returns a loggable description of a
   [Unix.process_status] value. *)
let signal_of_int n =
  (* Perhaps Sys or Unix will acquire name_of_signal for Christmas *)
  if n = Sys.sigsegv then
    "SIGSEGV"
  else if n = Sys.sigabrt then
    "SIGABRT"
  else
    "OCaml signal number " ^ string_of_int n

let string_of_process_status = function
| Unix.WEXITED n -> "exit " ^ string_of_int n
| Unix.WSIGNALED n -> signal_of_int n
| Unix.WSTOPPED n -> "stopped with " ^ signal_of_int n

(* [Environment.run_process] either [Return]s the exit code and lines of output
   from running a command, or assumes it exits with code 0 and displays the
   output directly to standard output. *)
type _ output =
| Execute : unit output
| Return : (int * string list) output

type phase = Original | Renamed

type mode = Bytecode | Native

(* exe ["foo" = "foo.exe"] on Windows or ["foo"] otherwise. *)
let exe =
  if Sys.win32 then
    Fun.flip (^) ".exe"
  else
    Fun.id

module StringSet = Set.Make(String)

(* All process invocation is done via [Environment.run_process] and
   [Environment.run_process_target] which in particular abstracts and manages
   the environment ultimately passed to [Unix.create_process_env]. *)
module Environment : sig
  type t

  (* [make bindir libdir] creates a new environment where [bindir] will be in
     [PATH] and with [libdir] available for loading of shared libraries (i.e.
     with [LD_LIBRARY_PATH] / [DYLD_LIBRARY_PATH] set or updated).
     [?env] allows [CAML_LD_LIBRARY_PATH], [OCAMLLIB] and [CAMLLIB] to be set
     (they will be unset otherwise). *)
  val make : ?phase:phase -> string -> string -> t

  val is_renamed : t -> bool

  val bindir : t -> string

  val libdir : t -> string

  val tool_path : t -> mode -> string -> string -> string

  val ocamlrun : t -> string

  val in_libdir : t -> string -> string

  (* [run_process mode ?strategy ?fails program ?argv0 args environment]
     executes [program] with [args] in [environment]. Set [~fails:true] for
     commands which are not expected to exit with code 0. If [mode] is
     [Execute], then the output is displayed using [display_output] and the the
     function returns if the exit status is consistent with [?fails] (i.e. for
     [~fails:true], the command not exit normally with code 0; for
     [~fails:false], the default, it must exit with code 0). If [mode] is
     [Return], [~fails] merely controls the display of the command, and both the
     output of the command and its exit code are returned by the function.
     Unlike [Unix.create_process_env], [program] is automatically added at the
     start of [args], unless [~argv0] is specified, in which case it is added
     instead.
     [~strategy], if specified, allows a series of execution strategies to be
     tried. The last one in the list is the only one permitted to terminate
     normally with exit code 0. If [~ocamlrun = Some runtime], then [runtime] is
     executed instead of [program] with [program] instead passed as the first
     argument (and [argv0] is always ignored]) and a different environment can
     be used.
     run_process translates a few specific error conditions into exit codes:
     - If Unix.create_process fails with ENOENT for a #!-style bytecode image,
       this is translated to exit code 127
     - If a "tendered" image exits with code 2, this is translated to exit code
       code 127
     - SIGABRT is converted to exit code 134
     - On s390x, SIGSEGV is converted to exit code 139
     When [~quiet:false], [run_process] always displays the command being
     executed on stdout and any changes to the environment since the previous
     call to [run_process]. When [~quiet:true], details are only displayed if
     [--verbose] was specified or if the outcome of the command doesn't match
     [~fails]. *)
  val run_process :
    'a output -> ?runtime:bool -> ?stubs:bool -> ?stdlib:bool
    -> ?prefix_path_with_cwd:bool -> ?quiet:bool -> ?fails:bool -> t
    -> string -> ?argv0:string -> string list -> 'a

  val run_process_with_test_env :
    'a output -> ?runtime:bool
    -> caml_ld_library_path:string list option -> ocamllib:string option
    -> camllib:string option -> t -> ?quiet:bool -> ?fails:bool
    -> string -> ?argv0:string -> string list -> 'a

  (* Formats and displays the output lines of program on stdout *)
  val display_output : string list -> unit
end = struct
  type shim =
  | Unshimmed
  | Shim
  | Test of string

  type t = {
    env: string array;
    serial: int;
    bindir: string;
    libdir: string;
    phase: phase;
    caml_ld_library_path: shim;
    ocamllib: shim;
    camllib: shim;
    prefix_path_with_cwd: bool;
  }

  let ld_library_path_name =
    if Config.system = "macosx" then
      "DYLD_LIBRARY_PATH"
    else
      "LD_LIBRARY_PATH"

  let base_bindings =
    (* List of environment variables to remove from the calling environment *)
    let scrub =
      let names = [
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
      ] in
      let names =
        if Sys.win32 then ld_library_path_name::names else names in
      StringSet.of_list names
    in
    let keep s =
      not (StringSet.mem (String.sub s 0 (String.index s '=')) scrub)
    in
    let bindings = List.filter keep (Array.to_list (Unix.environment ())) in
    let has_ld_library_path_binding =
      let prefix = ld_library_path_name ^ "=" in
      List.exists (String.starts_with ~prefix)
    in
    if Sys.win32 || has_ld_library_path_binding bindings then
      bindings
    else
      (ld_library_path_name ^ "=") :: bindings

  (* Tests whether the name of an environment variable is in fact PATH, masking
     the fact that environment variable names are case-insensitive on
     Windows. *)
  let is_path_env =
    if Sys.win32 then
      fun name -> String.lowercase_ascii name = "path"
    else
      String.equal "PATH"

  let environments = Hashtbl.create 15

  let augment env =
    let bindings = Array.to_list env.env in
    let apply name shim value bindings =
      match value with
      | Unshimmed ->
          bindings
      | Shim ->
          (name ^ "=" ^ shim)::bindings
      | Test binding ->
          (name ^ "=" ^ binding)::bindings
    in
    let update_path s =
      let l = String.length s in
      if l < 7 || not (String.starts_with ~prefix:"PATH=" s) then
        s
      else
        let starts_with_cwd = (String.sub s 5 2 = ".:") in
        if env.prefix_path_with_cwd && not starts_with_cwd then
          "PATH=.:" ^ String.sub s 5 (l - 5)
        else if not env.prefix_path_with_cwd && starts_with_cwd then
          "PATH=" ^ String.sub s 7 (l - 7)
        else
          s
    in
    let apply_cwd_prefix =
      if env.prefix_path_with_cwd then
        List.map update_path
      else
        Fun.id
    in
    let stublibs = Filename.concat env.libdir "stublibs" in
    let bindings =
      bindings
      |> apply "CAMLLIB" env.libdir env.camllib
      |> apply "OCAMLLIB" env.libdir env.ocamllib
      |> apply "CAML_LD_LIBRARY_PATH" stublibs env.caml_ld_library_path
      |> apply_cwd_prefix
    in
    {env with env = Array.of_list bindings}

  let is_renamed {phase; _} = (phase = Renamed)

  let bindir {bindir; _} = bindir
  let libdir {libdir; _} = libdir

  let tool_path {bindir; _} mode bytecode native =
    Filename.concat bindir (exe (if mode = Bytecode then bytecode else native))

  let ocamlrun {bindir; _} =
    Filename.concat bindir (exe "ocamlrun")

  let in_libdir {libdir; _} path =
    Filename.concat libdir path

  (* Returns an environment where any variables in scrub have been removed and
     with effectively PATH=$bindir:$PATH and
     LD_LIBRARY_PATH=$libdir:$LD_LIBRARY_PATH on Unix or
     DYLD_LIBRARY_PATH=$libdir$:DYLD_LIBRARY_PATH on macOS or
     PATH=$bindir;$libdir;$PATH on Windows. *)
  let make ?(phase = Original) bindir libdir =
    let update binding =
      let equals = String.index binding '=' in
      let name = String.sub binding 0 equals in
      let value =
        String.sub binding (equals + 1) (String.length binding - equals - 1)
      in
      if is_path_env name then
        if Sys.win32 then
          if String.index_opt bindir ';' <> None then
            Printf.sprintf "%s=\"%s\";%s" name bindir value
          else
            Printf.sprintf "%s=%s;%s" name bindir value
        else
          Printf.sprintf "%s=%s:%s" name bindir value
      else if name = ld_library_path_name then
        Printf.sprintf "%s=%s:%s" name libdir value
      else
        binding
    in
    let bindings = List.map update base_bindings in
    let serial =
      try Hashtbl.find environments bindings
      with Not_found ->
        let serial = Hashtbl.length environments + 1 in
        Hashtbl.add environments bindings serial;
        serial
    in
    {phase; env = Array.of_list bindings; serial; bindir; libdir;
    ocamllib = Unshimmed; camllib = Unshimmed; caml_ld_library_path = Unshimmed;
     prefix_path_with_cwd = false}

  let last_environment = ref (-1)

  let format_line () = Format.printf "@{<inline_code>>@} %s\n%!"

  let pp_program style program f = function
  | Some argv0 ->
      Format.fprintf f "@{<%s>%s (from %a)@}"
                       style argv0 display_path program
  | None ->
      Format.fprintf f "@{<%s>%a@}" style display_path program
  let pp_arg f x = Format.pp_print_char f ' '; display_path f x
  let pp_args = Format.pp_print_list ~pp_sep:(Fun.const ignore) pp_arg
  let pp_status ~exited_normally style f status =
    if not exited_normally then
      Format.fprintf f " <@{<%s>%s@}>" style (string_of_process_status status)
  let pp_environment f environment =
    if environment.prefix_path_with_cwd then
      Format.pp_print_string f "PATH=.:$PATH ";
    let pp_shim name = function
      | Unshimmed ->
          ()
      | Shim ->
          Format.fprintf f "@{<warning>%s=%s@} " name environment.libdir
      | Test test ->
          Format.fprintf f "%s=%s " name test
    in
    pp_shim "CAML_LD_LIBRARY_PATH" environment.caml_ld_library_path;
    pp_shim "OCAMLLIB" environment.ocamllib;
    pp_shim "CAMLLIB" environment.camllib
  let pp_pid f = function
  | Some pid when verbose -> Format.fprintf f " [@{<loc>%d@}]" pid
  | _ -> ()

  let display_execution level status pid ~runtime
                        program argv0 args environment =
    let style_of_level = function
    | `Normal -> "inline_code"
    | `Warning -> "warning"
    | `Error -> "error"
    in
    let program_style =
      let level = if runtime then `Warning else level in
      style_of_level level
    in
    let style = style_of_level level in
    let exited_normally = (level = `Normal && status = Unix.WEXITED 0) in
    Format.printf "@{<%s>%a@}%a@{<%s>%a@}%a%a\n@?"
                  style pp_environment environment
                  (pp_program program_style program) argv0
                  style pp_args args
                  pp_pid pid
                  (pp_status ~exited_normally style) status;
    if environment.serial <> !last_environment then begin
      last_environment := environment.serial;
      Format.printf "\
        @{<inline_code>> @}@{<loc>Environment@}\n\
        @{<inline_code>> @}  @{<loc>PATH=%s%a:$PATH@}\n"
        (if environment.prefix_path_with_cwd then ".:" else "")
        display_path environment.bindir;
      if not Sys.win32 then
        Format.printf "\
          @{<inline_code>> @}  @{<loc>%s=%a:$%s@}\n"
        ld_library_path_name display_path environment.libdir
        ld_library_path_name
    end

  let run_one ~just_execute ~fails ~quiet ~runtime
              program ?argv0 args environment =
    flush stderr;
    flush stdout;
    let quiet = quiet && not verbose in
    let captured_output = "process-output" in
    let stdout, stderr =
      let flags = Unix.([O_RDWR; O_CREAT; O_TRUNC; O_CLOEXEC]) in
      let fd = Unix.openfile captured_output flags 0o600 in
      fd, fd
    in
    let pid =
      let argv0 = Option.value ~default:program argv0 in
      try
        let pid =
          Unix.create_process_env program (Array.of_list (argv0::args))
                                  environment.env Unix.stdin stdout stderr
        in
        Some pid
      with
      | Unix.(Unix_error(ENOENT, "create_process", _))
        when is_shebang program -> None
    in
    let _, status =
      Option.map (Unix.waitpid []) pid
      |> Option.value ~default:(-1, Unix.WEXITED 127)
    in
    let status =
      match status with
      | Unix.WSIGNALED n
        when n = Sys.sigabrt ->
          (* Convert SIGABRT to exit code 134 *)
          Unix.WEXITED 134
      | Unix.WSIGNALED n
        when n = Sys.sigsegv
             && List.mem Config.architecture ["s390x"; "riscv"] ->
          (* cf. ocaml/ocaml#13693 - s390x executables might segfault, so this
             gets converted to Docker's exit code so it can be skipped *)
          Unix.WEXITED 139
(* XXX This doesn't work - for example, the problem is we can't differentiate
       exit 2 from the ocamlc.byte and exit 2 from header.c
      | Unix.WEXITED 2 when classification = Tendered ->
          (* Normalise the exit(2) from header.c to code 127 (as a #!-style
             header would do *)
          Unix.WEXITED 127
*)
      | status ->
          status
    in
    let level, exit_code =
      match status with
      | Unix.WEXITED n
        when fails = (n <> 0) || status = Unix.WEXITED 139 ->
          let level =
            if n = 0 then
              `Normal
            else
              `Warning
          in
          level, n
      | _ ->
          let display_argv0 =
            match argv0 with
            | Some argv0 -> Printf.sprintf "%s (from %s)" argv0 program
            | None -> program
          in
          display_execution
            `Error status pid ~runtime program argv0 args environment;
          fail_because "%s did not terminate as expected (got %s)"
                       display_argv0 (string_of_process_status status)
    in
    if not quiet then
      display_execution
        level status pid ~runtime program argv0 args environment;
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
      if just_execute then
        let display = if quiet then Fun.const ignore else format_line in
        In_channel.fold_lines display () ic; []
      else
        In_channel.input_lines ic
    in
    Unix.close stdout;
    Sys.remove captured_output;
    exit_code, lines

  let rec run ~fails ~quiet env program ?argv0 args acc strategy ~just_execute =
    match strategy with
    | [] ->
        acc
    | (runtime, strategy_env)::strategy ->
        let acc =
          let runtime, program, argv0, args =
            match runtime with
            | Some runtime ->
                true, runtime, None, program::args
            | None ->
                false, program, argv0, args
          in
          let env = Option.value ~default:env strategy_env in
          let (~just_execute, ~fails, ~quiet) =
            if strategy = [] then
              (~just_execute, ~fails, ~quiet)
            else
              (~just_execute:true, ~fails:true, ~quiet:true)
          in
          run_one ~just_execute ~fails ~quiet ~runtime program ?argv0 args env
        in
        run ~quiet ~fails env program ?argv0 args acc strategy ~just_execute

  let run_process : type s . s output
                      -> ?runtime:bool -> ?stubs:bool -> ?stdlib:bool
                      -> ?prefix_path_with_cwd:bool
                      -> ?quiet:bool -> ?fails:bool
                      -> t -> string -> ?argv0:string -> string list -> s =
    fun output ?(runtime = false) ?(stubs = false) ?(stdlib = false)
               ?(prefix_path_with_cwd = false) ?(quiet = false) ?(fails = false)
               env program ?argv0 args ->
      let env =
        if prefix_path_with_cwd then
          if Sys.win32 then
            invalid_arg "Can't use prefix_path_with_cwd on Windows"
          else
            augment {env with prefix_path_with_cwd = true}
        else
          env
      in
      let shim ~stubs ~stdlib env =
        (* XXX NB This is protected at at type level now - this code can go *)
        match env.ocamllib, env.camllib, env.caml_ld_library_path with
        | Test _, _, _
        | _, Test _, _
        | _, _, Test _->
            invalid_arg "Cannot shim a testing environment"
        | _ ->
            let env =
              if stubs then {env with caml_ld_library_path = Shim} else env
            in
            let env =
              if stdlib then {env with ocamllib = Shim} else env
            in
            augment env
      in
      let strategy =
        let shim ~stubs ~stdlib env =
          if stubs || stdlib then
            Some (shim ~stubs ~stdlib env)
          else
            None
        in
        let runtime =
          if runtime then
            Some (Filename.concat env.bindir (exe "ocamlrun"))
          else
            None
        in
        let strategy =
          [runtime, shim ~stubs ~stdlib env] in
        let strategy =
          if stdlib && (runtime <> None || stubs) then
            (runtime, shim ~stubs ~stdlib:false env) :: strategy
          else
            strategy in
        let strategy =
          if stubs && (runtime <> None || stdlib) then
            (runtime, shim ~stubs:false ~stdlib env) :: strategy
          else
            strategy in
        let strategy =
          if runtime <> None && (stubs || stdlib) then
            (None, shim ~stubs ~stdlib env) :: strategy
          else
            strategy in
        if runtime <> None || stubs || stdlib then
          (None, shim ~stubs:false ~stdlib:false env) :: strategy
        else
          strategy
      in
      let strategy =
        (* XXX This can be simplified - the point is that the flags are only
               used for a second phase environment *)
        if env.phase = Original || strategy = [] then
          [None, None]
        else
          strategy
      in
      let run = run ~fails ~quiet env program ?argv0 args (-1, []) strategy in
      match output with
      | Execute ->
          ignore (run ~just_execute:true)
      | Return ->
          run ~just_execute:false

  let display_output output = List.iter (format_line ()) output

  let run_process_with_test_env mode ?runtime ~caml_ld_library_path
                                ~ocamllib ~camllib env ?quiet ?fails program =
    let env =
      let caml_ld_library_path =
        match caml_ld_library_path with
        | Some dirs ->
            Test (String.concat (if Sys.win32 then ";" else ":") dirs)
        | None ->
            Unshimmed
      in
      let f = Option.fold ~none:Unshimmed ~some:(fun x -> Test x) in
      let ocamllib = f ocamllib in
      let camllib = f camllib in
      augment {env with caml_ld_library_path; ocamllib; camllib}
    in
    run_process mode ?runtime ?quiet ?fails env program

end

let library mode name =
  if mode = Native then
    name ^ ".cmxa"
  else
    name ^ ".cma"

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

(* This test verifies that a series of libraries can be loaded in a toplevel.
   Any failures cause the script to be aborted. *)
let load_libraries_in_toplevel env mode libraries =
  let toplevel = Environment.tool_path env mode "ocaml" "ocamlnat" in
  Format.printf "Testing loading of libraries in %a\n%!" display_path toplevel;
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
                      fail_because "threads.cmxs is not expected to exist"
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
      || has_c_stubs && not config.supports_shared_libraries then
        (* cf. ocaml/flexdll#146 - Cygwin's ocamlnat can't load unix.cmxs and
           the lines above will have triggered native Windows being unable to
           load threads.cmxs *)
        125
      else
        0
    in
    let exit_code, output =
      Environment.run_process Return
        ~runtime:(mode = Bytecode && not launcher_searches_for_ocamlrun)
        ~stdlib:(config.has_relative_libdir = None)
        ~fails:(expected_exit_code <> 0) env toplevel args
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
let load_libraries_in_prog env mode libraries =
  Format.printf "\nTesting loading of libraries with %s dynlink\n"
                (if mode = Native then "native" else "bytecode");
  let test_program = Filename.concat test_root (exe "test_script") in
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
      "-I"; "+dynlink"; library mode "dynlink"; "-linkall";
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
        erase_file test_program;
      let args = if custom then "-custom" :: args else args in
      Environment.run_process Execute
        ~runtime:(mode = Bytecode && not ocamlc_executable_after_rename)
        ~stdlib:(config.has_relative_libdir = None) env compiler args in
    compile ();
    files, compile
  in
  let test_libraries_in_prog ?expected_exit_code env libraries =
    let has_c_stubs library = (mode = Bytecode && library <> "dynlink") in
    let has_c_stubs = List.exists has_c_stubs libraries in
    if mode = Native && List.mem "threads" libraries then
      let threads_plugin =
        Environment.in_libdir env (Filename.concat "threads" "threads.cmxs")
      in
      if Sys.file_exists threads_plugin then
        fail_because "threads.cmxs is not expected to exist"
      else
        ()
    else
      let runtime =
        mode = Bytecode
        && expected_exit_code = None
        && not target_launcher_searches_for_ocamlrun
        && config.has_relative_libdir = None
      in
      let stubs =
        has_c_stubs
        && expected_exit_code = None
        && config.supports_shared_libraries
        && config.has_relative_libdir = None
      in
      let expected_exit_code =
        match expected_exit_code with
        | Some code -> code
        | None ->
            if (Sys.cygwin && mode = Native && List.mem "unix" libraries)
               || (not config.supports_shared_libraries && has_c_stubs) then
              (* cf. ocaml/flexdll#146 - Cygwin's natdynlink can't load
                     unix.cmxs *)
              2
            else
              0
      in
      let exit_code, output =
        Environment.run_process Return
          ~runtime
          ~stubs
          ~fails:(expected_exit_code <> 0) env
          test_program libraries
      in
      Environment.display_output output;
      if exit_code <> expected_exit_code then
        fail_because "%s is expected to return with exit code %d"
                     test_program expected_exit_code;
  in
  let not_dynlink l = not (List.mem "dynlink" l) in
  let files, re_compile = compile_test_program () in
  let expected_exit_code =
    (* Relocatable OCaml bytecode executables launched using the executable
       header require caml_executable_name, or they end up being accidentally
       relative, since the exec call leaves argv[0] as being the bytecode image
       itself. *)
    if mode = Bytecode && config.has_relative_libdir <> None
       && no_caml_executable_name
       && launched_via_stub test_program then
      Some 2
    else
      None in
  let libraries = List.filter not_dynlink libraries in
  let () =
    List.iter (test_libraries_in_prog ?expected_exit_code env) libraries;
    if expected_exit_code <> None then
      let () = re_compile ~custom:true () in
      List.iter (test_libraries_in_prog env) libraries
  in
  List.iter erase_file files

let is_executable =
  if Sys.win32 then
    Fun.const true
  else
    fun binary ->
      try Unix.access binary [Unix.X_OK]; true
      with Unix.Unix_error _ -> false

(* XXX The comment here needs writing! *)
let test_bytecode_binaries env =
  let bindir = Environment.bindir env in
  Format.printf "\nTesting bytecode binaries in %a\n" display_path bindir;
  let exec_magic =
    let ocamlrun = Environment.ocamlrun env in
    Environment.run_process Return env ocamlrun ["-M"]
  in
  let test_binary binary =
    if String.starts_with ~prefix:"ocaml" binary
    || String.starts_with ~prefix:"flexlink" binary then
    let program = Filename.concat bindir binary in
    if is_executable program then
      let classification = classify_executable program in
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
             | Tendered(~header:_, ~dlls) ->
                 not launcher_searches_for_ocamlrun
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
        | _ ->
            if not fails then
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

let compile_ld_conf_test_programs env =
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
    let compiler = Environment.tool_path env mode "ocamlc" "ocamlopt" in
    let args = [
      "-I"; "+compiler-libs";
      library mode "ocamlcommon"; library mode "ocamlbytecomp";
      "-o"; test_program; "test_install_script.ml"
    ] in
    Environment.run_process Execute
      ~runtime:(mode = Bytecode && not ocamlc_executable_after_rename)
      ~stdlib:(config.has_relative_libdir = None) env compiler args;
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
      && not target_launcher_searches_for_ocamlrun
      && config.has_relative_libdir = None
    in
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
let test_ld_conf env =
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
  let programs, files = compile_ld_conf_test_programs env in
  let programs = ocamlrun_config :: programs in
  let backed_up_ld_conf = Environment.in_libdir env "ld.conf.bak" in
  let libdir_ld_conf = Environment.in_libdir env "ld.conf" in
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
      Sys.rmdir dir;
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
      let libdir = Environment.libdir env in
      let libdir =
        if config.has_relative_libdir = None then
          libdir
        else
          try Unix.realpath libdir
          with Invalid_argument _ -> libdir
      in
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
  List.iter erase_file files

let write_test_program ~is_randomized ~with_unix description =
  let is_directory =
    if with_unix then
{|
  try (Unix.stat dir).Unix.st_kind = Unix.S_DIR
  with Unix.(Unix_error(ENOENT, _, _)) -> false
|}
    else
{|
  try Sys.is_directory dir
  with Sys_error _ -> false
|}
  in
  Out_channel.with_open_text "test_install_script.ml" @@ fun oc ->
    Printf.fprintf oc {|
let expected_executable_name = Sys.argv.(2)
let expected_argv0 = Sys.argv.(3)
let state = bool_of_string Sys.argv.(4)
let prefix = Sys.argv.(5)
let libdir_suffix = Sys.argv.(6)

let is_directory dir =%s

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
  let is_randomized = Hashtbl.is_randomized () in
  if %sis_randomized then begin
    Printf.eprintf "  *** Hashtbl.is_randomized () should be returning %%b\n"
                   (not is_randomized);
    exit 1
  end else if is_directory Config.standard_library <> state then begin
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
|} is_directory (if verbose then "" else "i") description
   (if is_randomized then "not " else "")

let usr_bin_sh =
  let env = Environment.make orig_bindir orig_libdir in
  match Environment.run_process Return ~quiet:true env
                                "sh" ["-c"; "command -v sh"] with
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
  fun env ~runtime ~stubs test_program expected_executable_name
      ~prefix_path_with_cwd expected_exit_code argv0 expected_argv0
      ~may_segfault ~stdlib_exists_when_renamed ->
    let stdlib_exists =
      if Environment.is_renamed env then
        stdlib_exists_when_renamed
      else
        config.has_relative_libdir <> None in
    let args = [string_of_bool stdlib_exists; prefix; libdir_suffix] in
    let argv0 =
      if argv0 = test_program then
        None
      else
        Some argv0
    in
    let args = "skip" :: expected_executable_name :: expected_argv0 :: args in
    let fails = (expected_exit_code <> 0) in
    let (exit_code, output) =
      Environment.run_process
        Return ~fails ~runtime ~stubs ~prefix_path_with_cwd env
        test_program ?argv0 args
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
| Default_ocamlc of launch_mode
| Default_ocamlopt
| Custom_runtime of runtime_mode
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
let compile_test env =
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
    let use_shared_runtime, mode, options, main_in_c,
        compilation_exit_code, linker_exit_code, may_segfault, tendered,
        target_launcher_searches_for_ocamlrun, clibs =
      let f ?(use_shared_runtime = false) ?(mode = Bytecode)
            ?(calls_linker = (mode = Native)) ?(compilation_exit_code = 0)
            ?(linker_exit_code = 0) ?(may_segfault = false) ?(tendered = false)
            ?(target_launcher_searches_for_ocamlrun =
                target_launcher_searches_for_ocamlrun) ?clibs options =
        let main_in_c = clibs <> None in
        let clibs = Option.value ~default:[] clibs in
        let compilation_exit_code, linker_exit_code =
          (* If the prefix has been renamed,
             If the linker is needed,
             If the linker is flexlink, not the C compiler,
             If the system does support native compilation,
             If the launcher does not search for ocamlrun,
             Yours is... an error, my son! *)
          if Environment.is_renamed env && calls_linker && linker_is_flexlink &&
             not config.has_ocamlopt && not launcher_searches_for_ocamlrun then
            if main_in_c then
              compilation_exit_code, 2
            else
              2, linker_exit_code
          else
            compilation_exit_code, linker_exit_code
        in
        use_shared_runtime, mode, options, main_in_c,
        compilation_exit_code, linker_exit_code, may_segfault, tendered,
        target_launcher_searches_for_ocamlrun, clibs
      in
      let fails_if ?(compilation_exit_code = 2) cond =
        if cond then
          compilation_exit_code
        else
          0
      in
      match test with
      | Default_ocamlc _launch_method ->
          f ~tendered:true []
      | Default_ocamlopt ->
          f ~mode:Native []
      | Custom_runtime Static ->
          f ~calls_linker:true ["-custom"]
      | Custom_runtime Shared ->
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
          f ~mode:Native
            ~clibs:["-lcomprmarsh"; "-lunixnat"; Config.compression_c_libraries]
            ["-output-obj"]
      | Output_obj(C_ocamlopt, Shared) ->
          (* cf. ocaml/ocaml#13693 - on Fedora/RHEL, this executable
             segfaults *)
          let may_segfault = List.mem Config.architecture ["s390x"; "riscv"] in
          (* Shared compilation isn't available on native Windows and fails on
             Cygwin *)
          let linker_exit_code = fails_if (Sys.win32 || Sys.cygwin) in
          f ~mode:Native ~use_shared_runtime:true ~may_segfault
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
          f ~mode:Native ~clibs:[Config.compression_c_libraries]
            ~linker_exit_code
            ["-output-complete-obj"; "-noautolink"; "-cclib"; "-lunixnat";
                                                    "-cclib"; "-lcomprmarsh"]
      | Output_complete_obj(C_ocamlopt, Shared) ->
          (* ocamlopt doesn't correctly implement -runtime-variant _shared *)
          let compilation_exit_code = fails_if true in
          f ~mode:Native ~use_shared_runtime:true
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
    || mode = Native && not config.has_ocamlopt then
      (* This test cannot be compiled because OCaml has been configured without
         required support *)
      `None
    else
      let test_program_path = Filename.concat test_root (exe test_program) in
      let compiler = Environment.tool_path env mode "ocamlc" "ocamlopt" in
      let compile_with_main_in_c output =
        let runtime_lib =
          let suffix = if use_shared_runtime then "_shared" else "" in
          if mode = Native then
            "-lasmrun" ^ suffix
          else
            "-lcamlrun" ^ suffix
        in
        let flags =
          let libraries =
            if mode = Native then
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
          erase_file output;
          true
        end
      in
      let output =
        if main_in_c then
          "test_install_ocaml" ^ Config.ext_obj
        else
          test_program_path
      in
      let with_unix = (config.supports_shared_libraries || not tendered) in
      let is_randomized = false in
      write_test_program ~is_randomized ~with_unix description;
      let options =
        if use_shared_runtime then
          "-runtime-variant" :: "_shared" :: options
        else
          options
      in
      let options =
        if Environment.is_renamed env || config.has_relative_libdir <> None then
          options
        else
          let new_libdir = Filename.concat (prefix ^ ".new") libdir_suffix in
          let stdlib_default = "standard_library_default=" ^ new_libdir in
          let options = "-set-runtime-default" :: stdlib_default :: options in
          if tendered then
            let libdir = Environment.libdir env in
            "-dllpath" :: (Filename.concat libdir "stublibs") :: options
          else
            options
      in
      let args =
        "-o" :: output ::
        "test_install_script.ml" :: options
      in
      let args =
        if with_unix then
          "-I" :: "+unix" :: library mode "unix" :: args
        else
          args
      in
      let args =
        "-I" :: "+compiler-libs" :: library mode "ocamlcommon" :: args
      in
      let args =
        if verbose then
          "-verbose" :: args
        else
          args
      in
      let exit_code =
        let exit_code, output =
          Environment.run_process Return
            ~fails:(compilation_exit_code <> 0)
            ~runtime:(mode = Bytecode && not ocamlc_executable_after_rename)
            ~stdlib:(config.has_relative_libdir = None) env compiler args
        in
        Environment.display_output output;
        exit_code
      in
      if exit_code <> compilation_exit_code then
        fail_because "%s is expected to return with exit code %d"
                     compiler compilation_exit_code
      else if exit_code <> 0 then
        (* Nothing to run because compilation of the test is known to fail *)
        `None
      else
        let files = [
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
        List.iter erase_file files;
        if main_in_c && not (compile_with_main_in_c output) then
          (* Nothing to run because linking the test is known to fail *)
          `None
        else
          let compiled_location = Environment.is_renamed env in
          let stdlib_exists_when_renamed =
            if config.has_relative_libdir = None then
              not (Environment.is_renamed env)
            else
              Environment.is_renamed env in
          (* Each test is compiled twice - in the original prefix
             (~original:true) and in the renamed prefix (~original:false).
             Additionally, the tests compiled in the original prefix are
             _executed_ a second time after the prefix has been renamed, which
             is what this slightly convoluted run function sets up *)
          let rec run env =
            (* Bytecode executables with absolute headers will need to be
               invoked via ocamlrun after the prefix has been renamed.
               XXX Expand: when relative, runtime-launch-info contains a .
                   and so the header is _correctly_ computed even after
                   renaming. *)
            let via_ocamlrun =
              Environment.is_renamed env
                <> (compiled_location && config.has_relative_libdir <> None)
              && tendered && not target_launcher_searches_for_ocamlrun
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
              {argv0 = test_program; prefix_path_with_cwd = not Sys.win32},
              {argv0_not_ocaml = false; argv0_resolved = test_program_relative}
            ] in
            let runs =
              let test_with_outcome (({argv0; _} as test), properties) =
                let {argv0_not_ocaml; argv0_resolved} = properties in
                let outcome =
                  (* If strategy has been specified, this program is going to be
                     executed as ocamlrun test_program_path ... *)
                  if via_ocamlrun then
                    Success {executable_name = test_program_path;
                             argv0 = test_program_path}
                  else
                    match classify_executable test_program_path with
                    | Tendered(~header:Header_shebang, ~dlls:_) ->
                        (* Likewise, shebang executables, regardless of the
                           input argv[0], will just see test_program_path *)
                        Success {executable_name = test_program_path;
                                 argv0 = test_program_path}
                    | Tendered(~header:Header_exe, ~dlls:_) ->
                        if argv0_not_ocaml then
                          if Sys.win32 then
                            (* stdlib/header.c will find ocamlrun (because it
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
                          (* stdlib/header.c correctly preserves argv[0] *)
                          Success {executable_name = test_program_path; argv0}
                        else if no_caml_executable_name
                                && config.has_relative_libdir <> None then
                          (* Without caml_executable_name, ocamlrun will be
                             forced to interpret the relative standard library
                             relative to argv[0], which will fail. *)
                          Fail 134
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
                          (* -custom executables use caml_executable_name *)
                          Success {executable_name = test_program_path; argv0}
                    | Vanilla ->
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
              let stubs =
                tendered && with_unix && config.has_relative_libdir = None
              in
              run_program
                env ~runtime:via_ocamlrun ~stubs
                test_program_path ~prefix_path_with_cwd expected_executable_name
                expected_exit_code argv0 expected_argv0 ~may_segfault
                ~stdlib_exists_when_renamed
            in
            List.iter execute runs;
            print_newline ();
            if Environment.is_renamed env then
              (erase_file test_program_path; `None)
            else
              `Some run
          in
          `Some run

let compiler_where env ?runtime mode =
  let compiler = Environment.tool_path env mode "ocamlc" "ocamlopt" in
  match Environment.run_process Return ?runtime env compiler ["-where"] with
  | (0, [where]) -> where
  | _ ->
      fail_because "Unexpected response from %s -where" compiler

(* This test verifies both that all compilation mechanisms are working and that
   each of these programs can correctly identify the Standard Library location.
   Any failures will cause either an exception or a compilation error. *)
let test_standard_library_location env =
  Format.printf "\nTesting compilation mechanisms for %a\n%!"
                display_path (Environment.bindir env);
  let ocamlc_where =
    compiler_where env ~runtime:(not ocamlc_executable_after_rename) Bytecode in
  let ocamlopt_where =
    if config.has_ocamlopt then
      compiler_where env Native
    else
      "n/a"
  in
  Format.printf "ocamlc -where: %a\nocamlopt -where: %a\n%!"
                display_path ocamlc_where display_path ocamlopt_where;
  let compile_test = compile_test env in
  let launch_method =
    if bytecode_shebangs_by_default then
      Header_shebang
    else
      Header_exe
  in
  let tests = [
    compile_test (Default_ocamlc launch_method)
      "byt_default" "with tender";
    compile_test (Custom_runtime Static)
      "custom_static" "-custom static runtime";
    compile_test (Custom_runtime Shared)
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
    compile_test Default_ocamlopt
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
  Printf.printf "Running programs\n%!";
  List.map (function `Some f -> f env | `None -> `None) tests

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
type finding =
| Build_dir of cwd * encoding
| Prefix_dir of encoding
| Relative_libdir of encoding
and encoding = UTF_8 | UTF_16
and cwd = Physical | Logical

module LocationSet = Set.Make(struct
  type t = location
  let compare = Stdlib.compare
end)

let rec contains file file_len tests i seen =
  if i = file_len then
    seen
  else
    let c = Bigarray.Array1.unsafe_get file i in
    let seen, i =
      if c = '/' || Sys.win32 && c = '\\' then
        let check_for acc (t, s) =
          if matches_at file file_len i s then
            (t, s)::acc
          else
            acc in
        let seen_here = List.fold_left check_for [] tests in
        let seen_here =
          let compare (_, l) (_, r) =
            -Int.compare (String.length l) (String.length r) in
          List.sort compare seen_here in
        match seen_here with
        | (t, s)::_ ->
            t :: seen, i + String.length s
        | [] ->
            seen, i
      else
        seen, i in
    contains file file_len tests (i + 1) seen

let read_content file ic =
  let len = in_channel_length ic in
  let content = Bigarray.Array1.create Bigarray.Char Bigarray.c_layout len in
  if In_channel.really_input_bigarray ic content 0 len = None then
    fail_because "Error reading %s" file;
  content, len

let output_compunit ic oc (compunit : Cmo_format.compilation_unit) =
  seek_in ic compunit.cu_pos;
  Misc.copy_file_chunk ic oc compunit.cu_codesize;
  if compunit.cu_debug > 0 then begin
    seek_in ic compunit.cu_debug;
    output_value oc (Compression.input_value ic);
    output_value oc (Compression.input_value ic);
  end;
  output_value oc compunit

let with_decompressed_ocaml_artefact ic file f =
  let magic = Cmt_format.read_magic_number ic in
  let temp_file, oc =
    Filename.open_temp_file ~mode:[Open_binary] "ocaml-artefact-" ".tmp" in
  let () =
    if magic = Config.cmi_magic_number || magic = Config.cmt_magic_number then
      output_value oc (Cmt_format.read file)
    else if magic = Config.cmo_magic_number then begin
      seek_in ic (input_binary_int ic);
      let compunit = (input_value ic : Cmo_format.compilation_unit) in
      output_compunit ic oc compunit
    end else if magic = Config.cma_magic_number then begin
      seek_in ic (input_binary_int ic);
      let toc = (input_value ic : Cmo_format.library) in
      List.iter (output_compunit ic oc) toc.lib_units;
      output_value oc toc
    end else
      fail_because "Unexpected magic number %S in %s" magic file in
  close_out oc;
  let result = In_channel.with_open_bin temp_file (f temp_file) in
  Sys.remove temp_file;
  result

let read_file env file =
  In_channel.with_open_bin file @@ fun ic ->
    match Filename.extension file with
    | ".cma" | ".cmi" | ".cmo" | ".cmti" | ".cmt" ->
        with_decompressed_ocaml_artefact ic file read_content
    | ext when (ext = Config.ext_lib || ext = Config.ext_obj)
               && Sys.os_type = "Unix" && Config.system <> "macosx" ->
        let exit, lines =
          Environment.run_process Return ~quiet:true env "readelf" ["-tS"; file]
        in
        let contains_compressed l =
          if l = "" || l.[0] <> ' ' then
            false
          else
            let test = String.starts_with ~prefix:"COMPRESSED" in
            let l = String.split_on_char ' ' l in
            List.exists test l in
        if exit <> 0 then
          fail_because "readelf failed"
        else if List.exists contains_compressed lines then
          let temp_file = Filename.temp_file "ocaml-artefact-" ".tmp" in
          let exit, _ =
            let args = ["--decompress-debug-sections"; file; temp_file] in
            Environment.run_process Return ~quiet:true env "objcopy" args
          in
          if exit = 0 then
            let result =
              In_channel.with_open_bin temp_file (read_content temp_file) in
            Sys.remove temp_file;
            result
          else begin
            Sys.remove temp_file;
            fail_because "objcopy failed"
          end
        else
          read_content file ic
    | _ ->
        read_content file ic

module StringMap = Map.Make(String)

let test_relocation env prefix =
  let grandparent dir = Filename.dirname (Filename.dirname dir) in
  let build_root = grandparent test_root in
  let build_root_logical = Option.map grandparent test_root_logical in
  let relative_libdir, build_root, build_root_logical, prefix =
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
      let build_root_logical =
        let f dir = normalise (Filename.dirname (Filename.dirname dir)) in
        Option.map f test_root_logical
      in
      Option.map normalise relative, normalise build_root,
      Option.map normalise build_root_logical, normalise prefix
    else
      relative, build_root, build_root_logical, prefix in
  Printf.printf "\nChecking installed files for\n\
                  \  Installation Prefix: %s\n" prefix;
  Option.iter (Printf.printf "  Relative Suffix: %s\n") relative_libdir;
  begin match build_root_logical with
  | Some build_root_logical ->
      Printf.printf "  Build Root (physical): %s\n\
                    \  Build Root (logical): %s\n%!"
                    build_root build_root_logical
  | None ->
      Printf.printf "  Build Root: %s\n%!" build_root
  end;
  let tests =
    Option.value ~default:[]
      (Option.map (fun relative_libdir ->
         [Relative_libdir UTF_8, relative_libdir;
          Relative_libdir UTF_16, utf_16le_of_utf_8 relative_libdir])
        relative_libdir)
  in
  let tests =
    Option.value ~default:tests
      (Option.map (fun build_root_logical ->
        (Build_dir(Logical, UTF_8), build_root_logical) ::
        (Build_dir(Logical, UTF_16), utf_16le_of_utf_8 build_root_logical) ::
        tests) build_root_logical)
  in
  let tests =
    (Prefix_dir UTF_8, prefix) ::
    (Prefix_dir UTF_16, utf_16le_of_utf_8 prefix) ::
    (Build_dir(Physical, UTF_8), build_root) ::
    (Build_dir(Physical, UTF_16), utf_16le_of_utf_8 build_root) :: tests
  in
  let reproducible_rules file =
    if Filename.basename file = "Makefile.config" then
      LocationSet.of_list [Relative; Prefix]
    else
      LocationSet.empty
  in
  let in_unexpected_state file file_rel rules =
    let content, content_len = read_file env file in
    let seen = contains content content_len tests 0 [] in
    let string_of_encoding () =
      function UTF_8 -> "UTF-8" | UTF_16 -> "UTF-16" in
    let string_of_cwd () =
      function Physical -> "Physical" | Logical -> "Logical" in
    let string_of_build_dir =
      if test_root_logical = None then
        fun () (_, encoding) ->
          Printf.sprintf "in %a" string_of_encoding encoding
      else
        fun () (cwd, encoding) ->
          Printf.sprintf
            "%a; in %a" string_of_cwd cwd string_of_encoding encoding
    in
    let some_string fmt = Printf.ksprintf Option.some fmt in
    let gather seen = function
    | Build_dir(kind, enc) ->
        if LocationSet.mem Build seen then
          seen, None
        else
          LocationSet.add Build seen,
          some_string "Build directory (%a)" string_of_build_dir (kind, enc)
    | Prefix_dir enc ->
        if LocationSet.mem Prefix seen then
          seen, None
        else
          LocationSet.add Prefix seen,
          some_string "Installation prefix (%a)" string_of_encoding enc
    | Relative_libdir enc ->
        if LocationSet.mem Relative seen then
          seen, None
        else
          LocationSet.add Relative seen,
          some_string "Relative suffix (%a)" string_of_encoding enc
    in
    let seen, hits = List.fold_left_map gather LocationSet.empty seen in
    let expected = rules file in
    let reproducible = reproducible_rules file in
    let consistent = LocationSet.equal expected reproducible in
    let reproducible = LocationSet.equal seen reproducible in
    if LocationSet.equal seen expected then
      ~incorrect:false, ~seen, ~reproducible, ~consistent
    else
      let string_of_location = function
      | Build -> "Build directory"
      | Prefix -> "Installation prefix"
      | Relative -> "Relative prefix" in
          let hits = List.filter_map Fun.id hits in
          let msg =
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
          Printf.eprintf "%s: expected to %s, but it %s\n"
                         file_rel expected msg;
          ~incorrect:true, ~seen, ~reproducible, ~consistent
  in
  let rec scan dir rel h rules
               ((~failed, ~results, ~reproducible:reproducible_so_far,
                 ~consistent:consistent_so_far) as acc) =
    match Unix.readdir h with
    | entry ->
        let acc =
          if entry <> Filename.current_dir_name
             && entry <> Filename.parent_dir_name then
            let entry_rel = Filename.concat rel entry in
            let entry = Filename.concat dir entry in
            match Unix.lstat entry with
            | {Unix.st_kind = S_DIR; _} ->
                scan entry entry_rel (Unix.opendir entry) rules acc
            | {Unix.st_kind = S_REG; _} ->
                let ~incorrect, ~seen, ~reproducible, ~consistent =
                  in_unexpected_state entry entry_rel rules in
                  ~failed:(failed || incorrect),
                  ~results:((entry_rel, seen)::results),
                  ~reproducible:(reproducible_so_far && reproducible),
                  ~consistent:(consistent_so_far && consistent)
            | _ ->
                acc
          else
            acc in
        scan dir rel h rules acc
    | exception End_of_file ->
        Unix.closedir h;
        acc in
  let c_compiler_debug_paths_are_absolute =
    Toolchain.c_compiler_debug_paths_can_be_absolute
    && (not Config.c_has_debug_prefix_map || config.has_relative_libdir = None)
  in
  let assembler_embeds_build_path =
    Toolchain.assembler_embeds_build_path
    && (not Config.as_has_debug_prefix_map
        || Config.as_is_cc
        || config.has_relative_libdir = None)
  in
  let bindir_rules file =
    let basename = Filename.basename file in
    if Filename.extension basename = ".manifest" then
      (* Executable manifests installed as part of flexlink for the MSVC port *)
      LocationSet.empty
    else
      (* Analysis on filenames doesn't need to care about .exe *)
      let basename =
        Filename.chop_suffix_opt ~suffix:".exe" basename
        |> Option.value ~default:basename in
      let classification = classify_executable file in
      (* Determine if the installation prefix should be found in this file *)
      let prefix =
        let code_embeds_stdlib_location =
          (* The runtime binaries all contain OCAML_STDLIB_DIR and everything
             except flexlink and ocamllex link with the Config module, either
             directly or via ocamlcommon *)
          config.has_relative_libdir = None
          && not (List.mem basename ["flexlink.byte"; "flexlink.opt";
                                     "ocamllex.byte"; "ocamllex.opt";
                                     "ocamlyacc"])
        in
        let linker_embeds_stdlib_location =
          (* If the launcher doesn't search for ocamlrun, then either the #!
             stub will include the absolute path or the RNTM section will *)
          match classification with
          | Tendered _ when not launcher_searches_for_ocamlrun -> true
          | _ -> false
        in
        if code_embeds_stdlib_location || linker_embeds_stdlib_location then
          LocationSet.singleton Prefix
        else
          LocationSet.empty
      in
      (* Determining if the build path will be found consists of two strictly
         separated portions: the properties we expect from the file itself and
         then how they are applied by the platform itself.
         First, determine if the program was compiled by ocamlopt, ocamlc or is
         a pure C program and, additionally, whether it was linked with -g.
         These are properties of the programs themselves, so there should be no
         platform-specific references in these definitions. *)
      let program_kind, linked_with_debug =
        (* As it happens, all ocamlopt-produced executables end with .opt or are
           ocamlnat. Other mechanisms (in particular looking for the
           caml_start_program symbol) are available, but are a bit more complex
           to make portable, and we don't need them at the moment, since
           -output-obj, -output-complete-obj or -output-complete-exe are not
           used by the compiler distribution. *)
        if String.ends_with ~suffix:".opt" basename
           || basename = "ocamlnat" then
          (* All native executable are linked with -g apart from flexlink.opt *)
          `Native_ocaml, (basename <> "flexlink.opt")
        else if classification <> Vanilla then
          (* Only ocamlc.byte, ocamlopt.byte and ocaml are linked with -g, but
             the debugging information in ocamlc.byte and ocamlopt.byte is
             stripped. *)
          `Bytecode_ocaml, (basename = "ocaml")
        else
          (* Bytecode runtimes and ocamlyacc of which only ocamlrund is linked
             with -g *)
          `Other, (basename = "ocamlrund")
      in
      (* Combine this with the properties of the platform to determine whether
         the executable will contain the build path. *)
      let contains_build_path =
        match program_kind with
        | `Native_ocaml ->
            (* If the linker propagates debugging information, it doesn't matter
               whether -g was passed to ocamlopt, because the build path will be
               embedded via libasmrun *)
            Toolchain.linker_embeds_build_path
            || (Toolchain.linker_propagates_debug_information
                && (c_compiler_debug_paths_are_absolute
                    || assembler_embeds_build_path))
        | `Bytecode_ocaml ->
            (* Only ocamlc.byte, ocamlopt.byte and ocaml are linked with -g, but
               the debugging information in ocamlc.byte and ocamlopt.byte is
               stripped. However, since the C objects in libcamlrun are compiled
               with -g, this will still result in debug information for -custom
               runtime executables. *)
            linked_with_debug && config.has_relative_libdir = None
            || (classification = Custom
                && Toolchain.linker_propagates_debug_information
                && c_compiler_debug_paths_are_absolute)
        | `Other ->
            (* Only ocamlrund is linked with -g. However, since the C objects
               which make up the executables are all compiled with -g, this
               will still result in debug information in all non-OCaml
               executables. *)
            Toolchain.linker_embeds_build_path
            || (c_compiler_debug_paths_are_absolute
                && (Toolchain.linker_propagates_debug_information
                    || linked_with_debug))
      in
      if contains_build_path then
        LocationSet.add Build prefix
      else
        prefix
  in
  let libdir_rules file =
    let basename = Filename.basename file in
    let ext = Filename.extension basename in
    if basename = "expunge" || basename = "expunge.exe" then
      bindir_rules file
    else
      let (~stdlib:embeds_stdlib_location,
           ~ocaml_debug:has_ocaml_debug_info,
           ~c_debug:contains_c_debug_info,
           ~s:contains_assembled_objects) =
        if basename = "Makefile.config" then
          (~stdlib:true, ~ocaml_debug:false, ~c_debug:false, ~s:false)
        else if basename = "config.cmx" then
          let stdlib =
            config.has_relative_libdir = None && not Config.flambda in
          (~stdlib, ~ocaml_debug:false, ~c_debug:false, ~s:false)
        else if List.mem ext [".cma"; ".cmo"; ".cmt"; ".cmti"] then
          let stdlib =
            config.has_relative_libdir = None
            && List.mem basename ["config.cmt"; "config_main.cmt";
                                  "ocamlcommon.cma"] in
          let ocaml_debug =
            config.has_relative_libdir = None in
          (~stdlib, ~ocaml_debug, ~c_debug:false, ~s:false)
        else if basename = "runtime-launch-info" then
          let stdlib = config.has_relative_libdir = None in
          (~stdlib, ~ocaml_debug:false, ~c_debug:false, ~s:false)
        else if ext = ".cmxs" then
          (~stdlib:false, ~ocaml_debug:false, ~c_debug:true, ~s:true)
        else if ext = Config.ext_obj then
          let is_ocaml =
            Sys.file_exists (Filename.remove_extension file ^ ".cmx") in
          let c_debug =
            not (is_ocaml || String.starts_with ~prefix:"flexdll_" basename) in
          (~stdlib:false, ~ocaml_debug:false, ~c_debug, ~s:is_ocaml)
        else if ext = Config.ext_lib || ext = Config.ext_dll then
          if ext = Config.ext_lib then
            let is_ocaml =
              Sys.file_exists (Filename.remove_extension file ^ ".cmxa") in
            let stdlib =
              config.has_relative_libdir = None
              && Filename.remove_extension basename = "ocamlcommon" in
            let c_debug = not is_ocaml in
            (~stdlib, ~ocaml_debug:false, ~c_debug, ~s:is_ocaml)
          else
            (~stdlib:false, ~ocaml_debug:false, ~c_debug:true, ~s:false)
        else
          (~stdlib:false, ~ocaml_debug:false, ~c_debug:false, ~s:false)
      in
      let contains_build_path =
        if String.starts_with ~prefix:"libasmrun" basename then
          ((c_compiler_debug_paths_are_absolute
              && Toolchain.asmrun_assembled_with_cc)
           || (assembler_embeds_build_path
                 && not Toolchain.asmrun_assembled_with_cc)
           || ext = Config.ext_dll && Toolchain.linker_embeds_build_path)
        else if (ext = Config.ext_dll || ext = ".cmxs")
           && (not Toolchain.linker_propagates_debug_information
               || Toolchain.linker_embeds_build_path) then
          Toolchain.linker_embeds_build_path
        else
          has_ocaml_debug_info
          || contains_c_debug_info && c_compiler_debug_paths_are_absolute
          || contains_assembled_objects && assembler_embeds_build_path
          || ext = Config.ext_obj
             && Toolchain.c_compiler_always_embeds_build_path
      in
      let prefix =
        if embeds_stdlib_location then
          LocationSet.singleton Prefix
        else
          LocationSet.empty
      in
      let prefix =
        if config.has_relative_libdir <> None
           && basename = "Makefile.config" then
          LocationSet.add Relative prefix
        else
          prefix
      in
      if contains_build_path then
        LocationSet.add Build prefix
      else
        prefix
  in
  let scan f rel_root =
    let dir = f env in
    scan dir rel_root (Unix.opendir dir)
  in
  let ~failed, ~results, ~reproducible:results_are_reproducible, ~consistent =
    ~failed:false, ~results:[], ~reproducible:true, ~consistent:true
    |> scan Environment.bindir "$bindir" bindir_rules
    |> scan Environment.libdir "$libdir" libdir_rules
  in
  flush stderr;
  let () =
    if results_are_reproducible && not consistent then
      fail_because "Internal error: bindir_rules and libdir_rules disagree \
                    with reproducible_rules"
    else if results_are_reproducible <> reproducible then
      fail_because "The build is %sexpected to be reproducible"
        (if not reproducible then "not " else "")
  in
  let sections =
    let f acc (_, seen) = LocationSet.union acc seen in
    List.fold_left f LocationSet.empty results
    |> LocationSet.elements
    |> List.sort Stdlib.compare
    |> List.map Option.some
    |> List.cons None in
  let results =
    let aggregate acc ((file, seen) as item) =
      let extension =
        if String.starts_with ~prefix:"$bindir" file then
          "$bindir/"
        else if Filename.basename file = "META" then
          "/META"
        else
          let extension = Filename.extension file in
          if extension = ".conf" || extension = ".config" then
            ""
          else if extension = ".in" then
            Filename.extension (Filename.remove_extension file) ^ extension
          else
            extension
      in
      let (files, all_seen) =
        try StringMap.find extension acc
        with Not_found -> [], LocationSet.empty
      in
      StringMap.add extension (item::files, LocationSet.union seen all_seen) acc
    in
    let aggregated = List.fold_left aggregate StringMap.empty results in
    let collapse extension (files, all_seen) acc =
      if extension = "" then
        List.rev_append files acc
      else
        let test section =
          let test =
            Option.fold ~none:LocationSet.is_empty ~some:LocationSet.mem section
          in
          let section =
            Option.fold ~none:LocationSet.empty
                        ~some:LocationSet.singleton section
          in
          match List.partition (fun (_, s) -> test s) files with
          | _::_, (([] | [_] | [_; _]) as exceptions) ->
              let extension, exceptions =
                if extension.[0] = '.' then
                  "*" ^ extension, List.map fst exceptions
                else if extension.[0] = '/' then
                  "**" ^ extension, List.map fst exceptions
                else
                  let l = String.length extension in
                  let chop (f, _) = String.sub f l (String.length f - l) in
                  extension ^ "*", List.map chop exceptions
              in
              let suffix =
                if exceptions = [] then
                  ""
                else
                  " (except " ^ String.concat " and " exceptions ^ ")"
              in
              let files =
                let keep (file, seen) =
                  let seen = LocationSet.diff seen section in
                  if LocationSet.is_empty seen then
                    None
                  else
                    Some (file, seen)
                in
                List.filter_map keep files
              in
              let item = (extension ^ suffix, section) in
              Some (item :: List.rev_append files acc)
          | _, _ ->
              None
        in
        let result =
          LocationSet.elements all_seen
          |> List.sort Stdlib.compare
          |> List.map Option.some
          |> List.cons None
          |> List.find_map test
        in
        match result with
        | Some acc ->
            acc
        | None ->
            List.rev_append files acc
    in
    StringMap.fold collapse aggregated []
  in
  let display section =
    let test =
      match section with
      | None ->
          Printf.printf "\nRelocatable files:\n";
          LocationSet.is_empty
      | Some path ->
          let name =
            match path with
            | Build -> "build path"
            | Prefix -> "installation prefix"
            | Relative -> "relative suffix"
          in
          Printf.printf "\nFiles containing the %s:\n" name;
          LocationSet.mem path
    in
    (* Put wildcard patterns first *)
    let compare l r = Stdlib.compare (l.[0] <> '*', l) (r.[0] <> '*', r) in
    let results =
      List.filter_map (fun (f, s) -> if test s then Some f else None) results
      |> List.sort compare
    in
    let pp_sep f () = Format.pp_print_char f ','; Format.pp_print_space f () in
    let pp_results = Format.(pp_print_list ~pp_sep pp_print_string) in
    Format.printf "@[<hov 4>  %a@]@." pp_results results
  in
  if failed then
    fail_because "Installed files don't match expectation"
  else
  List.iter display sections

let run_tests env libraries =
  load_libraries_in_prog env Bytecode libraries;
  if config.has_ocamlopt && config.supports_shared_libraries then
    load_libraries_in_prog env Native libraries;
  load_libraries_in_toplevel env Bytecode libraries;
  if config.has_ocamlnat then
    load_libraries_in_toplevel env Native libraries;
  test_ld_conf env;
  test_bytecode_binaries env;
  test_standard_library_location env

let () =
  (* Run all tests in the supplied prefix *)
  Compmisc.init_path ();
  if verbose then
    Clflags.verbose := true;
  let env = Environment.make ~phase:Original orig_bindir orig_libdir in
  let () = test_relocation env prefix in
  let programs = run_tests env config.libraries in
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
  let env = Environment.make ~phase:Renamed bindir libdir in
  (* Re-run the test programs compiled with the normal prefix *)
  Printf.printf "Re-running test programs\n%!";
  (* Finally re-run all of the tests with the new prefix *)
  List.iter
    (function `Some f -> assert (f env = `None) | `None -> ()) programs;
  Compmisc.reinit_path ~standard_library:libdir ();
  let programs = run_tests env config.libraries in
  assert (List.for_all (function `None -> true | _ -> false) programs)
