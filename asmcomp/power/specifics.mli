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

(** Specific operations for the PowerPC processor *)

(* Specific operations *)

type specific_operation =
    Imultaddf                           (** multiply and add *)
  | Imultsubf                           (** multiply and subtract *)
  | Ialloc_far of
      { bytes : int; label_after_call_gc : int (*Cmm.label*) option;
        dbginfo : Debuginfo.alloc_dbginfo }
                                        (** allocation in large functions *)

(* Addressing modes *)

type addressing_mode =
    Ibased of string * int              (** symbol + displ *)
  | Iindexed of int                     (** reg + displ *)
  | Iindexed2                           (** reg + reg *)

type abi = ELF32 | ELF64v1 | ELF64v2
