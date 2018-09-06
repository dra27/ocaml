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

(** Native compilation for .ml and .mli files. *)

val interface
  :  frontend:(Pparse.parse_intf_fun) option
  -> typing:Compile_common.typecheck_intf_fun option
  -> sourcefile:string
  -> outputprefix:string
  -> unit

val implementation
   :  frontend:(Pparse.parse_impl_fun) option
   -> typing:Compile_common.typecheck_impl_fun option
   -> backend:(module Backend_intf.S)
   -> sourcefile:string
   -> outputprefix:string
   -> unit

(** {2 Internal functions} **)

val clambda
  :  Compile_common.info
  -> Typedtree.structure * Typedtree.module_coercion
  -> Env.import_list
  -> unit
(** [clambda info typed] applies the regular compilation pipeline to the
    given typechecked implementation and outputs the resulting files.
*)

val flambda
  :  Compile_common.info
  -> (module Backend_intf.S)
  -> Typedtree.structure * Typedtree.module_coercion
  -> Env.import_list
  -> unit
(** [flambda info backend typed] applies the Flambda compilation pipeline to the
    given typechecked implementation and outputs the resulting files.
*)
