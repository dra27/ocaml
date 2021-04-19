(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*                 David Allsopp, OCaml Labs, Cambridge.                  *)
(*                                                                        *)
(*   Copyright 2021 David Allsopp Ltd.                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

val parse : string -> string * string list
(** [parse "path/to/caml/instruct.h"] parses instruct.h and returns the name of
    the enum and the list of opnames. *)

val output_opnames : out_channel -> string * string list -> unit
(** Write opnames.ml *)

val output_opcodes : out_channel -> string list -> unit
(* Write opcodes.ml *)
