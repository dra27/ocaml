(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*             Xavier Leroy, projet Cristal, INRIA Rocquencourt           *)
(*                                                                        *)
(*   Copyright 1996 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

(** Distribution configured settings

  Values in this module are all set by [configure.ac].

  {b Warning:} this module is unstable and part of
  {{!Compiler_libs}compiler-libs}.

*)

val bindir: string
(** The directory containing the binary programs *)

val standard_library_default: string
(** The default directory containing the standard libraries (when OCAMLLIB and
    CAMLLIB are not set). *)

val ccomp_type: string
(** The "kind" of the C compiler, assembler and linker used: one of
    "cc" (for Unix-style C compilers)
    "msvc" (for Microsoft Visual C++ and MASM) *)

val c_compiler: string
(** The compiler to use for compiling C files *)

val c_output_obj: string
(** Name of the option of the C compiler for specifying the output
    file *)

val c_has_debug_prefix_map : bool
(** Whether the C compiler supports -fdebug-prefix-map *)

val as_has_debug_prefix_map : bool
(** Whether the assembler supports --debug-prefix-map *)

val ocamlc_cflags : string
(** The flags ocamlc should pass to the C compiler *)

val ocamlc_cppflags : string
(** The flags ocamlc should pass to the C preprocessor *)

val bytecomp_c_libraries: string
(** The C libraries to link with custom runtimes *)

val native_c_libraries: string
(** The C libraries to link with native-code programs *)

val native_ldflags : string
(* Flags to pass to the system linker *)

val native_pack_linker: string
(** The linker to use for packaging (ocamlopt -pack) and for partial
    links (ocamlopt -output-obj). *)

val mkdll: string
(** The linker command line to build dynamic libraries. *)

val mkexe: string
(** The linker command line to build executables. *)

val mkmaindll: string
(** The linker command line to build main programs as dlls. *)

val default_rpath: string
(** Option to add a directory to be searched for libraries at runtime
    (used by ocamlmklib) *)

val mksharedlibrpath: string
(** Option to add a directory to be searched for shared libraries at runtime
    (used by ocamlmklib) *)

val ar: string
(** Name of the ar command, or "" if not needed  (MSVC) *)

val native_compiler: bool
(** Whether the native compiler is available or not *)

val architecture: string
(** Name of processor type for the native-code compiler *)

val model: string
(** Name of processor submodel for the native-code compiler *)

val system: string
(** Name of operating system for the native-code compiler *)

val asm: string
(** The assembler (and flags) to use for assembling
    ocamlopt-generated code. *)

val asm_cfi_supported: bool
(** Whether assembler understands CFI directives *)

val with_frame_pointers : bool
(** Whether assembler should maintain frame pointers *)

val ext_obj: string
(** Extension for object files, e.g. [.o] under Unix. *)

val ext_asm: string
(** Extension for assembler files, e.g. [.s] under Unix. *)

val ext_lib: string
(** Extension for library files, e.g. [.a] under Unix. *)

val ext_dll: string
(** Extension for dynamically-loaded libraries, e.g. [.so] under Unix.*)

val ext_exe: string
(** Extension for executable programs, e.g. [.exe] under Windows. *)

val systhread_supported : bool
(** Whether the system thread library is implemented *)

val flexdll_dirs : string list
(** Directories needed for the FlexDLL objects *)

val host : string
(** Whether the compiler is a cross-compiler *)

val target : string
(** Whether the compiler is a cross-compiler *)

val flambda : bool
(** Whether the compiler was configured for flambda *)

val with_flambda_invariants : bool
(** Whether the invariants checks for flambda are enabled *)

val with_cmm_invariants : bool
(** Whether the invariants checks for Cmm are enabled *)

val reserved_header_bits : int
(** How many bits of a block's header are reserved *)

val flat_float_array : bool
(** Whether the compiler and runtime automagically flatten float
    arrays *)

val function_sections : bool
(** Whether the compiler was configured to generate
    each function in a separate section *)

val windows_unicode: bool
(** Whether Windows Unicode runtime is enabled *)

val supports_shared_libraries: bool
(** Whether shared libraries are supported *)

val native_dynlink: bool
(** Whether native shared libraries are supported *)

val afl_instrument : bool
(** Whether afl-fuzz instrumentation is generated by default *)

val ar_supports_response_files: bool
(** Whether ar supports @FILE arguments. *)

val tsan : bool
(** Whether ThreadSanitizer instrumentation is enabled *)
