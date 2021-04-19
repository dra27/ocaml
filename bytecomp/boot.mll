(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*                      Nicolas Ojeda Bar, LexiFi                         *)
(*                                                                        *)
(*   Copyright 2016 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

let ident = ['a'-'z''A'-'Z''_']['a'-'z''A'-'Z''0'-'9''_']*

rule find_exceptions = parse
| "/* \"" (ident as name) "\" */" '\r'* '\n'
    { name :: find_exceptions lexbuf}
| [^ '/' ]+ | '/'
    { find_exceptions lexbuf }
| eof
    { [] }

{
  let parse_fail file =
    let ch = open_in_bin file in
    let lexbuf = Lexing.from_channel ch in
    let results = find_exceptions lexbuf in
    close_in ch;
    results

  let output_builtin_exceptions ch names =
    output_string ch "let builtin_exceptions = [|\n";
    List.iter (Printf.fprintf ch "  %S;\n") names;
    output_string ch "|]\n"
}
