(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*             Xavier Leroy, projet Cristal, INRIA Rocquencourt           *)
(*                                                                        *)
(*   Copyright 2000 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

(** Specific operations for the AMD64 processor *)

type addressing_mode =
    Ibased of string * int              (** symbol + displ *)
  | Iindexed of int                     (** reg + displ *)
  | Iindexed2 of int                    (** reg + reg + displ *)
  | Iscaled of int * int                (** reg * scale + displ *)
  | Iindexed2scaled of int * int        (** reg + reg * scale + displ *)

type specific_operation =
    Ilea of addressing_mode             (** "lea" gives scaled adds *)
  | Istore_int of nativeint * addressing_mode * bool
                                        (** Store an integer constant *)
  | Ioffset_loc of int * addressing_mode (** Add a constant to a location *)
  | Ifloatarithmem of float_operation * addressing_mode
                                        (** Float arith operation with memory *)
  | Ibswap of int                       (** endianness conversion *)
  | Isqrtf                              (** Float square root *)
  | Ifloatsqrtf of addressing_mode      (** Float square root from memory *)
  | Isextend32                          (** 32 to 64 bit conversion with sign
                                            extension *)
  | Izextend32                          (** 32 to 64 bit conversion with zero
                                            extension *)
and float_operation = Ifloatadd | Ifloatsub | Ifloatmul | Ifloatdiv
