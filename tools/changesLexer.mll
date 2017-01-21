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

  (* The order of these tags matters (BadTag > GPR > MPR) *)
  type tag_type =
    MPR
  | GPR
  | BadTag

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
  let rtrim s =
    let rec f i =
      if s.[i] = ' ' then
        if i = 0 then
          0
        else
          f (pred i)
      else
        succ i
    in
    let l = String.length s in
    if l = 0 then
      ""
    else
      let i = f (pred l) in
      if i <> l then
        String.sub s 0 i
      else
        s
  in
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
      else ws in
    let (a, ws) =
      let trimmed = rtrim line in
      if l = 0 || trimmed = "" then
        (a, warning_n ws n `BlankLine)
      else if line.[pred l] = ' ' then
        (trimmed::a, warning_n ws n `WhitespaceEnd)
      else
        (line::a, ws) in
   (succ n, a, ws)
  in
    let (ws, change) =
      let (n', change, ws) = List.fold_left check_spaces (n, [], ws) change in
      let n' = pred n' in
      let check_whitespace (gathering_authors, n, ws, a) line =
        let l = String.length line in
        let (gathering_authors, ws, line, a) =
          if gathering_authors then
            match String.index line '(' with
              i ->
                if i <> 0 then
                  let reviewer_line =
                    String.sub line i (String.length line - i)
                  in
                  let line = String.sub line 0 i |> rtrim in
                  if line = "" then
                    let ws = warning_new_n ws n `ReviewersNewLine in
                    (false, ws, reviewer_line, a)
                  else
                    let ws = warning_new_n ws n `ReviewersNewLine in
                    (false, ws, line, reviewer_line::a)
                else
                  (false, ws, line, a)
            | exception Not_found ->
                if l < 2 || line.[0] <> ' ' || line.[1] = ' ' then
                  let ws = warning_n ws n `ReviewersSpace in
                  (true, ws, " " ^ String.trim line, a)
                else
                  (true, ws, line, a)
          else
            (false, ws, line, a)
        in
        let (ws, a) =
          if l > 0 && not gathering_authors && line.[0] = ' ' then
            (warning_new_n ws n `WhitespaceStart, line::a)
          else
            (ws, line::a) in
        (gathering_authors, pred n, ws, a)
      in
      match change with
        line::rest ->
          let l = String.length line in
          if l = 0 || line.[l |> pred] <> ')' then
            let (_, _, ws, change) =
              let acc = (false, n', warning_new ws `NoAuthor, []) in
              List.fold_left check_whitespace acc change in
            (ws, change)
          else begin
            match String.rindex line '(' with
              i ->
                let (ws, rest, a) =
                  if i > 0 then
                    let rest =
                      let line = String.sub line 0 i |> rtrim in
                      if line = "" then
                        rest
                      else
                        line::rest
                    in
                    let ws = warning_new_n ws n `ReviewersNewLine in
                    (ws, rest, [String.sub line i (String.length line - i)])
                  else (ws, rest, [line]) in
                let (_, _, ws, change) =
                  let acc = (false, pred n', ws, a) in
                  List.fold_left check_whitespace acc rest in
                (ws, change)
            | exception Not_found ->
                let (still_gathering, _, ws, change) =
                  List.fold_left check_whitespace (true, n', ws, []) change in
                let ws =
                  if still_gathering then
                    warning ws `ReviewersUnopened
                  else
                    ws
                in
                (ws, change)
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
          let check_tag ws a sortable tag =
            let (((tag_type, n') as tag'), pedantically_wrong) =
              parse_tag (Lexing.from_string tag) in
            if tag_type = BadTag then
              (a, warning_new ws (`BadTag tag), false)
            else
              let ws =
                if pedantically_wrong then
                  let w =
                    let correct_tag =
                      String.uppercase_ascii (string_of_tag_type tag_type) ^
                        "#" ^ string_of_int n'
                    in
                    `TagNaming (tag, correct_tag)
                  in
                  warning ws w
                else ws
              in
              (tag'::a, ws, sortable) in
          let rec find_tags n (a, ws, sortable) =
            match String.index_from tags n ',' with
              i ->
                let (n', ws, sortable) =
                  if String.length tags < i + 2 then
                    (succ i, warning ws `CorruptTags, false)
                  else if head.[succ i] = ' ' then
                    (i + 2, ws, sortable)
                  else
                    (succ i, warning ws `CommaSpace, sortable)
                in
                  String.sub tags n (i - n)
                    |> check_tag ws a sortable
                    |> find_tags n'
            | exception Not_found ->
                String.sub head n (String.length tags - n)
                  |> check_tag ws a sortable
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
              let (tags, ws, sortable) = find_tags 0 ([], ws, true) in
              let (_, _, _, tag, ws) =
                let acc = (true, max_int, (BadTag, 0), (BadTag, 0), ws) in
                List.fold_left check_tag acc tags in
              let change =
                if sortable then
                  let head =
                    String.sub head (i + 1) (String.length head - i - 1)
                      |> String.trim
                  in
                  let tags =
                    let f (tag, n) =
                      let tag =
                        string_of_tag_type tag |> String.uppercase_ascii
                      in
                      tag ^ "#" ^ string_of_int n
                    in
                    (List.map f (List.sort compare tags))
                  in
                  let head =
                    let padding =
                      if head = "" then
                        ""
                      else
                        " "
                    in
                    (String.concat ", " tags ^ ":" ^ padding ^ head)
                  in
                  head::(List.tl change)
                else
                  change in
              (tag, ws, change)
      | exception Not_found ->
          ((BadTag, 0), warning_new ws `Untagged, change)
}
