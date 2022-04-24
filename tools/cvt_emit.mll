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

{
let first_item = ref false
let lexeme_beginning = ref 0

let add_semicolon () =
  if !first_item
  then first_item := false
  else print_string "; "

let print_unescaped_string s =
  let l = String.length s in
  let i = ref 0 in
  while !i < l do
    if s.[!i] = '\\'
    && !i+1 < l
    && (let c = s.[!i+1] in c = '{' || c = '`') (* ` *)
    then i := !i+1;
    print_char s.[!i];
    i := !i + 1
  done
}

rule main = parse
    "`" { lexeme_beginning := Lexing.lexeme_start lexbuf;
          first_item := true;
          print_char '(';
          command lexbuf;
          print_char ')';
          main lexbuf }
  | "\\`"
        { print_string "`"; main lexbuf }
  | '\t' { prerr_char '[';
           prerr_int lexbuf.Lexing.lex_curr_p.Lexing.pos_lnum;
           prerr_endline "]: Tabs not allowed outside `...` blocks";
           exit 2 }
  | '"' { lexeme_beginning := Lexing.lexeme_start lexbuf;
          print_char '"';
          string lexbuf }
  | eof { () }
  | _   { let c = Lexing.lexeme_char lexbuf 0 in
          if c = '\n' then
            Lexing.new_line lexbuf;
          print_char c; main lexbuf }

and command = parse
    "`" { () }
  | eof { prerr_string "Unterminated `...` at character ";
          prerr_int !lexeme_beginning;
          prerr_newline();
          exit 2 }
  | "{" [^ '}'] * "}"
        { let s = Lexing.lexeme lexbuf in
          add_semicolon();
          print_string (String.sub s 1 (String.length s - 2));
          command lexbuf }
  | '\\' ('\n' | "\r\n")
        { Lexing.new_line lexbuf;
          add_semicolon();
          print_string "emit_string \"\\\n\"";
          command lexbuf
          }
  | ( [^ '`' '{' '\\'] |
      '\\' ['\\' '"' 'n' 't' 'b' 'r' '`' '{' ] |
      '\\' ['0'-'9'] ['0'-'9'] ['0'-'9'] ) +
        { let s = Lexing.lexeme lexbuf in
          add_semicolon();
          (* Optimise one-character strings *)
          if String.length s = 1 && s.[0] <> '\\' && s.[0] <> '\''
          || String.length s = 2 && s.[0] = '\\' && s.[1] <> '`' && s.[1]<>'{'
          (* ` *)
          then begin
            print_string "emit_char '";
            print_unescaped_string s;
            print_string "'"
          end else begin
            print_string "emit_string \"";
            print_unescaped_string s;
            print_string "\""
          end;
          command lexbuf }

and string = parse
  | '"' { print_char '"';
          main lexbuf }
  | '\\' ('\n' | "\r\n")
        { Lexing.new_line lexbuf;
          print_string "\\\n";
          string lexbuf }
  | '\\' _ | [^ '\\' '"' ]+
        { print_string (Lexing.lexeme lexbuf);
          string lexbuf }
  | eof { prerr_string "Unterminated \"...\" at character ";
          prerr_int !lexeme_beginning;
          prerr_newline();
          exit 2 }

{
let _ =
  let open Lexing in
  let lexbuf = from_channel stdin in
  lexbuf.lex_curr_p <- {lexbuf.lex_curr_p with pos_lnum = 1};
  main lexbuf

let _ = exit (0)
}
