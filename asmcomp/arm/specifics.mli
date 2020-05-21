(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*                 Benedikt Meurer, University of Siegen                  *)
(*                                                                        *)
(*   Copyright 1998 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*   Copyright 2012 Benedikt Meurer.                                      *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

(** Specific operations for the ARM processor *)

(* Addressing modes *)

type addressing_mode =
    Iindexed of int                     (** reg + displ *)

(* We do not support the reg + shifted reg addressing mode, because
   what we really need is reg + shifted reg + displ,
   and this is decomposed in two instructions (reg + shifted reg -> tmp,
   then addressing tmp + displ). *)

(* Specific operations *)

type specific_operation =
    Ishiftarith of arith_operation * shift_operation * int
  | Ishiftcheckbound of shift_operation * int
  | Irevsubimm of int
  | Imulhadd      (** multiply high and add *)
  | Imuladd       (** multiply and add *)
  | Imulsub       (** multiply and subtract *)
  | Inegmulf      (** floating-point negate and multiply *)
  | Imuladdf      (** floating-point multiply and add *)
  | Inegmuladdf   (** floating-point negate, multiply and add *)
  | Imulsubf      (** floating-point multiply and subtract *)
  | Inegmulsubf   (** floating-point negate, multiply and subtract *)
  | Isqrtf        (** floating-point square root *)
  | Ibswap of int (** endianness conversion *)

and arith_operation =
    Ishiftadd
  | Ishiftsub
  | Ishiftsubrev
  | Ishiftand
  | Ishiftor
  | Ishiftxor

and shift_operation =
    Ishiftlogicalleft
  | Ishiftlogicalright
  | Ishiftarithmeticright

type abi = EABI | EABI_HF
type arch = ARMv4 | ARMv5 | ARMv5TE | ARMv6 | ARMv6T2 | ARMv7 | ARMv8
type fpu = Soft | VFPv2 | VFPv3_D16 | VFPv3
