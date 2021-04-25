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

(** Internal compiler preprocessors.

  {b Warning:} this module is unstable and part of
  {{!Compiler_libs}compiler-libs}.

*)

val stdlib_aliases : unit -> Ast_mapper.mapper
(** Handles the stdlib__ prefixing in stdlib.ml and stdlib.mli *)

val labelled_since : unit -> Ast_mapper.mapper
