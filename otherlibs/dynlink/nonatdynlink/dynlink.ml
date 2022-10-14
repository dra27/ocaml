(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*                        David Allsopp, Tarides.                         *)
(*                                                                        *)
(*   Copyright 2022 David Allsopp Ltd.                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

(* Stubbed version of Dynlink for when natdynlink is not available/disabled. *)

module DT = Dynlink_types

type linking_error = DT.linking_error =
  | Undefined_global of string
  | Unavailable_primitive of string
  | Uninitialized_global of string

type error = DT.error =
  | Not_a_bytecode_file of string
  | Inconsistent_import of string
  | Unavailable_unit of string
  | Unsafe_file
  | Linking_error of string * linking_error
  | Corrupted_interface of string
  | Cannot_open_dynamic_library of exn
  | Library's_module_initializers_failed of exn
  | Inconsistent_implementation of string
  | Module_already_loaded of string
  | Private_library_cannot_implement_interface of string

exception Error = DT.Error

let is_native = true
let support = Unsupported
let adapt_filename f = Filename.chop_extension f ^ ".cmxs"

type[@ocaml.warning "-69"] global_map = {
  name : string;
  crc_intf : Digest.t option;
  crc_impl : Digest.t option;
  syms : string list
}

(* ndl_open is called only to obtain an exception *)
external ndl_open : string -> bool -> unit = "caml_natdynlink_open"
external ndl_getmap : unit -> global_map list = "caml_natdynlink_getmap"

let load global filename =
  try ignore (ndl_open filename global)
  with exn -> raise (Error (Cannot_open_dynamic_library exn))

let loadfile filename = load true filename
let loadfile_private filename = load false filename

let set_allowed_units _allowed_units = ()
let allow_only _units = ()
let prohibit _units = ()

let main_program_units = lazy (
  let initial_units = ndl_getmap () in
    let f comp_unit =
      Option.map (Fun.const comp_unit.name) comp_unit.crc_impl in
    List.filter_map f initial_units
)

let main_program_units () = Lazy.force main_program_units

let public_dynamically_loaded_units () = []
let all_units = main_program_units
let allow_unsafe_modules _b = ()

let unsafe_get_global_value ~bytecode_or_asm_symbol:_ = None

let error_message = DT.error_message
