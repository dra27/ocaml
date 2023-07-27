(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*             Xavier Leroy, projet Cristal, INRIA Rocquencourt           *)
(*                                                                        *)
(*   Copyright 2005 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)



(** Command line flags *)

(** Optimization parameters represented as ints indexed by round number. *)
module Int_arg_helper : sig
  type parsed

  val parse : string -> string -> parsed ref -> unit

  type parse_result =
    | Ok
    | Parse_failed of exn
  val parse_no_error : string -> parsed ref -> parse_result

  val get : key:int -> parsed -> int

  val get_default : parsed -> int
end

(** Optimization parameters represented as floats indexed by round number. *)
module Float_arg_helper : sig
  type parsed

  val parse : string -> string -> parsed ref -> unit

  type parse_result =
    | Ok
    | Parse_failed of exn
  val parse_no_error : string -> parsed ref -> parse_result

  val get : key:int -> parsed -> float

  val get_default : parsed -> float
end

type inlining_arguments = {
  inline_call_cost : int option;
  inline_alloc_cost : int option;
  inline_prim_cost : int option;
  inline_branch_cost : int option;
  inline_indirect_cost : int option;
  inline_lifting_benefit : int option;
  inline_branch_factor : float option;
  inline_max_depth : int option;
  inline_max_unroll : int option;
  inline_threshold : float option;
  inline_toplevel_threshold : int option;
}

val classic_arguments : inlining_arguments
val o1_arguments : inlining_arguments
val o2_arguments : inlining_arguments
val o3_arguments : inlining_arguments

(** Set all the inlining arguments for a round.
    The default is set if no round is provided. *)
val use_inlining_arguments_set : ?round:int -> inlining_arguments -> unit

val objfiles : string list ref
val ccobjs : string list ref
val dllibs : string list ref
val cmi_file : string option ref
val compile_only : bool ref
val output_name : string option ref
val include_dirs : string list ref
val no_std_include : bool ref
val no_cwd : bool ref
val print_types : bool ref
val make_archive : bool ref
val debug : bool ref
val debug_full : bool ref
val unsafe : bool ref
val use_linscan : bool ref
val link_everything : bool ref
val custom_runtime : bool ref
val no_check_prims : bool ref
val bytecode_compatible_32 : bool ref
val output_c_object : bool ref
val output_complete_object : bool ref
val output_complete_executable : bool ref
val all_ccopts : string list ref
val classic : bool ref
val nopervasives : bool ref
val match_context_rows : int ref
val safer_matching : bool ref
val open_modules : string list ref
val preprocessor : string option ref
val all_ppx : string list ref
val absname : bool ref
val annotations : bool ref
val binary_annotations : bool ref
val use_threads : bool ref
val noassert : bool ref
val verbose : bool ref
val noprompt : bool ref
val nopromptcont : bool ref
val init_file : string option ref
val noinit : bool ref
val noversion : bool ref
val use_prims : string ref
val use_runtime : string ref
val plugin : bool ref
val principal : bool ref
val real_paths : bool ref
val recursive_types : bool ref
val strict_sequence : bool ref
val strict_formats : bool ref
val applicative_functors : bool ref
val make_runtime : bool ref
val c_compiler : string option ref
val no_auto_link : bool ref
val dllpaths : string list ref
val make_package : bool ref
val for_package : string option ref
val error_size : int ref
val float_const_prop : bool ref
val transparent_modules : bool ref
val unique_ids : bool ref
val locations : bool ref
val dump_source : bool ref
val dump_parsetree : bool ref
val dump_typedtree : bool ref
val dump_shape : bool ref
val dump_rawlambda : bool ref
val dump_lambda : bool ref
val dump_rawclambda : bool ref
val dump_clambda : bool ref
val dump_rawflambda : bool ref
val dump_flambda : bool ref
val dump_flambda_let : int option ref
val dump_instr : bool ref
val keep_camlprimc_file : bool ref
val keep_asm_file : bool ref
val optimize_for_speed : bool ref
val dump_cmm : bool ref
val dump_selection : bool ref
val dump_cse : bool ref
val dump_live : bool ref
val dump_spill : bool ref
val dump_split : bool ref
val dump_interf : bool ref
val dump_prefer : bool ref
val dump_regalloc : bool ref
val dump_reload : bool ref
val dump_scheduling : bool ref
val dump_linear : bool ref
val dump_interval : bool ref
val keep_startup_file : bool ref
val dump_combine : bool ref
val native_code : bool ref
val inline_threshold : Float_arg_helper.parsed ref
val inlining_report : bool ref
val simplify_rounds : int option ref
val default_simplify_rounds : int ref
val rounds : unit -> int
val inline_max_unroll : Int_arg_helper.parsed ref
val inline_toplevel_threshold : Int_arg_helper.parsed ref
val inline_call_cost : Int_arg_helper.parsed ref
val inline_alloc_cost : Int_arg_helper.parsed ref
val inline_prim_cost : Int_arg_helper.parsed ref
val inline_branch_cost : Int_arg_helper.parsed ref
val inline_indirect_cost : Int_arg_helper.parsed ref
val inline_lifting_benefit : Int_arg_helper.parsed ref
val inline_branch_factor : Float_arg_helper.parsed ref
val dont_write_files : bool ref
val shared : bool ref
val dlcode : bool ref
val pic_code : bool option ref
val runtime_variant : string ref
val with_runtime : bool ref
val force_slash : bool ref
val keep_docs : bool ref
val keep_locs : bool ref
val opaque : bool ref
val profile_columns : Profile.column list ref
val flambda_invariant_checks : bool option ref
val unbox_closures : bool ref
val unbox_closures_factor : int ref
val default_unbox_closures_factor : int
val unbox_free_vars_of_closures : bool ref
val unbox_specialised_args : bool ref
val clambda_checks : bool ref
val cmm_invariants : bool option ref
val inline_max_depth : Int_arg_helper.parsed ref
val remove_unused_arguments : bool ref
val dump_flambda_verbose : bool ref
val classic_inlining : bool ref
val afl_instrument : bool option ref
val afl_inst_ratio : int ref
val function_sections : bool ref
val interface_suffix: string ref
(** Suffix for interface file names *)

val all_passes : string list ref
val dumped_pass : string -> bool
val set_dumped_pass : string -> bool -> unit

val dump_into_file : bool ref
val dump_dir : string option ref

(* Support for flags that can also be set from an environment variable *)
type 'a env_reader = {
  parse : string -> 'a option;
  print : 'a -> string;
  usage : string;
  env_var : string;
}

val color : Misc.Color.setting option ref
val color_reader : Misc.Color.setting env_reader

val error_style : Misc.Error_style.setting option ref
val error_style_reader : Misc.Error_style.setting env_reader

val unboxed_types : bool ref

val insn_sched : bool ref
val insn_sched_default : bool

module Compiler_pass : sig
  type t = Parsing | Typing | Lambda | Scheduling | Emit
  val of_string : string -> t option
  val to_string : t -> string
  val is_compilation_pass : t -> bool
  val available_pass_names : filter:(t -> bool) -> native:bool -> string list
  val can_save_ir_after : t -> bool
  val compare : t -> t -> int
  val to_output_filename: t -> prefix:string -> string
  val of_input_filename: string -> t option
end
val stop_after : Compiler_pass.t option ref
val should_stop_after : Compiler_pass.t -> bool
val set_save_ir_after : Compiler_pass.t -> bool -> unit
val should_save_ir_after : Compiler_pass.t -> bool

(** Distribution configurable settings. Values in this record can all be set
    via [configure.ac]. *)
type config = private {
  mutable file: string option;
  (** The filename the configuration was loaded from, or [None] if the
      compiler's configure'd configuration is in use. *)

  mutable bindir: string;
  (** The directory containing the binary programs *)

  mutable standard_library_default: string;
  (** The default directory containing the standard libraries (when OCAMLLIB and
      CAMLLIB are not set). *)

  mutable host : string;
  (** Whether the compiler is a cross-compiler *)

  mutable target : string;
  (** Whether the compiler is a cross-compiler *)

  mutable reserved_header_bits : int;
  (** How many bits of a block's header are reserved *)

  mutable flat_float_array : bool;
  (** Whether the compiler and runtime automagically flatten float
      arrays *)

  mutable windows_unicode: bool;
  (** Whether Windows Unicode runtime is enabled *)

  mutable supports_shared_libraries: bool;
  (** Whether shared libraries are supported *)

  mutable native_dynlink: bool;
  (** Whether native shared libraries are supported *)

  mutable native_compiler: bool;
  (** Whether the native compiler is available or not *)

  mutable architecture: string;
  (** Name of processor type for the native-code compiler *)

  mutable model: string;
  (** Name of processor submodel for the native-code compiler *)

  mutable system: Config_constants.System.t;
  (** Name of operating system for the native-code compiler *)

  mutable abi: string;
  (** ["default"] or the name of the Application Binary Interface (ABI) in use
      for {!system} (e.g. ["eabi"] or ["eabihf"] for 32-bit arm on Linux) *)

  mutable with_frame_pointers : bool;
  (** Whether assembler should maintain frame pointers *)

  mutable flambda : bool;
  (** Whether the compiler was configured for flambda *)

  mutable with_flambda_invariants : bool;
  (** Whether the invariants checks for flambda are enabled *)

  mutable with_cmm_invariants : bool;
  (** Whether the invariants checks for Cmm are enabled *)

  mutable function_sections : bool;
  (** Whether the compiler was configured to generate
      each function in a separate section *)

  mutable afl_instrument : bool;
  (** Whether afl-fuzz instrumentation is generated by default *)

  mutable tsan : bool;
  (** Whether ThreadSanitizer instrumentation is enabled *)

  mutable ccomp_type: string;
  (** The "kind" of the C compiler, assembler and linker used: one of
      "cc" (for Unix-style C compilers)
      "msvc" (for Microsoft Visual C++ and MASM) *)

  mutable c_compiler: string;
  (** The compiler to use for compiling C files *)

  mutable c_output_obj: string;
  (** Name of the option of the C compiler for specifying the output
      file *)

  mutable c_has_debug_prefix_map : bool;
  (** Whether the C compiler supports -fdebug-prefix-map *)

  mutable as_has_debug_prefix_map : bool;
  (** Whether the assembler supports --debug-prefix-map *)

  mutable ocamlc_cflags : string;
  (** The flags ocamlc should pass to the C compiler *)

  mutable ocamlc_cppflags : string;
  (** The flags ocamlc should pass to the C preprocessor *)

  mutable bytecomp_c_libraries: string;
  (** The C libraries to link with custom runtimes *)

  mutable native_c_libraries: string;
  (** The C libraries to link with native-code programs *)

  mutable native_ldflags : string;
  (* Flags to pass to the system linker *)

  mutable native_pack_linker: string;
  (** The linker to use for packaging (ocamlopt -pack) and for partial
      links (ocamlopt -output-obj). *)

  mutable mkdll: string;
  (** The linker command line to build dynamic libraries. *)

  mutable mkexe: string;
  (** The linker command line to build executables. *)

  mutable mkmaindll: string;
  (** The linker command line to build main programs as dlls. *)

  mutable linker_is_flexlink: bool;
  (** The linker command line calls [flexlink] rather than the C compiler *)

  mutable default_rpath: string;
  (** Option to add a directory to be searched for libraries at runtime
      (used by ocamlmklib) *)

  mutable mksharedlibrpath: string;
  (** Option to add a directory to be searched for shared libraries at runtime
      (used by ocamlmklib) *)

  mutable ar: string;
  (** Name of the ar command, or "" if not needed  (MSVC) *)

  mutable asm: string;
  (** The assembler (and flags) to use for assembling
      ocamlopt-generated code. *)

  mutable asm_cfi_supported: bool;
  (** Whether assembler understands CFI directives *)

  mutable ext_obj: string;
  (** Extension for object files, e.g. [.o] under Unix. *)

  mutable ext_asm: string;
  (** Extension for assembler files, e.g. [.s] under Unix. *)

  mutable ext_lib: string;
  (** Extension for library files, e.g. [.a] under Unix. *)

  mutable ext_dll: string;
  (** Extension for dynamically-loaded libraries, e.g. [.so] under Unix.*)

  mutable ext_exe: string;
  (** Extension for executable programs, e.g. [.exe] under Windows. *)

  mutable systhread_supported : bool;
  (** Whether the system thread library is implemented *)

  mutable flexdll_dirs : string list;
  (** Directories needed for the FlexDLL objects *)

  mutable ar_supports_response_files: bool
  (** Whether ar supports @FILE arguments. *)
}

val config : config
(** The active distribution configuration. Initially set with
    {!Config_settings}. The configuration can be replaced by passing an
    alternate module to {!load_config}. *)

val config_hook : (config -> unit) -> unit
(** Registers a hook function to be called after {!load_config} has applied a
    new configuration. *)

module type Config = module type of Config_settings

val load_config : ?file:string -> (module Config) -> unit
(** Replaces {!config} with the fields from the supplied module. *)

val arg_spec : (string * Arg.spec * string) list ref

(* [add_arguments __LOC__ args] will add the arguments from [args] at
   the end of [arg_spec], checking that they have not already been
   added by [add_arguments] before. A warning is printed showing the
   locations of the function from which the argument was previously
   added. *)
val add_arguments : string -> (string * Arg.spec * string) list -> unit

(* [create_usage_msg program] creates a usage message for [program] *)
val create_usage_msg: string -> string
(* [print_arguments usage] print the standard usage message *)
val print_arguments : string -> unit

(* [reset_arguments ()] clear all declared arguments *)
val reset_arguments : unit -> unit
