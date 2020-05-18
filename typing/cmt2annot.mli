(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*                   Fabrice Le Fessant, INRIA Saclay                     *)
(*                                                                        *)
(*   Copyright 2012 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

(** Generate an .annot file from a .cmt file. *)

val variables_iterator: Location.t -> Tast_iterator.iterator

val bind_variables: Location.t -> 'a Typedtree.general_pattern -> unit

val bind_bindings: Location.t -> Typedtree.value_binding list -> unit

val bind_cases: 'a Typedtree.case list -> unit

val record_module_binding: Location.t -> Typedtree.module_binding -> unit

val iterator: scope:Location.t -> bool -> Tast_iterator.iterator

val binary_part: Tast_iterator.iterator -> Cmt_format.binary_part -> unit

val gen_annot:
  string option -> sourcefile:string option -> use_summaries:bool ->
  Cmt_format.binary_annots -> unit
