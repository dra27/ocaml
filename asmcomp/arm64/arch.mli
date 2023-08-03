# 2 "asmcomp/arm64/arch.mli"
(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*             Xavier Leroy, projet Gallium, INRIA Rocquencourt           *)
(*                 Benedikt Meurer, University of Siegen                  *)
(*                                                                        *)
(*   Copyright 2013 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*   Copyright 2012 Benedikt Meurer.                                      *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

include module type of struct include Operations.Arm64 end

(* Specific operations for the ARM processor, 64-bit mode *)

val macosx : bool

(* Machine-specific command-line options *)

val command_line_options : (string * Arg.spec * string) list

(* Sizes, endianness *)

val big_endian : bool

val size_addr : int

val size_int : int

val size_float : int

val allow_unaligned_access : bool

(* Behavior of division *)

val division_crashes_on_overflow : bool

(* Operations on addressing modes *)

val identity_addressing : addressing_mode

val offset_addressing : addressing_mode -> int -> addressing_mode

val num_args_addressing : addressing_mode -> int

val box_addressing_mode : addressing_mode -> Operations.addressing_modes
val unbox_addressing_mode : Operations.addressing_modes -> addressing_mode

val box_specific_operation :
  specific_operation -> Operations.specific_operations
val unbox_specific_operation :
  Operations.specific_operations -> specific_operation

(* Printing operations and addressing modes *)

val is_logical_immediate : nativeint -> bool
