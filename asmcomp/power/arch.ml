# 2 "asmcomp/power/arch.ml"
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

include Operations.Power

(* Specific operations for the PowerPC processor *)

(* Machine-specific command-line options *)

let command_line_options = []

(* Sizes, endianness *)

let big_endian = false
let size_addr = 8
let size_int = size_addr
let size_float = 8

let allow_unaligned_access = true

(* Behavior of division *)

let division_crashes_on_overflow = true

(* Operations on addressing modes *)

let identity_addressing = Iindexed 0

let offset_addressing addr delta =
  match addr with
    Ibased(s, n) -> Ibased(s, n + delta)
  | Iindexed n -> Iindexed(n + delta)
  | Iindexed2 -> assert false

let num_args_addressing = function
    Ibased _ -> 0
  | Iindexed _ -> 1
  | Iindexed2 -> 2

(* Working around the lack of more exotic typing *)

let box_addressing_mode addressing_mode =
  (Power addressing_mode : Operations.addressing_modes)

let unbox_addressing_mode (addr : Operations.addressing_modes) =
  match addr with
  | Power addressing_mode -> addressing_mode
  | _ -> assert false

let box_specific_operation sop =
  (Power sop : Operations.specific_operations)

let unbox_specific_operation (sop : Operations.specific_operations) =
  match sop with
  | Power specific_operation -> specific_operation
  | _ -> assert false
