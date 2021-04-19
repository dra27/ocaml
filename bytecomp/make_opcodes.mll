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
let space = [' ''\n''\r''\t']*

rule find_enum = parse
| "enum" space (ident as id) space '{' { id, opnames lexbuf }
| _                                    { find_enum lexbuf }

and opnames = parse
| space (ident as op) space ','        { op :: opnames lexbuf }
| space ident space '}'                { [] }

{
  let parse file =
    let ch = open_in_bin file in
    let lexbuf = Lexing.from_channel ch in
    let results = find_enum lexbuf in
    close_in ch;
    results

  let output_opnames ch (id, opnames) =
    Printf.fprintf ch "let names_of_%s = [|\n" id;
    List.iter (Printf.fprintf ch "  %S;\n") opnames;
    output_string ch "|]\n"

  let output_opcodes ch =
    List.iteri (fun i op -> Printf.fprintf ch "let op%s = %i\n" op i)
}
