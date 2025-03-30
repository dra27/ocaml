(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*             Xavier Leroy, projet Cristal, INRIA Rocquencourt           *)
(*                                                                        *)
(*   Copyright 2000 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

(* Handling of sections in bytecode executable files *)

module Name = struct

  type raw_name = string

  type t =
    | CODE (** bytecode *)
    | CRCS (** crcs for modules *)
    | DATA (** global data (constant) *)
    | DBUG (** debug info *)
    | DLLS (** dll names *)
    | DLPT (** dll paths *)
    | OSLD (** OCaml Standard Library Default location *)
    | PRIM (** primitives names *)
    | RNTM (** The path to the bytecode interpreter (use_runtime mode) *)
    | SYMB (** global identifiers *)
    | Other of raw_name

  let of_string name =
    match name with
    | "CODE" -> CODE
    | "DLPT" -> DLPT
    | "DLLS" -> DLLS
    | "DATA" -> DATA
    | "OSLD" -> OSLD
    | "PRIM" -> PRIM
    | "SYMB" -> SYMB
    | "DBUG" -> DBUG
    | "CRCS" -> CRCS
    | "RNTM" -> RNTM
    | name   ->
        if String.length name <> 4 then
          invalid_arg "Bytesections.Name.of_string: must be of size 4";
        Other name

  let to_string = function
    | CODE -> "CODE"
    | DLPT -> "DLPT"
    | DLLS -> "DLLS"
    | DATA -> "DATA"
    | OSLD -> "OSLD"
    | PRIM -> "PRIM"
    | SYMB -> "SYMB"
    | DBUG -> "DBUG"
    | CRCS -> "CRCS"
    | RNTM -> "RNTM"
    | Other n -> n
end

type section_entry = {
  name : Name.t;
  pos  : int;
  len  : int;
}

type section_table = {
   sections : section_entry list;
   first_pos : int
}

(* Recording sections *)
type toc_writer = {
  (* List of all sections, in reverse order *)
  mutable section_table_rev : section_entry list;
  mutable section_prev : int;
  outchan : out_channel;
}

let init_record outchan : toc_writer =
  let pos = pos_out outchan in
  { section_prev = pos;
    section_table_rev = [];
    outchan }

let record t name =
  let pos = pos_out t.outchan in
  if pos < t.section_prev then
    invalid_arg "Bytesections.record: out_channel offset moved backward";
  let entry = {name; pos = t.section_prev; len = pos - t.section_prev} in
  t.section_table_rev <- entry :: t.section_table_rev;
  t.section_prev <- pos

let write_toc_and_trailer t =
  let section_table = List.rev t.section_table_rev in
  List.iter
    (fun {name; pos = _; len} ->
       let name = Name.to_string name in
       assert (String.length name = 4);
      output_string t.outchan name; output_binary_int t.outchan len)
    section_table;
  output_binary_int t.outchan (List.length section_table);
  output_string t.outchan Config.exec_magic_number

(* Read the table of sections from a bytecode executable *)

exception Bad_magic_number

let read_toc ic =
  let pos_trailer = in_channel_length ic - 16 in
  seek_in ic pos_trailer;
  let num_sections = input_binary_int ic in
  let header =
    really_input_string ic (String.length Config.exec_magic_number)
  in
  if header <> Config.exec_magic_number then raise Bad_magic_number;
  let toc_pos = pos_trailer - 8 * num_sections in
  seek_in ic toc_pos;
  let section_table_rev = ref [] in
  for _i = 1 to num_sections do
    let name = Name.of_string (really_input_string ic 4) in
    let len = input_binary_int ic in
    section_table_rev := (name, len) :: !section_table_rev
  done;
  let first_pos, sections =
    List.fold_left (fun (pos, l) (name, len) ->
        let section = {name; pos = pos - len; len} in
        (pos - len, section :: l)) (toc_pos, []) !section_table_rev
  in
  { sections; first_pos }

let all t = t.sections

let pos_first_section t = t.first_pos

let find_section t name =
  let rec find = function
    | [] -> raise Not_found
    | {name = n; pos; len} :: rest ->
        if n = name
        then pos, len
        else find rest
  in find t.sections

(* Position ic at the beginning of the section named "name",
   and return the length of that section.  Raise Not_found if no
   such section exists. *)

let seek_section t ic name =
  let pos, len = find_section t name in
  seek_in ic pos; len

(* Return the contents of a section, as a string *)

let read_section_string t ic name =
  really_input_string ic (seek_section t ic name)

(* Return the contents of a section, as marshalled data *)

let read_section_struct t ic name =
  ignore (seek_section t ic name);
  input_value ic

(* Reverses Filename.Unix.quote. *)
let dequote s =
  let l = String.length s - 1 in
  assert (l >= 1 && s.[0] = '\'' && s.[l] = '\'');
  let b = Buffer.create l in
  let rec loop s b i =
    if i = l then
      Buffer.contents b
    else
      let c = s.[i] in
      assert
        (c <> '\''
         || (i + 3 < l && s.[i+1] = '\\' && s.[i+2] = '\'' && s.[i+3] = '\''));
      Buffer.add_char b c;
      loop s b (i + if c = '\'' then 4 else 1)
  in
  loop s b 1

(* [dequote_between ~prefix ~suffix s] returns [Some (dequote s')] when [s] is
   [prefix ^ s' ^ suffix] (note that [s'] is therefore single-quoted) and [None]
   otherwise. *)
let dequote_between ~prefix ~suffix s =
  let s_len = String.length s in
  let prefix_len = String.length prefix in
  let suffix_len = String.length suffix in
  if String.starts_with ~prefix:(prefix ^ "'") s
     && String.ends_with ~suffix:("'" ^ suffix) s then
    Some (dequote (String.sub s prefix_len (s_len - prefix_len - suffix_len)))
  else
    None

(* Return the runtime used by this tendered/standalone image. Raise Not_found
   for an image compiled with -without-runtime. *)
let read_runtime t ic =
  seek_in ic 0;
  (* Check for a shebang line... *)
  if really_input_string ic 2 = "#!" then
    (* Read the interpreter string *)
    let shebang = String.trim (input_line ic) in
    (* If the interpreter is sh, parse the script *)
    if Filename.basename shebang = "sh" then
      let line = input_line ic in
      (* When the path to the runtime can't be directly used in a shebang, the
         shell is used instead, the next line is then:
           exec '<runtime>' "$0" "$@" *)
      match dequote_between ~prefix:{|exec |} ~suffix:{| "$0" "$@"|} line with
      | None ->
          Printf.ksprintf failwith "Unexpected exec line: %S" line
      | Some runtime ->
          runtime
    else
      (* Direct reference to ocamlrun ("#!/usr/bin/ocamlrun", etc.) *)
      shebang
  else
    (* ... otherwise look for an RNTM section (read_section_string will raise
       Not_found if there isn't one) *)
    let rntm = read_section_string t ic Name.RNTM in
    let len = String.length rntm in
    if len = 0 || rntm.[len - 1] <> '\000' then
      Printf.ksprintf failwith "Corrupt RNTM: %S" rntm;
    String.sub rntm 0 (len - 1)
