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

include Config_constants
include Config_settings

(* The main OCaml version string has moved to ../build-aux/ocaml_version.m4 *)
let version = Sys.ocaml_version

let standard_library = Misc.get_stdlib standard_library_default

(* #7678: ocamlopt uses these only to compile .c files, and the behaviour for
          the two drivers should be identical. *)
let ocamlopt_cflags = ocamlc_cflags
let ocamlopt_cppflags = ocamlc_cppflags

let cmx_magic_number =
  if flambda then
    cmx_magic_number_flambda
  else
    cmx_magic_number_clambda
and cmxa_magic_number =
  if flambda then
    cmxa_magic_number_flambda
  else
    cmxa_magic_number_clambda

let naked_pointers = false

let interface_suffix = Clflags.interface_suffix

let default_executable_name = Compenv.default_executable_name

let print_config = Compenv.print_config
let config_var = Compenv.config_var
