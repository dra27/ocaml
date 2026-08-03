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

(* The table of keywords *)

open Keywords_token

let keyword_table = Hashtbl.create 149

let all_keywords =
  let v5_3 = Some (5,3) in
  let v1_0 = Some (1,0) in
  let v1_6 = Some (1,6) in
  let v4_2 = Some (4,2) in
  let always = None in
  [
    "and", AND, always;
    "as", AS, always;
    "assert", ASSERT, v1_6;
    "begin", BEGIN, always;
    "class", CLASS, v1_0;
    "constraint", CONSTRAINT, v1_0;
    "do", DO, always;
    "done", DONE, always;
    "downto", DOWNTO, always;
    "effect", EFFECT, v5_3;
    "else", ELSE, always;
    "end", END, always;
    "exception", EXCEPTION, always;
    "external", EXTERNAL, always;
    "false", FALSE, always;
    "for", FOR, always;
    "fun", FUN, always;
    "function", FUNCTION, always;
    "functor", FUNCTOR, always;
    "if", IF, always;
    "in", IN, always;
    "include", INCLUDE, always;
    "inherit", INHERIT, v1_0;
    "initializer", INITIALIZER, v1_0;
    "lazy", LAZY, v1_6;
    "let", LET, always;
    "match", MATCH, always;
    "method", METHOD, v1_0;
    "module", MODULE, always;
    "mutable", MUTABLE, always;
    "new", NEW, v1_0;
    "nonrec", NONREC, v4_2;
    "object", OBJECT, v1_0;
    "of", OF, always;
    "open", OPEN, always;
    "or", OR, always;
(*  "parser", PARSER; *)
    "private", PRIVATE, v1_0;
    "rec", REC, always;
    "sig", SIG, always;
    "struct", STRUCT, always;
    "then", THEN, always;
    "to", TO, always;
    "true", TRUE, always;
    "try", TRY, always;
    "type", TYPE, always;
    "val", VAL, always;
    "virtual", VIRTUAL, v1_0;
    "when", WHEN, always;
    "while", WHILE, always;
    "with", WITH, always;

    "lor", INFIXOP3("lor"), always; (* Should be INFIXOP2 *)
    "lxor", INFIXOP3("lxor"), always; (* Should be INFIXOP2 *)
    "mod", INFIXOP3("mod"), always;
    "land", INFIXOP3("land"), always;
    "lsl", INFIXOP4("lsl"), always;
    "lsr", INFIXOP4("lsr"), always;
    "asr", INFIXOP4("asr"), always
]

let init (version,keywords) =
  let greater (x:(int*int) option) (y:(int*int) option) =
    match x, y with
    | None, _ | _, None -> true
    | Some x, Some y -> x >= y
  in
  let tbl = keyword_table in
  Hashtbl.clear tbl;
  let add_keyword (name, token, since) =
    if greater version since then Hashtbl.replace tbl name (Some token)
  in
  List.iter add_keyword all_keywords;
  List.iter (fun name ->
    match List.find (fun (n,_,_) -> n = name) all_keywords with
    | (_,tok,_) -> Hashtbl.replace tbl name (Some tok)
    | exception Not_found -> Hashtbl.replace tbl name None
    ) keywords

let is_keyword = Hashtbl.mem keyword_table

let token_of_string = Hashtbl.find keyword_table
