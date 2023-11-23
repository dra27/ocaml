# 2 "asmcomp/arm64/arch.ml"
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

include Operations.Arm64

(* Specific operations for the ARM processor, 64-bit mode *)

let macosx = (Config.system = "macosx")

(* Machine-specific command-line options *)

let command_line_options = []

(* Sizes, endianness *)

let big_endian = false

let size_addr = 8
let size_int = 8
let size_float = 8

let allow_unaligned_access = false

(* Behavior of division *)

let division_crashes_on_overflow = false

(* Operations on addressing modes *)

let identity_addressing = Iindexed 0

let offset_addressing addr delta =
  match addr with
  | Iindexed n -> Iindexed(n + delta)
  | Ibased(s, n) -> Ibased(s, n + delta)

let num_args_addressing = function
  | Iindexed _ -> 1
  | Ibased _ -> 0

(* Working around the lack of more exotic typing *)

let box_addressing_mode addressing_mode =
  (Arm64 addressing_mode : Operations.addressing_modes)

let unbox_addressing_mode (addr : Operations.addressing_modes) =
  match addr with
  | Arm64 addressing_mode -> addressing_mode
  | _ -> assert false

let box_specific_operation sop =
  (Arm64 sop : Operations.specific_operations)

let unbox_specific_operation (sop : Operations.specific_operations) =
  match sop with
  | Arm64 specific_operation -> specific_operation
  | _ -> assert false

(* Recognition of logical immediate arguments *)

(* An automaton to recognize ( 0+1+0* | 1+0+1* )

               0          1          0
              / \        / \        / \
              \ /        \ /        \ /
        -0--> [1] --1--> [2] --0--> [3]
       /
     [0]
       \
        -1--> [4] --0--> [5] --1--> [6]
              / \        / \        / \
              \ /        \ /        \ /
               1          0          1

The accepting states are 2, 3, 5 and 6. *)

let auto_table = [|   (* accepting?, next on 0, next on 1 *)
  (* state 0 *) (false, 1, 4);
  (* state 1 *) (false, 1, 2);
  (* state 2 *) (true,  3, 2);
  (* state 3 *) (true,  3, 7);
  (* state 4 *) (false, 5, 4);
  (* state 5 *) (true,  5, 6);
  (* state 6 *) (true,  7, 6);
  (* state 7 *) (false, 7, 7)   (* error state *)
|]

let rec run_automata nbits state input =
  let (acc, next0, next1) = auto_table.(state) in
  if nbits <= 0
  then acc
  else run_automata (nbits - 1)
                    (if Nativeint.logand input 1n = 0n then next0 else next1)
                    (Nativeint.shift_right_logical input 1)

(* The following function determines a length [e]
   such that [x] is a repetition [BB...B] of a bit pattern [B] of length [e].
   [e] ranges over 64, 32, 16, 8, 4, 2.  The smaller [e] the better. *)

let logical_imm_length x =
  (* [test n] checks that the low [2n] bits of [x] are of the
     form [BB], that is, two occurrences of the same [n] bits *)
  let test n =
    let mask = Nativeint.(sub (shift_left 1n n) 1n) in
    let low_n_bits = Nativeint.(logand x mask) in
    let next_n_bits = Nativeint.(logand (shift_right_logical x n) mask) in
    low_n_bits = next_n_bits in
  (* If [test n] fails, we know that the length [e] is
     at least [2n].  Hence we test with decreasing values of [n]:
     32, 16, 8, 4, 2. *)
  if not (test 32) then 64
  else if not (test 16) then 32
  else if not (test 8) then 16
  else if not (test 4) then 8
  else if not (test 2) then 4
  else 2

(* A valid logical immediate is
- neither [0] nor [-1];
- composed of a repetition [BBBBB] of a bit-pattern [B] of length [e]
- the low [e] bits of the number, that is, [B], match [0+1+0*] or [1+0+1*].
*)

let is_logical_immediate x =
  x <> 0n && x <> -1n && run_automata (logical_imm_length x) 0 x
