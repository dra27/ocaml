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

and find_exceptions = parse
| "/* \"" (ident as name) "\" */" '\r'* '\n'
    { name :: find_exceptions lexbuf}
| [^ '/' ]+ | '/'
    { find_exceptions lexbuf }
| eof
    { [] }

and read_lines = parse
| ([^ '\r' '\n' ]* as line) '\r'* '\n'?
    { line :: read_lines lexbuf }
| eof
    { [] }

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

  let read_lines file =
    let ch = open_in_bin file in
    let lexbuf = Lexing.from_channel ch in
    let results = read_lines lexbuf in
    close_in ch;
    results

  let output_stdlib_modules ch modules =
    (*
     * This file must be self-contained.
     *
     * This file lists all standard library modules. It is used by:
     * 1. stdlib/Makefile when building stdlib.cma
     * 2. Makefile to expunge the toplevels
     * 3. api_docgen/Makefile.docfiles to compute all documentation files which
     *    need to be generated for the stdlib
     *
     * Three variables are exported:
     * $(STDLIB_MODULE_BASENAMES) - basenames, in dependency order, of the
     *    modules in the stdlib
     * $(STDLIB_PREFIXED_MODULES) - just the namespaced modules of
     *    $(STDLIB_MODULE_BASENAMES), i.e. without camlinternal* and stdlib.
     *    Used in stdlib/Makefile to munge the dependencies.
     * $(STDLIB_MODULES) - full list, in prefixed form as appropriate.
     *)
  let prefix = "stdlib__" in
  let prefix_len = String.length prefix in
  let (stdlib_module_basenames, stdlib_prefixed_modules) =
    let f name (stdlib_module_basenames, stdlib_prefixed_modules) =
      if String.starts_with ~prefix name then
        let basename =
          String.sub name prefix_len (String.length name - prefix_len)
            |> String.uncapitalize_ascii
        in
          (basename::stdlib_module_basenames, basename::stdlib_prefixed_modules)
      else
        (name::stdlib_module_basenames, stdlib_prefixed_modules)
    in
      List.fold_right f modules ([], [])
  in
    Printf.fprintf ch "STDLIB_MODULE_BASENAMES =\\\n\
                      \  %s\n\
                       STDLIB_PREFIXED_MODULES = \\\n\
                      \  %s\n\
                       STDLIB_MODULES = \\\n\
                      \  %s\n"
                        (String.concat " \\\n  " stdlib_module_basenames)
                        (String.concat " \\\n  " stdlib_prefixed_modules)
                        (String.concat " \\\n  " modules)
}
