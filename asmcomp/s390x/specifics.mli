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

(** Specific operations for the Z processor *)

(* Specific operations *)

type specific_operation =
    Imultaddf                           (** multiply and add *)
  | Imultsubf                           (** multiply and subtract *)

(* Addressing modes *)

type addressing_mode =
  | Iindexed of int                     (** reg + displ *)
  | Iindexed2 of int                    (** reg + reg + displ *)
