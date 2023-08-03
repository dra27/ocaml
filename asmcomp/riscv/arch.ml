# 2 "asmcomp/riscv/arch.ml"
(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*                Nicolas Ojeda Bar <n.oje.bar@gmail.com>                 *)
(*                                                                        *)
(*   Copyright 2016 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

include Operations.Riscv

(* Specific operations for the RISC-V processor *)

(* Machine-specific command-line options *)

let command_line_options = []

let is_immediate n =
  (n <= 0x7FF) && (n >= -0x800)

(* Sizes, endianness *)

let big_endian = false

let size_addr = 8
let size_int = size_addr
let size_float = 8

let allow_unaligned_access = false

(* Behavior of division *)

let division_crashes_on_overflow = false

(* Operations on addressing modes *)

let identity_addressing = Iindexed 0

let offset_addressing addr delta =
  match addr with
  | Iindexed n -> Iindexed(n + delta)

let num_args_addressing = function
  | Iindexed _ -> 1

(* Working around the lack of more exotic typing *)

let box_addressing_mode addressing_mode =
  (Riscv addressing_mode : Operations.addressing_modes)

let unbox_addressing_mode (addr : Operations.addressing_modes) =
  match addr with
  | Riscv addressing_mode -> addressing_mode
  | _ -> assert false

let box_specific_operation sop =
  (Riscv sop : Operations.specific_operations)

let unbox_specific_operation (sop : Operations.specific_operations) =
  match sop with
  | Riscv specific_operation -> specific_operation
  | _ -> assert false

(* Specific operations that are pure *)

let operation_is_pure _ = true

(* Specific operations that can raise *)

let operation_can_raise _ = false
