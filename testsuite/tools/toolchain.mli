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

val c_compiler_debug_paths_can_be_absolute : bool

val linker_propagates_debug_information : bool

val c_compiler_always_embeds_build_path : bool

val asmrun_assembled_with_cc : bool

val assembler_embeds_build_path : bool

val linker_embeds_build_path : bool

val linker_is_flexlink : bool

val exe : string -> string

val no_caml_executable_name : bool
