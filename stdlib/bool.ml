(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*                         The OCaml programmers                          *)
(*                                                                        *)
(*   Copyright 2018 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

type t = bool = false | true

external not : bool -> bool = "%boolnot"
external ( && ) : bool -> bool -> bool = "%sequand"
external ( || ) : bool -> bool -> bool = "%sequor"
external equal : bool -> bool -> bool = "%equal"
external compare : bool -> bool -> int = "%compare"
external to_int : bool -> int = "%identity"
let to_float = function false -> 0. | true -> 1.

(*
let of_string = function
| "false" -> Some false
| "true" -> Some true
| _ -> None
*)

let to_string = function false -> "false" | true -> "true"
