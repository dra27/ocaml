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
  has_runtime_search: bool;
    (* $(RUNTIME_SEARCH) - Makefile.build_config *)
  has_runtime_search_target: bool;
    (* $(RUNTIME_SEARCH_TARGET) - Makefile.build_config *)
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
let bindir, libdir, prefix, bindir_suffix, libdir_suffix, config =
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
    |> List.sort compare in
  let bindir = ref "" in
  let libdir = ref "" in
  let config =
    ref {supports_shared_libraries = false;
         has_ocamlnat = false; has_ocamlopt = false; has_runtime_search = true;
         has_runtime_search_target = true; libraries = []} in
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
      raise (Arg.Bad (dir ^ ": directory not found")) in
  let supports_shared_libraries supports_shared_libraries () =
    config := {!config with supports_shared_libraries} in
  let has_ocamlnat has_ocamlnat () =
    config := {!config with has_ocamlnat} in
  let has_ocamlopt has_ocamlopt () =
    config := {!config with has_ocamlopt} in
  let has_runtime_search has_runtime_search () =
    config := {!config with has_runtime_search} in
  let has_runtime_search_target has_runtime_search_target () =
    config := {!config with has_runtime_search_target} in
  let args = Arg.align [
    "--bindir", Arg.String (check_exists bindir), "\
<bindir>\tDirectory containing programs (must share a prefix with --libdir)";
    "--libdir", Arg.String (check_exists libdir), "\
<libdir>\tDirectory containing stdlib.cma (must share a prefix with --bindir)";
    "--with-shared", Arg.Unit (supports_shared_libraries true), "\
\tInstallation supports shared libraries (*.dll/*.so can be used from OCaml)";
    "--without-shared", Arg.Unit (supports_shared_libraries false), "";
    "--with-ocamlnat", Arg.Unit (has_ocamlnat true), "\
\tNative toplevel (ocamlnat) is installed in the directory given in --bindir";
    "--without-ocamlnat", Arg.Unit (has_ocamlnat false), "";
    "--with-ocamlopt", Arg.Unit (has_ocamlopt true), "\
\tNative compiler (ocamlopt) is installed in the directory given in --bindir";
    "--without-ocamlopt", Arg.Unit (has_ocamlopt false), "";
    "--with-runtime-search", Arg.Unit (has_runtime_search true), "\
\tCompiler bytecode binaries can search for their runtimes";
    "--without-runtime-search", Arg.Unit (has_runtime_search false), "";
    "--with-runtime-search-target",
      Arg.Unit (has_runtime_search_target true), "\
\tBytecode binaries produced by the compiler can search for their runtimes";
    "--without-runtime-search-target",
      Arg.Unit (has_runtime_search_target false), "";
  ] in
  let libraries lib =
    config := {!config with libraries = lib::config.contents.libraries} in
  let usage = "\n\
Usage: test_install --bindir <bindir> --libdir <libdir> <options> [libraries]\n\
options are:" in
  let error fmt =
    let f msg =
      Printf.eprintf "%s: %s\n" Sys.executable_name msg;
      Arg.usage args usage;
      exit 2 in
    Printf.ksprintf f fmt in
  let split_to_prefix bindir libdir =
    let rec split_dir acc dir =
      let dirname = Filename.dirname dir in
      if dirname = dir then
        dir::acc
      else
        split_dir (Filename.basename dir :: acc) dirname in
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
          error "directory given for --bindir inside that given for --libdir" in
    loop [] (split_dir [] bindir) (split_dir [] libdir) in
  Arg.parse args libraries usage;
  let config =
    {!config with libraries = sort_libraries config.contents.libraries} in
  let {contents = bindir} = bindir in
  let {contents = libdir} = libdir in
  if bindir = "" || libdir = "" then
    let () = Arg.usage args usage in
    exit 2
  else
    let prefix, bindir_suffix, libdir_suffix = split_to_prefix bindir libdir in
    if Sys.file_exists (prefix ^ ".new") then
      error "can't rename %s to %s.new as the latter already exists!"
      prefix prefix;
    Misc.Style.setup (Some Always);
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
        List.filter_map (fun (s, b) -> if b then Some s else None) puzzle in
      String.concat "" summary in
    Format.printf
      "@{<loc>Test Environment@}\n\
      \  @{<hint>prefix@} = %s\n\
      \  @{<hint>bindir@} = [$prefix/]%s\n\
      \  @{<hint>libdir@} = [$prefix/]%s\n\
       Testing %s\n%!" prefix bindir_suffix libdir_suffix summary;
    bindir, libdir, prefix, bindir_suffix, libdir_suffix, config

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
          None in
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
                String.sub remainder idx (String.length remainder - idx) in
              suffix, path in
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
  | `Not_tendered_bytecode (* Produced by ocamlopt, -output-complete-exe, etc.
                            *)
  | `Shebang  (* Launched using #! header *)
  | `Launcher (* Launched using the executable launcher *)
  | `Custom   (* Compiled with -custom *)
]

let classify_bytecode_image file =
  try
    In_channel.with_open_bin file (fun ic ->
      let start = really_input_string ic 2 in
      let is_RNTM = function
      | Bytesections.{name = Name.RNTM; _} -> true
      | _ -> false in
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

  val make :
    ?caml_ld_library_path:bool -> ?ocamllib:bool -> string -> string -> t

  val run_process :
    'a output
      -> ?runtime:string -> string -> string list -> ?no_stderr:bool -> t -> 'a
end = struct
  type t = {
    env: string array;
    serial: int;
    bindir: string;
    libdir: string;
    set_CAML_LD_LIBRARY_PATH: bool;
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

  (* Returns an environment where any variables in scrub have been removed and
     with effectively PATH=$bindir:$PATH and
     LD_LIBRARY_PATH=$libdir:$LD_LIBRARY_PATH on Unix or
     PATH=$bindir;$libdir;$PATH on Windows. *)
  let make ?(caml_ld_library_path=false) ?(ocamllib=false) bindir libdir =
    let keep binding =
      let equals = String.index binding '=' in
      let name = String.sub binding 0 equals in
      let value =
        String.sub binding (equals + 1) (String.length binding - equals - 1) in
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
      else if not Sys.win32 && name = "LD_LIBRARY_PATH" then
        Some (Printf.sprintf "%s=%s:%s" name libdir value)
      else
        Some binding
    in
    let bindings =
      List.filter_map keep (Array.to_list (Unix.environment ())) in
    let bindings =
      if Sys.win32
      || List.exists (String.starts_with ~prefix:"LD_LIBRARY_PATH=")
                     bindings then
        bindings
      else
        ("LD_LIBRARY_PATH=" ^ libdir)::bindings in
    let bindings =
      if ocamllib then
        ("OCAMLLIB=" ^ libdir)::bindings
      else
        bindings
    in
    let bindings =
      if caml_ld_library_path then
        ("CAML_LD_LIBRARY_PATH=" ^ Filename.concat libdir "stublibs")::bindings
      else
        bindings
    in
    let env = Array.of_list bindings in
    try {env; serial = Hashtbl.find environments env; bindir; libdir;
         set_CAML_LD_LIBRARY_PATH = caml_ld_library_path;
         set_OCAMLLIB = ocamllib}
    with Not_found ->
      let serial = Hashtbl.length environments + 1 in
      Hashtbl.add environments env serial;
      {env; serial; bindir; libdir;
       set_CAML_LD_LIBRARY_PATH = caml_ld_library_path; set_OCAMLLIB = ocamllib}

  type program =
  | Direct of string
  | Tender of string * string

  let null = Unix.openfile Filename.null [Unix.O_WRONLY] 0o200

  let last_environment = ref (-1)

  let rec run_process ~to_stdout ?runtime program args ?(no_stderr = false)
                      ({env; _} as environment) =
    flush stderr;
    flush stdout;
    let captured_output = "process-output" in
    let stdout, stderr =
      let flags = Unix.([O_RDWR; O_CREAT; O_TRUNC; O_CLOEXEC]) in
      let fd = Unix.openfile captured_output flags 0o600 in
      fd, fd in
    let stderr = if no_stderr || runtime <> None then null else stderr in
    let runtime, classification =
      match runtime with
      | None ->
          "", `Not_tendered_bytecode
      | Some runtime ->
          runtime, classify_bytecode_image program in
    let summarise f () =
      display_path f program;
      List.iter (fun x -> Format.pp_print_char f ' '; display_path f x) args;
      if not to_stdout then
        Format.pp_print_string f (" 1> " ^ captured_output);
      if no_stderr then
        Format.pp_print_string f (" 2>" ^ Filename.null) in
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
        if environment.set_CAML_LD_LIBRARY_PATH then
          Format.printf "\
@{<inline_code>> @}  @{<warning>CAML_LD_LIBRARY_PATH@}=\
  %a/stublibs:$CAML_LD_LIBRARY_PATH\n"
            display_path libdir;
        if environment.set_OCAMLLIB then
          Format.printf "\
@{<inline_code>> @}  @{<warning>OCAMLLIB@}=%a:$OCAMLLIB\n" display_path libdir
      end in
    try
      let pid =
        Unix.create_process_env program (Array.of_list (program::args)) env
                                Unix.stdin stdout stderr in
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
          if to_stdout then
            let format_line () s =
              Format.printf "@{<inline_code>>@} %s\n%!" s in
            let () = In_channel.fold_lines format_line () ic in
            []
          else
            In_channel.input_lines ic in
        Unix.close stdout;
        Sys.remove captured_output;
        lines in
      match status with
      | Unix.WEXITED n when runtime = "" && (n = 0 || not to_stdout) ->
          n, result
      | Unix.WEXITED 2 when classification = `Launcher ->
          run_process ~to_stdout runtime (program::args) ~no_stderr
                      environment
      | status ->
          fail_because "%s did not terminate as expected (%a)"
                       program print_process_status status
    with Unix.(Unix_error(ENOENT, "create_process", _)) as e ->
      Format.printf "@{<warning>%a@} <@{<warning>exit 2@}>\n%!" summarise ();
      display_environment ();
      if classification = `Shebang || classification = `Launcher then
        run_process ~to_stdout runtime (program::args) ~no_stderr environment
      else
        raise e

  let run_process : type s . s output -> ?runtime:string -> string
                      -> string list -> ?no_stderr:bool -> t -> s =
    fun output ?runtime program args ?no_stderr env ->
      match output with
      | Stdout ->
          run_process ~to_stdout:true ?runtime program args ?no_stderr env
          |> ignore
      | Return ->
          run_process ~to_stdout:false ?runtime program args ?no_stderr env
end

(* exe ["foo" = "foo.exe"] on Windows or ["foo"] otherwise. *)
let exe =
  if Sys.win32 then
    Fun.flip (^) ".exe"
  else
    Fun.id

(* This test verifies that a series of libraries can be loaded in a toplevel.
   Any failures cause the script to be aborted. *)
let load_libraries_in_toplevel env ?runtime toplevel ext libraries =
  Format.printf "\nTesting loading of libraries in %a\n%!"
                display_path toplevel;
  Out_channel.with_open_text "test_install_script.ml" (fun oc ->
    List.iter (fun library ->
      (* dynlink.cmxs does not exist, for obvious reasons, but we can check
         loading the library in ocamlnat "works". *)
      let ext =
        if library = "dynlink" && ext = "cmxs" then
          "cmxa"
        else
          ext
      in
      Printf.fprintf oc
        "#directory \"+%s\";;\n\
         #load \"%s.%s\";;\n\
         print_endline \"  Loaded %s.%s\";;"
      library library ext library ext) libraries;
    Printf.fprintf oc "#quit;;\n");
  let args =
    ["-noinit"; "-no-version"; "-noprompt"; "test_install_script.ml"] in
  Environment.run_process Stdout ?runtime toplevel args env;
  Sys.remove "test_install_script.ml"

(* This test verifies that a series of libraries can be loaded via Dynlink.
   Any failures will cause either an exception or a compilation error. *)
let load_libraries_in_prog env ?runtime ?target_runtime libdir compiler ~native
                           libraries =
  Out_channel.with_open_text "test_install_script.ml" (fun oc ->
    let emit_library library =
      if library <> "dynlink" (*&& (not native || library <> "threads")*) then
        let libdir = Filename.concat libdir library in
        let library = library ^ ".cma" in
        let lib = Filename.concat libdir library in
        Printf.fprintf oc
          "  Dynlink.loadfile (Dynlink.adapt_filename %S);\n\
          \  Printf.printf \"  Loaded %%s\\n\" (Dynlink.adapt_filename %S);"
          lib library

    in
    Printf.fprintf oc
      "let () =\n\
      \  let () = Dynlink.allow_unsafe_modules true in\n\
      \  print_endline \"\\nTesting loading of libraries with %s dynlink.\";\n"
      (if native then "native" else "bytecode");
    List.iter emit_library libraries;
  );
  flush stdout;
  let test_program =
    Filename.concat test_root (exe "test_install_script") in
  let () =
    let dynlink = if native then "dynlink.cmxa" else "dynlink.cma" in
    let args = [
      "-I"; "+dynlink"; dynlink; "-linkall";
      "-o"; test_program; "test_install_script.ml"
    ] in
    let runtime =
      if config.has_ocamlopt then
        None
      else
        runtime in
    Environment.run_process Stdout ?runtime compiler args env in
  let () =
    Environment.run_process Stdout
                            ?runtime:target_runtime test_program [] env in
  let files = [
    test_program;
    "test_install_script.ml";
    "test_install_script.cmi";
    "test_install_script.cm" ^ (if native then "x" else "o")
  ] in
  let files =
    if native then
      ("test_install_script" ^ Config.ext_obj)::files
    else
     files in
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
let test_bytecode_binaries ~full env bindir =
  let test_binary binary =
    if String.starts_with ~prefix:"ocaml" binary
    || String.starts_with ~prefix:"flexlink" binary then
    let binary = Filename.concat bindir binary in
    if is_executable binary then
      match classify_bytecode_image binary with
      | `Not_tendered_bytecode -> ()
      | (`Shebang | `Launcher | `Custom) as kind ->
          try
            let (result, output) =
              Environment.run_process Return
                                      binary ["-vnum"] ~no_stderr:true env in
            print_string "  Result: ";
            List.iter print_endline output;
            flush stdout;
            let incorrect_status =
              if full then
                (* First time around, everything is supposed to work! *)
                result <> 0
              else
                match kind with
                | `Custom ->
                    (* Executables compiled with -custom should work
                       regardless *)
                    result <> 0
                | `Launcher ->
                    (* Second time around, the executable launchers should
                       fail *)
                    not config.has_runtime_search && result <> 2
                | `Shebang ->
                    (* Second time around, the shebangs should all be broken so
                       Unix_error should already have been raised! *)
                    not config.has_runtime_search
            in
            if incorrect_status then
              fail_because "%s did not terminate as expected (%a)"
                           binary print_process_status (Unix.WEXITED result);
            if result = 2 then
              print_endline "unable to run"
          with Unix.Unix_error(_, "create_process", _) as e ->
            if full then
              raise e
            else
              print_endline "  Result: unable to run"
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
      dir in
  if String.ends_with ~suffix:Sys.argv.(3) dir then
    let l = String.length Sys.argv.(3) in
    String.sub dir 0 (String.length dir - l) ^ "$libdir"
  else
    dir

let () =
  Printf.printf "  %s: %%s\n%%!" display_lib;
  if is_directory Config.standard_library <> state then
    let () =
      Printf.eprintf "  *** Directory %%sfound!\n"
                     (if state then "not " else "")
    in
    exit 1
|} description)

let compile_with_options env compiler ~native ?runtime options
                         test_program description f =
  Printf.printf "  Compiling %s\n%!" description;
  write_test_program description;
  let test_program =
    Filename.concat test_root (exe test_program) in
  let ocamlcommon = if native then "ocamlcommon.cmxa" else "ocamlcommon.cma" in
  let args =
    "-I" :: "+compiler-libs" :: ocamlcommon ::
    "-o" :: test_program ::
    "test_install_script.ml" :: options in
  let () = Environment.run_process Stdout ?runtime compiler args env in
  let files = [
    "test_install_script.ml";
    "test_install_script.cmi";
    "test_install_script.cm" ^ (if native then "x" else "o")
  ] in
  let files =
    if native then
      ("test_install_script" ^ Config.ext_obj)::files
    else
     files in
  List.iter Sys.remove files;
  Some (f test_program)

let compile_obj env standard_library compiler ~native ?runtime
                runtime_lib test_program description f =
  Printf.printf "  Compiling %s\n%!" description;
  write_test_program description;
  let test_program =
    Filename.concat test_root (exe test_program) in
  let ocamlcommon = if native then "ocamlcommon.cmxa" else "ocamlcommon.cma" in
  let args = [
    "-I"; "+compiler-libs"; ocamlcommon;
    "-output-obj"; "-o"; "test_install_ocaml" ^ Config.ext_obj;
    "test_install_script.ml"
  ] in
  let () = Environment.run_process Stdout ?runtime compiler args env in
  let files = [
    "test_install_script.ml";
    "test_install_script.cmi";
    "test_install_script.cm" ^ (if native then "x" else "o");
    "test_install_ocaml" ^ Config.ext_obj;
  ] in
  let files =
    if native then
      ("test_install_script" ^ Config.ext_obj)::files
    else
     files in
  let objects = [
    "test_install_ocaml" ^ Config.ext_obj;
    Filename.concat (Filename.dirname Sys.executable_name)
                    ("test_install_main" ^ Config.ext_obj)
  ] in
  let flags =
    let libraries =
      if native then
        Config.native_c_libraries ^ " -lcomprmarsh "
          ^ Config.comprmarsh_c_libraries
      else
        Config.bytecomp_c_libraries in
    runtime_lib ^ " " ^ libraries
  in
  if Ccomp.call_linker Ccomp.Exe test_program objects flags <> 0 then
    fail_because "Unexpected linker error";
  List.iter Sys.remove files;
  Some (f test_program)

let compiler_where env ?runtime compiler =
  match Environment.run_process Return ?runtime compiler ["-where"] env with
  | (0, [where]) -> where
  | _ ->
      fail_because "Unexpected response from %s -where" compiler

let run_program env ?runtime test_program ~arg =
  let args = [string_of_bool arg; prefix; libdir_suffix] in
  Environment.run_process Stdout ?runtime test_program args env

(* XXX Code dup between these two paths *)
let compile_with_options ?(unix_only=false)
                         ?(needs_shared=false) ?(tendered=false) ~full env
                         compiler ~native ?runtime
                         options test_program description =
  if unix_only && Sys.win32
  || needs_shared && not config.supports_shared_libraries
  || native && not config.has_ocamlopt then
    None
  else
    let cont test_program ?runtime env ~arg =
      let runtime = if tendered then runtime else None in
      run_program env ?runtime test_program ~arg;
      if full then
        Some (fun ?runtime env ~arg ->
          let runtime = if tendered then runtime else None in
          run_program env ?runtime test_program ~arg;
          Sys.remove test_program;
          None)
      else
        (Sys.remove test_program; None)
    in
    compile_with_options
      env compiler ~native ?runtime options test_program description cont

let compile_obj ?(unix_only=false)
                ?(needs_shared=false) ~full env standard_library
                compiler ~native ?runtime runtime_lib
                test_program description =
  if unix_only && Sys.win32
  || needs_shared && not config.supports_shared_libraries
  || native && not config.has_ocamlopt then
    None
  else
    let cont test_program ?runtime env ~arg =
      run_program env test_program ~arg;
      if full then
        Some (fun ?runtime env ~arg -> run_program env test_program ~arg;
        Sys.remove test_program;
        None)
      else
        (Sys.remove test_program; None)
    in
    compile_obj env (if full then None else Some standard_library) compiler
                ~native ?runtime runtime_lib test_program description cont

(* This test verifies both that all compilation mechanisms are working and that
   each of these programs can correctly identify the Standard Library location.
   Any failures will cause either an exception or a compilation error. *)
let test_standard_library_location ~full env bindir libdir ocamlc ocamlopt =
  Format.printf "\nTesting compilation mechanisms for %a\n%!"
                display_path bindir;
  let runtime =
    if full || config.has_runtime_search || config.has_ocamlopt then
      None
    else
      Some (exe (Filename.concat bindir "ocamlrun"))
  in
  let ocamlc_where = compiler_where env ?runtime ocamlc in
  let ocamlopt_where =
    if config.has_ocamlopt then
      compiler_where env ocamlopt
    else
      "n/a"
  in
  Format.printf "  ocamlc -where: %a\n  ocamlopt -where: %a\n%!"
                display_path ocamlc_where display_path ocamlopt_where;
  let unix_only = true in
  let tendered = true in
  let needs_shared = true in
  (* With an absolute header, in bytecode-only mode, flexlink is a bytecode
     executable and cannot run in the second phase. *)
  let disabled_for_bytecode_only_windows =
    not full && Sys.win32
    && not config.has_runtime_search && not config.has_ocamlopt in
  let programs = List.filter_map Fun.id [
    (* XXX Shouldn't this more be that the test is expected to fail?? *)
    compile_with_options ~tendered ~full env ocamlc ?runtime ~native:false
      [] "test_bytecode"
      "Bytecode (with tender)";
    compile_with_options ~full env ocamlc ?runtime ~native:false
      ~unix_only:disabled_for_bytecode_only_windows
      ["-custom"] "test_custom_static"
      "Bytecode (-custom static runtime)";
    compile_with_options
      ~unix_only ~needs_shared ~full env ocamlc ?runtime ~native:false
      ["-custom"; "-runtime-variant"; "_shared"] "test_custom_shared"
      "Bytecode (-custom shared runtime)";
    compile_obj ~full env libdir ocamlc ?runtime ~native:false
      "-lcamlrun" "test_output_obj_static"
      "Bytecode (-output-obj static runtime)";
    compile_obj
      ~unix_only ~needs_shared ~full env libdir ocamlc ?runtime ~native:false
      "-lcamlrun_shared" "test_output_obj_shared"
      "Bytecode (-output-obj shared runtime)";
    compile_with_options ~full env ocamlc ?runtime ~native:false
      ~unix_only:disabled_for_bytecode_only_windows
      ["-output-complete-exe"] "test_output_complete_exe_static"
      "Bytecode (-output-complete-exe static runtime)";
    compile_with_options
      ~unix_only ~needs_shared ~full env ocamlc ?runtime ~native:false
      ["-output-complete-exe"; "-runtime-variant"; "_shared"]
      "test_output_complete_exe_shared"
      "Bytecode (-output-complete-exe shared runtime)";
    compile_with_options ~full env ocamlopt ~native:true
      [] "test_native_static"
      "Native (static runtime)";
    compile_obj ~full env libdir ocamlopt ~native:true
      "-lasmrun" "test_native_output_obj_static"
      "Native (-output-obj static runtime)";
    compile_obj
      ~unix_only ~needs_shared ~full env libdir ocamlopt ~native:true
      "-lasmrun_shared" "test_native_output_obj_shared"
      "Native (-output-obj shared runtime)";
  ] in
  let runtime =
    if config.has_runtime_search_target || full then
      None
    else
      Some (exe (Filename.concat bindir "ocamlrun"))
  in
  Printf.printf "Running programs\n%!";
  List.filter_map (fun f -> f ?runtime env ~arg:true) programs

(* XXX ~full is more the phase - have we renamed the root, etc. *)
let run_tests ~full env bindir libdir libraries =
  let ocaml = exe (Filename.concat bindir "ocaml") in
  let ocamlnat = exe (Filename.concat bindir "ocamlnat") in
  let ocamlc = exe (Filename.concat bindir "ocamlc") in
  let ocamlopt = exe (Filename.concat bindir "ocamlopt") in
  let runtime =
    if full || config.has_runtime_search then
      None
    else
      Some (exe (Filename.concat bindir "ocamlrun")) in
  let target_runtime =
    if full || config.has_runtime_search_target then
      None
    else
      Some (exe (Filename.concat bindir "ocamlrun")) in
  if config.supports_shared_libraries then begin
    load_libraries_in_toplevel env ?runtime ocaml "cma" config.libraries end;
  if config.has_ocamlnat then
    load_libraries_in_toplevel env ocamlnat "cmxs" config.libraries;
  if config.supports_shared_libraries then
    load_libraries_in_prog env ?runtime ?target_runtime libdir ocamlc
                           ~native:false libraries;
  if config.has_ocamlopt && config.supports_shared_libraries then
    load_libraries_in_prog env libdir ocamlopt ~native:true libraries;
  test_bytecode_binaries ~full env bindir;
  test_standard_library_location ~full env bindir libdir ocamlc ocamlopt

let () =
  Compmisc.init_path ();
  let env = Environment.make bindir libdir in
  let programs =
    run_tests ~full:true env bindir libdir config.libraries in
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
  Printf.printf "Re-running test programs\n%!";
  let env = Environment.make bindir libdir in
  let runtime =
    if config.has_runtime_search_target then
      None
    else
      Some (exe (Filename.concat bindir "ocamlrun")) in
  List.iter (fun f -> assert (f ?runtime env ~arg:false = None)) programs;
  let env =
    Environment.make ~caml_ld_library_path:true ~ocamllib:true bindir libdir in
  Compmisc.reinit_path ~standard_library:libdir ();
  let programs = run_tests ~full:false env bindir libdir config.libraries in
  assert (programs = [])
