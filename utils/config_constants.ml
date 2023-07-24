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

(* Constants which used to be housed in Config. This module, as hinted by its
   name, should contain only constants, and these constants should not be
   controlled by configure.

   If anything in this file is changed, a bootstrap is required. *)

let exec_magic_number = "Caml1999X033"
    (* exec_magic_number is duplicated in runtime/caml/exec.h *)
and cmi_magic_number = "Caml1999I033"
and cmo_magic_number = "Caml1999O033"
and cma_magic_number = "Caml1999A033"
and cmx_magic_number_flambda = "Caml1999y033"
and cmxa_magic_number_flambda = "Caml1999z033"
and cmx_magic_number_clambda = "Caml1999Y033"
and cmxa_magic_number_clambda = "Caml1999Z033"
and ast_impl_magic_number = "Caml1999M033"
and ast_intf_magic_number = "Caml1999N033"
and cmxs_magic_number = "Caml1999D033"
and cmt_magic_number = "Caml1999T033"
and linear_magic_number = "Caml1999L033"

let max_tag = 243
(* This is normally the same as in obj.ml, but we have to define it
   separately because it can differ when we're in the middle of a
   bootstrapping phase. *)
let lazy_tag = 246

let max_young_wosize = 256
let stack_threshold = 32 (* Stack_threshold_words in runtime/caml/config.h *)
let stack_safety_margin = 6

module System = struct
  type t =
  | S_unknown
  | S_linux | S_gnu
  | S_dragonfly | S_freebsd | S_netbsd | S_openbsd
  | S_macosx | S_solaris | S_beos | S_cygwin
  | S_mingw | S_mingw64 | S_win32 | S_win64

  let to_string = function
  | S_unknown -> "unknown"
  | S_linux -> "linux"
  | S_gnu -> "gnu"
  | S_dragonfly -> "dragonfly"
  | S_freebsd -> "freebsd"
  | S_netbsd -> "netbsd"
  | S_openbsd -> "openbsd"
  | S_macosx -> "macosx"
  | S_solaris -> "solaris"
  | S_beos -> "beos"
  | S_cygwin -> "cygwin"
  | S_mingw -> "mingw"
  | S_mingw64 -> "mingw64"
  | S_win32 -> "win32"
  | S_win64 -> "win64"

  let is_windows = function
  | S_mingw64 | S_mingw | S_cygwin | S_win64 | S_win32 -> true
  | _ -> false

  let is_macOS = function
  | S_macosx -> true
  | _ -> false

  let is_solaris = function
  | S_solaris -> true
  | _ -> false

  let uses_masm = function
  | S_win32 | S_win64 -> true
  | _ -> false

  let is_bsd_system = function
  | S_netbsd | S_freebsd | S_openbsd -> true
  | _ -> false
end

let merlin = false
