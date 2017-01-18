(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*           David Allsopp, OCaml Labs, University of Cambridge           *)
(*                                                                        *)
(*   Copyright 2017 MetaStack Solutions Ltd.                              *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

{
module Types = struct
  type t =
    Section of string
  | Breaking
  | Blank
  | Change of bool * string list
  | Underlining of int
  | Heading of string
  | Corrupt of string
  | EOF

  type tag_type =
    BadTag
  | GPR
  | MPR

  let string_of_tag_type = function
    BadTag -> "feature"
  | GPR -> "gpr"
  | MPR -> "pr"

  let tag_type_of_string = function
    "feature" -> BadTag
  | "gpr" -> GPR
  | "pr" -> MPR
  | _ -> invalid_arg "tag_type_of_string"
end

open Types

(* This string should be exactly the same as in the Breaking regexp below *)
let breaking_message =
  "(Changes that can break existing programs are marked with a \"*\")"

let current_line lexbuf =
  Lexing.(lexbuf.lex_curr_p.pos_lnum)

let new_line lexbuf v =
  let v = (current_line lexbuf, v) in
  Lexing.new_line lexbuf;
  v
}

let eol = "\r\n"
let to_eol = [^ '\r' ]+

rule get_token = parse
  "### " (to_eol as section) eol
   {Section section |> new_line lexbuf}
  (* This string should be exactly the same as [breaking_message] above *)
| "(Changes that can break existing programs are marked with a \"*\")" eol
   {Breaking |> new_line lexbuf}
| eol
   {Blank |> new_line lexbuf}
| ([ '-' '*' ] as kind) ' ' (to_eol as line)
   {lex_change (kind = '*') (current_line lexbuf) [line] lexbuf}
| ('-'+ as line) eol
   {Underlining (String.length line) |> new_line lexbuf}
| ([ 'A'-'Z' ] to_eol as heading) eol
   {Heading heading |> new_line lexbuf}
| (to_eol as line)
   {lex_corrupt (Corrupt line) lexbuf}
| eof
   {(current_line lexbuf, EOF)}
and lex_corrupt v = parse
  eol
   {v |> new_line lexbuf}
and lex_change kind n buf = parse
  eol "  " (to_eol as line)
   {Lexing.new_line lexbuf;
    lex_change kind n (line::buf) lexbuf}
| eol
   {Lexing.new_line lexbuf;
    (n, Change (kind, List.rev buf))}

and parse_tag = parse
  ([ 'g' 'G' 'm' 'M' ]? as gpr) (([ 'p' 'P' ][ 'r' 'R' ] '#') as prefix)
    ([ '1'-'9' ][ '0'-'9' ]* as n) eof
   {if String.lowercase_ascii gpr <> "g" then
      ((MPR, int_of_string n), (gpr <> "" || prefix <> "PR#"))
    else
      ((GPR, int_of_string n), (gpr <> "G" || prefix <> "PR#"))}
| _*
   {((BadTag, 0), false)}

{
let uint_of_string s = Scanf.sscanf s "%u%!" (fun x -> x)

let warning_new_n warnings old ws n w =
  if old then
    ws
  else
    warnings ws n w

let standard_warning = function
  `LongLine l -> Printf.sprintf "Line too long (%d chars)" l
| `WhitespaceEnd -> "Illegal whitespace at end of line"
| `ReviewersNewLine -> "The reviewers section should begin on a new line"
| `ReviewersSpace -> "Expect exactly one space at the start of a reviewers line"
| `WhitespaceStart -> "Unexpected whitespace at beginning of line"
| `NoAuthor -> "Change appears not to have an author"
| `ReviewersUnopened ->
    "The reviewers section doesn't appear to have been opened \
     (left parenthesis missing)"
| `ColonSpace -> "Colon should be followed by space"
| `BadTag tag -> Printf.sprintf "Tag %s not recognised" tag
| `CorruptTags -> "Corrupt tag set"
| `CommaSpace -> "Comma should be followed by space"
| `GPRsAscending -> "GPRs should be numbered in ascending numerical order"
| `GPRsAfterPRs -> "GPRs should appear after PRs"
| `MPRsAscending -> "MPRs should be numbered in ascending numerical order"
| `Untagged -> "Change appears to be untagged"
| `TagNaming (given, correct) ->
    Printf.sprintf "Tag %s should be %s" given correct
| `BlankLine -> "Unexpected blank line"
| `Tabs -> "Tab characters are not permitted"

let validate_change_entry old warnings ws n change =
  let warning_n = warnings in
  let warning ws w = warnings ws n w in
  let warning_new_n ws = warning_new_n warnings old ws in
  let warning_new ws w = warning_new_n ws n w in
  let check_spaces (n, a, ws) line =
    let l = String.length line in
    let (line, ws) =
      if String.contains line '\t' then
        let line = String.map (function '\t' -> ' ' | c -> c) line in
        (line, warning_n ws n `Tabs)
      else
        (line, ws) in
    let ws =
      if l > 78 then
        warning_n ws n (`LongLine l)
      else if l = 0 then
        warning_n ws n `BlankLine
      else if line.[pred l] = ' ' then
        warning_n ws n `WhitespaceEnd
      else
        ws in
   (succ n, line::a, ws)
  in
    let ws =
      let (n', change, ws) = List.fold_left check_spaces (n, [], ws) change in
      let n' = pred n' in
      let check_whitespace (gathering_authors, n, ws) line =
        let l = String.length line in
        let (gathering_authors, ws) =
          if gathering_authors then
            match String.index line '(' with
              i ->
                let ws =
                  if i <> 0 then
                    warning_new_n ws n `ReviewersNewLine
                  else
                    ws in
                (false, ws)
            | exception Not_found ->
                let ws =
                  if l < 2 || line.[0] <> ' ' || line.[1] = ' ' then
                    warning_n ws n `ReviewersSpace
                  else
                    ws in
                (true, ws)
          else
            (false, ws)
        in
        let ws =
          if l > 0 && not gathering_authors && line.[0] = ' ' then
            warning_new_n ws n `WhitespaceStart
          else
            ws in
        (gathering_authors, pred n, ws)
      in
      match change with
        line::rest ->
          let l = String.length line in
          if l = 0 || line.[l |> pred] <> ')' then
            let (_, _, ws) =
              let acc = (false, n', warning_new ws `NoAuthor) in
              List.fold_left check_whitespace acc change
            in
            ws
          else begin
            match String.rindex line '(' with
              i ->
                let ws =
                  if i > 0 then
                    warning_new_n ws n `ReviewersNewLine
                  else ws in
                let (_, _, ws) =
                  List.fold_left check_whitespace (false, pred n', ws) rest in
                ws
            | exception Not_found ->
                let (still_gathering, _, ws) =
                  List.fold_left check_whitespace (true, n', ws) change in
                if still_gathering then
                  warning ws `ReviewersUnopened
                else
                  ws
          end
      | [] ->
          assert false
    in
      let head = List.hd change in
      match String.index head ':' with
        i ->
          let tags = String.sub head 0 i in
          let ws =
            let l = String.length head in
            if l = i + 1 then
              ws
            else
              if head.[i + 1] <> ' ' || i + 2 < l && head.[i + 2] = ' ' then
                warning_new ws `ColonSpace
              else
                ws in
          let check_tag ws a tag =
            let (((tag_type, n') as tag'), pedantically_wrong) =
              parse_tag (Lexing.from_string tag) in
            if tag_type = BadTag then
              (a, warning_new ws (`BadTag tag))
            else
              let ws =
                if pedantically_wrong then
                  let w =
                    let correct_tag =
                      String.uppercase_ascii (string_of_tag_type tag_type)
                        ^ "#" ^ string_of_int n'
                    in
                    `TagNaming (tag, correct_tag)
                  in
                  warning ws w
                else ws
              in
              (tag'::a, ws) in
          let rec find_tags n (a, ws) =
            match String.index_from tags n ',' with
              i ->
                let (n', ws) =
                  if String.length tags < i + 2 then
                    (succ i, warning ws `CorruptTags)
                  else if head.[succ i] = ' ' then
                    (i + 2, ws)
                  else
                    (succ i, warning ws `CommaSpace)
                in
                  String.sub tags n (i - n) |> check_tag ws a |> find_tags n'
            | exception Not_found ->
                String.sub head n (String.length tags - n) |> check_tag ws a
          in
            (* Validate that the tags are in order *)
            let check_tag (gpr, idx, _, current_bet, ws) tag =
              match tag with
                (GPR, n) ->
                  if gpr then
                    if n < idx then
                      (gpr, n, tag, tag, ws)
                    else
                      (gpr, idx, tag, current_bet, warning ws `GPRsAscending)
                  else
                    (gpr, idx, tag, current_bet, warning ws `GPRsAfterPRs)
              | (MPR, n) ->
                  let idx =
                    if gpr then
                      max_int
                    else
                      idx
                  in
                  if n < idx then
                    (false, n, tag, tag, ws)
                  else
                    (false, idx, tag, current_bet, warning ws `MPRsAscending)
              | (BadTag, _) ->
                  assert false
            in
              let (l, ws) = find_tags 0 ([], ws) in
              let (_, _, _, tag, ws) =
                let acc = (true, max_int, (BadTag, 0), (BadTag, 0), ws) in
                List.fold_left check_tag acc l in
              (tag, ws)
      | exception Not_found ->
          ((BadTag, 0), warning_new ws `Untagged)
}
