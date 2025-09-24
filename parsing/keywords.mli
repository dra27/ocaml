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

val init : (int*int) option * string list -> unit

val is_keyword : string -> bool

val token_of_string : string -> Keywords_token.token option

(** Comment tracking *)

val add_comment : (string * Location.t) -> unit
(** Add a comment to the list of saved comments *)

val add_docstring_comment : Docstrings.docstring -> unit
(** Convert a docstring to a comment and add it to the list *)

val comments : unit -> (string * Location.t) list
(** Get all saved comments in order *)

val reset_comments : unit -> unit
(** Clear the comment list *)
