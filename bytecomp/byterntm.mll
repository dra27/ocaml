(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*            David Allsopp, University of Cambridge & Tarides            *)
(*                                                                        *)
(*   Copyright 2025 David Allsopp Ltd.                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

{
(* XXX Get this working first, but it's tempting to do this with a lexer too?? *)

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

let parse_runtime_id name =
  let len = String.length name in
  let id =
    if len < 6 || name.[len - 5] <> '-' then
      None
    else
      Misc.RuntimeID.of_string (String.sub name (len - 4) 4)
  in
  if id = None then
    name, id
  else
    String.sub name 0 (len - 5), id

let parse_absolute name =
  let basename = Filename.basename name in
  let dir = String.sub name 0 (String.length name - String.length basename) in
  let name, runtime_id = parse_runtime_id basename in
  name, Some (dir, runtime_id), None

let parse_search bin z runtime last valid invalid =
  let open Option.Syntax in
  let+ runtime, id, ids =
    match last with
    | Some last ->
        Some (runtime ^ String.make 1 last, None, None)
    | None ->
        let* runtime, id =
          let len = String.length runtime in
          if len < 4 || runtime.[len - 4] <> '-' then
            None
          else
            Some (String.sub runtime 0 (len - 4),
                  String.sub runtime (len - 3) 3)
        in
        let apply c acc =
          let+ id = Misc.RuntimeID.of_string (id ^ String.make 1 c)
          and+ acc in
          id::acc
        in
        let apply v = String.fold_right apply (Option.get v) (Some []) in
        let+ valid = apply valid
        and+ invalid = apply invalid
        in
        runtime, Some id, Some (valid, invalid)
  in
  match bin with
  | Some bin ->
      let id =
        let* id and* z in
        Misc.RuntimeID.of_string (id ^ String.make 1 z)
      in
      runtime, Some (bin, id), ids
  | None ->
      runtime, None, ids
}

rule analyze = parse
  | "#!" [^ ' ' '\n']+ "/sh\n"
      { analyze_sh_launcher lexbuf }

  | "#!" ([^ ' ' '\n']+ as runtime) '\n' | ([^ '\000']+ as runtime) '\000'? eof
      { Some (parse_absolute runtime) }

  | (([^ '\000']+ as bin '\000' ([^ '\000']+ as runtime) ([^ '\000'] as z))
       | ('\000' ([^ '\000']+ as runtime))) '\000'
    (_ as last | ([^ '\000']+ as valid '\000' ([^ '\000']* as invalid))) eof
      { parse_search bin z runtime last valid invalid }

  | _ | eof
      { None }

and analyze_sh_launcher = parse
  | "exec " ([^ '\n']+ as runtime) "\"$0\" \"$@\"\n"
      { Some (parse_absolute (dequote runtime)) }

  |  "r=" ([^ '\n']+ as runtime) '\n'
    ("c=" ([^ '\n']+ as bin) "\"$r\"" ('"' ("'" as z) '"' | "'" ([^ '\''] as z) "'")
      '\n'
     [^ '\n']+ '\n' (* if ! test -f "$c"; then *))?
     [^ '\n']+ '\n' (* d="$(dirname "$0" 2>/dev/null)" *)
     [^ '\n']+ '\n' (* test -z "$d" || d="${d%/}/" *)
     "for z in "
       ('\'' ('"' as last) '\'' | "'" ([^ '\''] as last) "'"
         | ([^ ' ']+ as valid ' ' ([^ ';']* as invalid))) "; do\n"
      { parse_search bin z (dequote runtime) last valid invalid }

  | _ | eof
      { None }

{
let read_runtime t ic =
  seek_in ic 0;
  let lexbuf =
    try
      if really_input_string ic 2 = "#!" then
        let () = seek_in ic 0 in
        Some (Lexing.from_channel ic)
      else
        let rntm = Bytesections.(read_section_string t ic Name.RNTM) in
        Some (Lexing.from_string rntm)
    with End_of_file | Not_found -> None
  in
  Option.bind lexbuf analyze
}
