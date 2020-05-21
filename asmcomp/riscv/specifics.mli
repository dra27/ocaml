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

(** Specific operations for the RISC-V processor *)

(* Specific operations *)

type specific_operation =
  | Imultaddf of bool        (** multiply, optionally negate, and add *)
  | Imultsubf of bool        (** multiply, optionally negate, and subtract *)

(* Addressing modes *)

type addressing_mode =
  | Iindexed of int                     (** reg + displ *)
