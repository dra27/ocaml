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

module Import : sig
  type launch_mode =
  | Header_exe
  | Header_shebang

  type executable =
  | Tendered of {header:launch_mode; dlls:bool}
  | Custom
  | Vanilla

  (* [Environment.run_process] either [Return]s the exit code and lines of
     output from running a command, or assumes it exits with code 0 and displays
     the output directly to standard output. *)
  type _ output =
  | Execute : unit output
  | Return : (int * string list) output

  type phase =
  | Original
  | Renamed

  type mode =
  | Bytecode
  | Native

end

open Import

type t

(* [make bindir libdir] creates a new environment where [bindir] will be in
   [PATH] and with [libdir] available for loading of shared libraries (i.e.
   with [LD_LIBRARY_PATH] / [DYLD_LIBRARY_PATH] set or updated).
   [?env] allows [CAML_LD_LIBRARY_PATH], [OCAMLLIB] and [CAMLLIB] to be set
   (they will be unset otherwise). *)
val make : (Format.formatter -> string -> unit) -> verbose:bool
  -> test_root:string -> test_root_logical:string option -> phase:phase
  -> prefix:string -> bindir_suffix:string -> libdir_suffix:string -> t

val is_renamed : t -> bool

val test_root : t -> string

val test_root_logical : t -> string option

val prefix : t -> string

val bindir : t -> string

val libdir : t -> string

val libdir_suffix : t -> string

val tool_path : t -> mode -> string -> string -> string

val ocamlrun : t -> string

val in_libdir : t -> string -> string

val in_test_root : t -> string -> string

val pp_path : t -> (Format.formatter -> string -> unit)

val verbose : t -> bool

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

val fail_because : ('a, unit, string, 'b) format4 -> 'a

val classify_executable : string -> executable

val launched_via_stub : string -> bool

val erase_file : string -> unit

val lib : mode -> string -> string
