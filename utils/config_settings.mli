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

  Values in this module are all set by [configure.ac] and form the defaults for
  {!Clflags.config}.

  This module should not normally be used directly - read values from
  {!Clflags.config} instead.

  {b Warning:} this module is unstable and part of
  {{!Compiler_libs}compiler-libs}.

*)

val bindir: string
val standard_library_default: string
val host : string
val target : string
val reserved_header_bits : int
val flat_float_array : bool
val windows_unicode: bool
val supports_shared_libraries: bool
val native_dynlink: bool
val native_compiler: bool
val architecture: string
val model: string
val system: Config_constants.System.t
val abi: string
val with_frame_pointers : bool
val flambda : bool
val with_flambda_invariants : bool
val with_cmm_invariants : bool
val function_sections : bool
val afl_instrument : bool
val tsan : bool
val ccomp_type: string
val c_compiler: string
val c_output_obj: string
val c_has_debug_prefix_map : bool
val as_has_debug_prefix_map : bool
val ocamlc_cflags : string
val ocamlc_cppflags : string
val bytecomp_c_libraries: string
val native_c_libraries: string
val native_ldflags : string
val native_pack_linker: string
val mkdll: string
val mkexe: string
val mkmaindll: string
val linker_is_flexlink: bool
val default_rpath: string
val mksharedlibrpath: string
val ar: string
val asm: string
val asm_cfi_supported: bool
val ext_obj: string
val ext_asm: string
val ext_lib: string
val ext_dll: string
val ext_exe: string
val systhread_supported : bool
val flexdll_dirs : string list
val ar_supports_response_files: bool
