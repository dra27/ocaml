# 2 "asmcomp/s390x/arch.mli"
(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*            Xavier Leroy, projet Gallium, INRIA Rocquencourt            *)
(*                          Bill O'Farrell, IBM                           *)
(*                                                                        *)
(*   Copyright 2015 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*   Copyright 2015 IBM (Bill O'Farrell with help from Tristan Amini).    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

include module type of struct include Operations.S390x end

(* Specific operations for the Z processor *)

(* Machine-specific command-line options *)

val pic_code : bool ref

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

(* Specific operations that are pure *)

val operation_is_pure : specific_operation -> bool

(* Specific operations that can raise *)

val operation_can_raise : specific_operation -> bool
