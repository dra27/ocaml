(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*            Gabriel Scherer, projet Parsifal, INRIA Saclay              *)
(*                                                                        *)
(*   Copyright 2016 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

type native_obj_config = {
  flambda : bool;
}
let native_obj_config () = {
  flambda = Config_settings.flambda;
}

type version = int

type kind =
  | Exec
  | Cmi | Cmo | Cma
  | Cmx of native_obj_config | Cmxa of native_obj_config
  | Cmxs
  | Cmt
  | Ast_impl | Ast_intf

(* please keep up-to-date, this is used for sanity checking *)
let all_native_obj_configs = [
    {flambda = true};
    {flambda = false};
  ]
let all_kinds = [
  Exec;
  Cmi; Cmo; Cma;
]
@ List.map (fun conf -> Cmx conf) all_native_obj_configs
@ List.map (fun conf -> Cmxa conf) all_native_obj_configs
@ [
  Cmt;
  Ast_impl; Ast_intf;
]

type raw = string
type info = {
  kind: kind;
  version: version;
}

type raw_kind = string

let parse_kind : raw_kind -> kind option = function
  | "Caml1999X" -> Some Exec
  | "Caml1999I" -> Some Cmi
  | "Caml1999O" -> Some Cmo
  | "Caml1999A" -> Some Cma
  | "Caml1999y" -> Some (Cmx {flambda = true})
  | "Caml1999Y" -> Some (Cmx {flambda = false})
  | "Caml1999z" -> Some (Cmxa {flambda = true})
  | "Caml1999Z" -> Some (Cmxa {flambda = false})

  (* Caml2007D and Caml2012T were used instead of the common Caml1999 prefix
     between the introduction of those magic numbers and October 2017
     (8ba70ff194b66c0a50ffb97d41fe9c4bdf9362d6).

     We accept them here, but will always produce/show kind prefixes
     that follow the current convention, Caml1999{D,T}. *)
  | "Caml2007D" | "Caml1999D" -> Some Cmxs
  | "Caml2012T" | "Caml1999T" -> Some Cmt

  | "Caml1999M" -> Some Ast_impl
  | "Caml1999N" -> Some Ast_intf
  | _ -> None

(* note: over time the magic kind number has changed for certain kinds;
   this function returns them as they are produced by the current compiler,
   but [parse_kind] accepts older formats as well. *)
let raw_kind : kind -> raw = function
  | Exec -> "Caml1999X"
  | Cmi -> "Caml1999I"
  | Cmo -> "Caml1999O"
  | Cma -> "Caml1999A"
  | Cmx {flambda = true} -> "Caml1999y"
  | Cmx {flambda = false} -> "Caml1999Y"
  | Cmxa {flambda = true} -> "Caml1999z"
  | Cmxa {flambda = false} -> "Caml1999Z"
  | Cmxs -> "Caml1999D"
  | Cmt -> "Caml1999T"
  | Ast_impl -> "Caml1999M"
  | Ast_intf -> "Caml1999N"

let string_of_kind : kind -> string = function
  | Exec -> "exec"
  | Cmi -> "cmi"
  | Cmo -> "cmo"
  | Cma -> "cma"
  | Cmx _ -> "cmx"
  | Cmxa _ -> "cmxa"
  | Cmxs -> "cmxs"
  | Cmt -> "cmt"
  | Ast_impl -> "ast_impl"
  | Ast_intf -> "ast_intf"

let human_description_of_native_obj_config : native_obj_config -> string =
  fun[@warning "+9"] {flambda} ->
    if flambda then "flambda" else "non flambda"

let human_name_of_kind : kind -> string = function
  | Exec -> "executable"
  | Cmi -> "compiled interface file"
  | Cmo -> "bytecode object file"
  | Cma -> "bytecode library"
  | Cmx config ->
     Printf.sprintf "native compilation unit description (%s)"
       (human_description_of_native_obj_config config)
  | Cmxa config ->
     Printf.sprintf "static native library (%s)"
       (human_description_of_native_obj_config config)
  | Cmxs -> "dynamic native library"
  | Cmt -> "compiled typedtree file"
  | Ast_impl -> "serialized implementation AST"
  | Ast_intf -> "serialized interface AST"

let kind_length = 9
let version_length = 3
let magic_length =
  kind_length + version_length

type parse_error =
  | Truncated of string
  | Not_a_magic_number of string

let explain_parse_error kind_opt error =
     Printf.sprintf
       "We expected a valid %s, but the file %s."
       (Option.fold ~none:"object file" ~some:human_name_of_kind kind_opt)
       (match error with
          | Truncated "" -> "is empty"
          | Truncated _ -> "is truncated"
          | Not_a_magic_number _ -> "has a different format")

let parse s : (info, parse_error) result =
  if String.length s = magic_length then begin
    let raw_kind = String.sub s 0 kind_length in
    let raw_version = String.sub s kind_length version_length in
    match parse_kind raw_kind with
    | None -> Error (Not_a_magic_number s)
    | Some kind ->
        begin match int_of_string raw_version with
        | exception _ -> Error (Truncated s)
        | version -> Ok { kind; version }
        end
  end
  else begin
    (* a header is "truncated" if it starts like a valid magic number,
       that is if its longest segment of length at most [kind_length]
       is a prefix of [raw_kind kind] for some kind [kind] *)
    let sub_length = Int.min kind_length (String.length s) in
    let starts_as kind =
      String.sub s 0 sub_length = String.sub (raw_kind kind) 0 sub_length
    in
    if List.exists starts_as all_kinds then Error (Truncated s)
    else Error (Not_a_magic_number s)
  end

let read_info ic =
  let header = Buffer.create magic_length in
  begin
    try Buffer.add_channel header ic magic_length
    with End_of_file -> ()
  end;
  parse (Buffer.contents header)

let raw { kind; version; } =
  Printf.sprintf "%s%03d" (raw_kind kind) version

let current_raw kind =
  match[@warning "+9"] kind with
    | Exec -> Config_constants.exec_magic_number
    | Cmi -> Config_constants.cmi_magic_number
    | Cmo -> Config_constants.cmo_magic_number
    | Cma -> Config_constants.cma_magic_number
    | Cmx {flambda = true} -> Config_constants.cmx_magic_number_flambda
    | Cmx {flambda = false} -> Config_constants.cmx_magic_number_clambda
    | Cmxa {flambda = true} -> Config_constants.cmxa_magic_number_flambda
    | Cmxa {flambda = false} -> Config_constants.cmxa_magic_number_clambda
    | Cmxs -> Config_constants.cmxs_magic_number
    | Cmt -> Config_constants.cmt_magic_number
    | Ast_intf -> Config_constants.ast_intf_magic_number
    | Ast_impl -> Config_constants.ast_impl_magic_number

(* it would seem more direct to define current_version with the
   correct numbers and current_raw on top of it, but for now we
   consider the Config_settings.foo values to be ground truth, and don't want
   to trust the present module instead. *)
let current_version kind =
  let raw = current_raw kind in
  try int_of_string (String.sub raw kind_length version_length)
  with _ -> assert false

type 'a unexpected = { expected : 'a; actual : 'a }
type unexpected_error =
  | Kind of kind unexpected
  | Version of kind * version unexpected

let explain_unexpected_error = function
  | Kind { actual; expected } ->
      Printf.sprintf "We expected a %s (%s) but got a %s (%s) instead."
        (human_name_of_kind expected) (string_of_kind expected)
        (human_name_of_kind actual) (string_of_kind actual)
  | Version (kind, { actual; expected }) ->
      Printf.sprintf "This seems to be a %s (%s) for %s version of OCaml."
        (human_name_of_kind kind) (string_of_kind kind)
        (if actual < expected then "an older" else "a newer")

let check_current expected_kind { kind; version } : _ result =
  if kind <> expected_kind then begin
    let actual, expected = kind, expected_kind in
    Error (Kind { actual; expected })
  end else begin
    let actual, expected = version, current_version kind in
    if actual <> expected
    then Error (Version (kind, { actual; expected }))
    else Ok ()
  end

type error =
  | Parse_error of parse_error
  | Unexpected_error of unexpected_error

let read_current_info ~expected_kind ic =
  match read_info ic with
    | Error err -> Error (Parse_error err)
    | Ok info ->
       let kind = Option.value ~default:info.kind expected_kind in
       match check_current kind info with
         | Error err -> Error (Unexpected_error err)
         | Ok () -> Ok info
