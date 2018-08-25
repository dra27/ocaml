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

(** Bytecode compilation for .ml and .mli files. *)

val interface
  :  frontend:(Pparse.parse_intf_fun) option
  -> sourcefile:string
  -> outputprefix:string
  -> unit

val implementation
  :  frontend:(Pparse.parse_impl_fun) option
  -> sourcefile:string
  -> outputprefix:string
  -> unit
