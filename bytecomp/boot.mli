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

(** Boot utility functions. Functions embedded in boot/ocamlc and accessed via
    the [-bootstrap] option. *)

val parse_fail : string -> string list
(** [parse_fail "path/to/caml/fail.h"] parses fail.h and returns the list of
    predefined exceptions. *)

val output_builtin_exceptions : out_channel -> string list -> unit
(** Write the builtin_exceptions part of runtimedef.ml *)
