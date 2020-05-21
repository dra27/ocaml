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

(** Specific operations for the Intel 386 processor *)

type addressing_mode =
    Ibased of string * int              (** symbol + displ *)
  | Iindexed of int                     (** reg + displ *)
  | Iindexed2 of int                    (** reg + reg + displ *)
  | Iscaled of int * int                (** reg * scale + displ *)
  | Iindexed2scaled of int * int        (** reg + reg * scale + displ *)

type specific_operation =
    Ilea of addressing_mode             (** Lea gives scaled adds *)
  | Istore_int of nativeint * addressing_mode * bool
                                        (** Store an integer constant *)
  | Istore_symbol of string * addressing_mode * bool (* Store a symbol *)
  | Ioffset_loc of int * addressing_mode (** Add a constant to a location *)
  | Ipush                               (** Push regs on stack *)
  | Ipush_int of nativeint              (** Push an integer constant *)
  | Ipush_symbol of string              (** Push a symbol *)
  | Ipush_load of addressing_mode       (** Load a scalar and push *)
  | Ipush_load_float of addressing_mode (** Load a float and push *)
  | Isubfrev | Idivfrev                 (** Reversed float sub and div *)
  | Ifloatarithmem of bool * float_operation * addressing_mode
                                        (** Float arith operation with memory
                                            bool: true=64 bits, false=32 *)
  | Ifloatspecial of string

and float_operation =
    Ifloatadd | Ifloatsub | Ifloatsubrev | Ifloatmul | Ifloatdiv | Ifloatdivrev
