(****************************************************************************)
(*                                                                          *)
(*                                   OCaml                                  *)
(*                                                                          *)
(*                            INRIA Rocquencourt                            *)
(*                                                                          *)
(*  Copyright  2006   Institut National de Recherche  en  Informatique et   *)
(*  en Automatique.  All rights reserved.  This file is distributed under   *)
(*  the terms of the GNU Library General Public License, with the special   *)
(*  exception on linking described in LICENSE at the top of the OCaml       *)
(*  source tree.                                                            *)
(*                                                                          *)
(****************************************************************************)

(* Authors:
 * - Daniel de Rauglaudre: initial version
 * - Nicolas Pouillard: refactoring
 *)


let slashify p =
  match Sys.os_type with
  | "Win32" ->
    let len = String.length p in
    let b = String.create len in
    for i = 0 to len - 1 do
      String.set b i (match p.[i] with
      | '\\' ->  '/'
      | x -> x )
    done;
    b
  | _ -> p

let ocaml_standard_library = slashify (Camlp4_import.Config.standard_library) ;;

let camlp4_standard_library =
  slashify (
    try
      let d = Sys.getenv "CAMLP4LIB" in
      if Sys.is_directory d then
        d
      else
        raise Not_found
    with _ ->
      Filename.concat ocaml_standard_library "camlp4"
  );;

let version = Sys.ocaml_version;;
let program_name = ref "camlp4";;
let constructors_arity = ref true;;
let unsafe             = ref false;;
let verbose            = ref false;;
let antiquotations     = ref false;;
let quotations         = ref true;;
let inter_phrases      = ref None;;
let camlp4_ast_impl_magic_number = "Camlp42006M002";;
let camlp4_ast_intf_magic_number = "Camlp42006N002";;
let ocaml_ast_intf_magic_number = Camlp4_import.Config.ast_intf_magic_number;;
let ocaml_ast_impl_magic_number = Camlp4_import.Config.ast_impl_magic_number;;
let current_input_file = ref "";;
