# 2 "asmcomp/s390x/arch.ml"
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

include Operations.S390x

(* Specific operations for the Z processor *)

(* Machine-specific command-line options *)

let pic_code = ref true

let command_line_options =
  [ "-fPIC", Arg.Set pic_code,
      " Generate position-independent machine code (default)";
    "-fno-PIC", Arg.Clear pic_code,
      " Generate position-dependent machine code" ]

(* Sizes, endianness *)

let big_endian = true

let size_addr = 8
let size_int = size_addr
let size_float = 8

let allow_unaligned_access = false

(* Behavior of division *)

let division_crashes_on_overflow = true

(* Operations on addressing modes *)

let identity_addressing = Iindexed 0

let offset_addressing addr delta =
  match addr with
  | Iindexed n -> Iindexed(n + delta)
  | Iindexed2 n -> Iindexed2(n + delta)

let num_args_addressing = function
  | Iindexed _ -> 1
  | Iindexed2 _ -> 2

(* Working around the lack of more exotic typing *)

let box_addressing_mode addressing_mode =
  (S390x addressing_mode : Operations.addressing_modes)

let unbox_addressing_mode (addr : Operations.addressing_modes) =
  match addr with
  | S390x addressing_mode -> addressing_mode
  | _ -> assert false

let box_specific_operation sop =
  (S390x sop : Operations.specific_operations)

let unbox_specific_operation (sop : Operations.specific_operations) =
  match sop with
  | S390x specific_operation -> specific_operation
  | _ -> assert false
