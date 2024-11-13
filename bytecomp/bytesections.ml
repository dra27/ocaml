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

(* List of all sections, in reverse order *)

let section_table = ref ([] : (string * int) list)

(* Recording sections *)

let section_beginning = ref 0

let init_record outchan =
  section_beginning := pos_out outchan;
  section_table := []

let record outchan name =
  let pos = pos_out outchan in
  section_table := (name, pos - !section_beginning) :: !section_table;
  section_beginning := pos

let write_toc_and_trailer outchan =
  List.iter
    (fun (name, len) ->
      output_string outchan name; output_binary_int outchan len)
    (List.rev !section_table);
  output_binary_int outchan (List.length !section_table);
  output_string outchan Config.exec_magic_number;
  section_table := [];

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
  seek_in ic (pos_trailer - 8 * num_sections);
  section_table := [];
  for _i = 1 to num_sections do
    let name = really_input_string ic 4 in
    let len = input_binary_int ic in
    section_table := (name, len) :: !section_table
  done

(* Return the current table of contents *)

let toc () = List.rev !section_table

(* Position ic at the beginning of the section named "name",
   and return the length of that section.  Raise Not_found if no
   such section exists. *)

let seek_section ic name =
  let rec seek_sec curr_ofs = function
    [] -> raise Not_found
  | (n, len) :: rem ->
      if n = name
      then begin seek_in ic (curr_ofs - len); len end
      else seek_sec (curr_ofs - len) rem in
  seek_sec (in_channel_length ic - 16 - 8 * List.length !section_table)
           !section_table

(* Return the contents of a section, as a string *)

let read_section_string ic name =
  really_input_string ic (seek_section ic name)

(* Return the contents of a section, as marshalled data *)

let read_section_struct ic name =
  ignore (seek_section ic name);
  input_value ic

(* Return the position of the beginning of the first section *)

let pos_first_section ic =
  in_channel_length ic - 16 - 8 * List.length !section_table -
  List.fold_left (fun total (_name, len) -> total + len) 0 !section_table

let reset () =
  section_table := [];
  section_beginning := 0

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

let cut_path name =
  let basename = Filename.basename name in
  String.sub name 0 (String.length name - String.length basename), basename

type search_mode =
| Absolute of string
| Absolute_then_search of string
| Search

(* Return the runtime used by this tendered/standalone image. Raise Not_found
   for an image compiled with -without-runtime. *)
let read_runtime ic =
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
      | Some runtime ->
          let dir, runtime = cut_path runtime in
          runtime, Absolute dir
      | None ->
          (* Both -runtime-search enable and -runtime-search always add a
             variable r containing the name of the runtime. *)
          match dequote_between ~prefix:{|r=|} ~suffix:{||} line with
          | None ->
              Printf.ksprintf failwith "Unexpected sh line: %S" line
          | Some runtime ->
              (* -runtime-search enable also adds a variable c containing the
                 default path to be tried. *)
              let line = input_line ic in
              match dequote_between ~prefix:{|c=|} ~suffix:{|"$r"|} line with
              | Some dir ->
                  runtime, Absolute_then_search dir
              | None ->
                  runtime, Search
    else
      (* Direct reference to ocamlrun ("#!/usr/bin/ocamlrun", etc.) *)
      let dir, runtime = cut_path shebang in
      runtime, Absolute dir
  else
    (* ... otherwise look for an RNTM section (read_section_string will raise
       Not_found if there isn't one) *)
    let rntm = read_section_string ic "RNTM" in
    let len = String.length rntm in
    if len = 0 then
      Printf.ksprintf failwith "Corrupt RNTM: %S" rntm;
    try
      let dir, name = Misc.cut_at rntm '\000' in
      if name = "" then
        if Sys.win32 then
          dir, Search
        else
          let dir, runtime = cut_path dir in
          runtime, Absolute dir
      else
        if dir = "" then
          name, Search
        else
          name, Absolute_then_search (dir ^ Filename.dir_sep)
    with Not_found ->
      let dir, runtime = cut_path rntm in
      runtime, Absolute dir
