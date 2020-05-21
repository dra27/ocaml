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

(** Specific operations for the ARM processor, 64-bit mode *)

(* Addressing modes *)

type addressing_mode =
  | Iindexed of int                     (** reg + displ *)
  | Ibased of string * int              (** global var + displ *)

(* We do not support the reg + shifted reg addressing mode, because
   what we really need is reg + shifted reg + displ,
   and this is decomposed in two instructions (reg + shifted reg -> tmp,
   then addressing tmp + displ). *)

(* Specific operations *)

type cmm_label = int
  (* Do not introduce a dependency to Cmm *)

type specific_operation =
  | Ifar_alloc of { bytes : int; label_after_call_gc : cmm_label option;
                    dbginfo : Debuginfo.alloc_dbginfo }
  | Ifar_intop_checkbound of { label_after_error : cmm_label option; }
  | Ifar_intop_imm_checkbound of
      { bound : int; label_after_error : cmm_label option; }
  | Ishiftarith of arith_operation * int
  | Ishiftcheckbound of { shift : int; label_after_error : cmm_label option; }
  | Ifar_shiftcheckbound of
      { shift : int; label_after_error : cmm_label option; }
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
