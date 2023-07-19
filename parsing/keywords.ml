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

let keyword_table =
  Misc.create_hashtable 149 [
    "and", ();
    "as", ();
    "assert", ();
    "begin", ();
    "class", ();
    "constraint", ();
    "do", ();
    "done", ();
    "downto", ();
    "else", ();
    "end", ();
    "exception", ();
    "external", ();
    "false", ();
    "for", ();
    "fun", ();
    "function", ();
    "functor", ();
    "if", ();
    "in", ();
    "include", ();
    "inherit", ();
    "initializer", ();
    "lazy", ();
    "let", ();
    "match", ();
    "method", ();
    "module", ();
    "mutable", ();
    "new", ();
    "nonrec", ();
    "object", ();
    "of", ();
    "open", ();
    "or", ();
    "private", ();
    "rec", ();
    "sig", ();
    "struct", ();
    "then", ();
    "to", ();
    "true", ();
    "try", ();
    "type", ();
    "val", ();
    "virtual", ();
    "when", ();
    "while", ();
    "with", ();

    "lor", ();
    "lxor", ();
    "mod", ();
    "land", ();
    "lsl", ();
    "lsr", ();
    "asr", ()
]

let is_keyword name = Hashtbl.mem keyword_table name
