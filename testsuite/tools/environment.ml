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

module Import = struct
  type launch_mode = Header_exe | Header_shebang

  type executable =
  | Tendered of {header:launch_mode; dlls:bool}
  | Custom
  | Vanilla

  type _ output =
  | Execute : unit output
  | Return : (int * string list) output

  type phase = Original | Renamed

  type mode = Bytecode | Native
end

open Import

type t = {
  env: string array;
  serial: int;
  test_root: string;
  test_root_logical: string option;
  prefix: string;
  bindir_suffix: string;
  libdir_suffix: string;
  phase: phase;
  caml_ld_library_path: shim;
  ocamllib: shim;
  camllib: shim;
  prefix_path_with_cwd: bool;
  pp_path: Format.formatter -> string -> unit;
  verbose: bool;
}
and shim =
| Unshimmed
| Shim
| Test of string

(* Print a formatted message to [stderr] and [exit 1] *)
let fail_because fmt = Format.ksprintf (fun s -> prerr_endline s; exit 1) fmt

let string_of_process_status = function
| Unix.WEXITED n -> "exit " ^ string_of_int n
| Unix.WSIGNALED n -> Sys.signal_to_string n
| Unix.WSTOPPED n -> "stopped with " ^ Sys.signal_to_string n

(* [classify_executable file] determines if [file] is :
   - Tendered bytecode with an executable header
   - Scripted bytecode invoking ocamlrun with a #! header
   - Custom bytecode (produced with ocamlc -custom)
   - Vanilla executables (vanilla ocamlopt or any of the caml_startup mechanisms
     via -output-obj, -output-complete-exe, etc.). The actual OCaml program may
     be bytecode (but it will have been embedded in a C object). *)
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
        Tendered {header = Header_shebang; dlls = List.exists is_DLLS sections}
      else if List.exists is_RNTM sections then
        Tendered {header = Header_exe; dlls = List.exists is_DLLS sections}
      else
        Custom)
  with End_of_file | Bytesections.Bad_magic_number ->
    Vanilla

let is_shebang program =
  if Filename.is_relative program then
    false
  else
    match classify_executable program with
    | Tendered {header = Header_shebang; _} -> true
    | _ -> false

let launched_via_stub program =
  match classify_executable program with
  | Tendered {header = Header_exe; _} -> true
  | _ -> false

module StringSet = Set.Make(String)

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

let prefix {prefix; _} = prefix
let bindir {prefix; bindir_suffix; _} = Filename.concat prefix bindir_suffix
let libdir {prefix; libdir_suffix; _} = Filename.concat prefix libdir_suffix
let libdir_suffix {libdir_suffix; _} = libdir_suffix
let test_root {test_root; _} = test_root
let test_root_logical {test_root_logical; _} = test_root_logical

let tool_path env mode bytecode native =
  let tool = Toolchain.exe (if mode = Bytecode then bytecode else native) in
  Filename.concat (bindir env) tool

let ocamlrun env =
  Filename.concat (bindir env) (Toolchain.exe "ocamlrun")

let in_libdir env path =
  Filename.concat (libdir env) path

let in_test_root {test_root; _} path =
  Filename.concat test_root path

let pp_path {pp_path; _} = pp_path

let verbose {verbose; _} = verbose

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
  let libdir = libdir env in
  let stublibs = in_libdir env "stublibs" in
  let bindings =
    bindings
    |> apply "CAMLLIB" libdir env.camllib
    |> apply "OCAMLLIB" libdir env.ocamllib
    |> apply "CAML_LD_LIBRARY_PATH" stublibs env.caml_ld_library_path
    |> apply_cwd_prefix
  in
  {env with env = Array.of_list bindings}

let is_renamed {phase; _} = (phase = Renamed)

(* Returns an environment where any variables in scrub have been removed and
   with effectively PATH=$bindir:$PATH and
   LD_LIBRARY_PATH=$libdir:$LD_LIBRARY_PATH on Unix or
   DYLD_LIBRARY_PATH=$libdir$:DYLD_LIBRARY_PATH on macOS or
   PATH=$bindir;$libdir;$PATH on Windows. *)
let make pp_path ~verbose ~test_root ~test_root_logical
         ~phase ~prefix ~bindir_suffix ~libdir_suffix =
  let bindir = Filename.concat prefix bindir_suffix in
  let libdir = Filename.concat prefix libdir_suffix in
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
  {phase; env = Array.of_list bindings; serial; test_root; test_root_logical;
   prefix; bindir_suffix; libdir_suffix; ocamllib = Unshimmed;
   camllib = Unshimmed; caml_ld_library_path = Unshimmed;
   prefix_path_with_cwd = false; pp_path; verbose}

let last_environment = ref (-1)

let format_line () = Format.printf "@{<inline_code>>@} %s\n%!"

let display_execution pp_path ~verbose level status pid ~runtime
                      program argv0 args environment =
  let pp_program style program f = function
  | Some argv0 ->
      Format.fprintf f "@{<%s>%s (from %a)@}"
                       style argv0 pp_path program
  | None ->
      Format.fprintf f "@{<%s>%a@}" style pp_path program
  in
  let pp_arg f x = Format.pp_print_char f ' '; pp_path f x in
  let pp_args = Format.pp_print_list ~pp_sep:(Fun.const ignore) pp_arg in
  let pp_status ~exited_normally style f status =
    if not exited_normally then
      Format.fprintf f " <@{<%s>%s@}>" style (string_of_process_status status)
  in
  let pp_environment f environment =
    if environment.prefix_path_with_cwd then
      Format.pp_print_string f "PATH=.:$PATH ";
    let pp_shim name = function
      | Unshimmed ->
          ()
      | Shim ->
          Format.fprintf f "@{<warning>%s=%s@} " name (libdir environment)
      | Test test ->
          Format.fprintf f "%s=%s " name test
    in
    pp_shim "CAML_LD_LIBRARY_PATH" environment.caml_ld_library_path;
    pp_shim "OCAMLLIB" environment.ocamllib;
    pp_shim "CAMLLIB" environment.camllib
  in
  let pp_pid f = function
  | Some pid when verbose -> Format.fprintf f " [@{<loc>%d@}]" pid
  | _ -> ()
  in
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
      pp_path (bindir environment);
    if not Sys.win32 then
      Format.printf "\
        @{<inline_code>> @}  @{<loc>%s=%a:$%s@}\n"
      ld_library_path_name pp_path (libdir environment)
      ld_library_path_name
  end

let run_one pp_path ~verbose ~just_execute ~fails ~quiet ~runtime
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
        display_execution pp_path ~verbose
          `Error status pid ~runtime program argv0 args environment;
        fail_because "%s did not terminate as expected (got %s)"
                     display_argv0 (string_of_process_status status)
  in
  if not quiet then
    display_execution pp_path ~verbose
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

let rec run pp_path ~verbose ~fails ~quiet env program ?argv0 args acc strategy
            ~just_execute =
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
        run_one pp_path ~verbose ~just_execute ~fails ~quiet ~runtime program
                ?argv0 args env
      in
      run pp_path ~verbose ~quiet ~fails env program ?argv0 args acc strategy
          ~just_execute

let run_process : type s . s output
                    -> ?runtime:bool -> ?stubs:bool -> ?stdlib:bool
                    -> ?prefix_path_with_cwd:bool
                    -> ?quiet:bool -> ?fails:bool
                    -> t -> string -> ?argv0:string -> string list -> s =
  fun output ?(runtime = false) ?(stubs = false) ?(stdlib = false)
             ?(prefix_path_with_cwd = false) ?(quiet = false) ?(fails = false)
             ({verbose; _} as env) program ?argv0 args ->
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
          Some (ocamlrun env)
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
    let run =
      run env.pp_path ~verbose ~fails ~quiet
          env program ?argv0 args (-1, []) strategy in
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

let lib mode name =
  if mode = Native then
    name ^ ".cmxa"
  else
    name ^ ".cma"
