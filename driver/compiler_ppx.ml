(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*                 David Allsopp, OCaml Labs, Cambridge.                  *)
(*                                                                        *)
(*   Copyright 2021 David Allsopp Ltd.                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

open Asttypes
open Parsetree
open Ast_mapper

let mk_canonical ~loc name =
  let open Ast_helper in
  let expr =
    Exp.mk (Pexp_constant (Pconst_string ("@canonical " ^ name, loc, None)))
  in
  let payload =
    Str.mk ~loc (Pstr_eval (expr, []))
  in
  Attr.mk ~loc (Location.mknoloc "ocaml.doc") (PStr [payload])

let stdlib_aliases () =
  let prefix_aliases = ref false in
  let signature_item mapper item =
    match item with
    | {psig_desc =
        Psig_module
          ({pmd_name = {txt = Some name};
            pmd_type =
              ({pmty_desc =
                  Pmty_alias
                    ({txt = Lident ident} as alias)} as type_)} as decl)}
      when !prefix_aliases && name = ident ->
        let pmd_type =
          let pmty_desc =
            Pmty_alias {alias with txt = Lident ("Stdlib__" ^ name)}
          in
          {type_ with pmty_desc}
        and pmd_attributes =
          (mk_canonical ~loc:decl.pmd_name.loc name)::decl.pmd_attributes
        in
        {item with psig_desc = Psig_module {decl with pmd_type; pmd_attributes}}

    | {psig_desc =
        Psig_extension
          ((({txt = "ocaml.stdlib_aliases"} as attr_name), PStr []), _)} ->
          prefix_aliases := true;
          {item with psig_desc =
            Psig_attribute {attr_name;
                            attr_payload = PStr [];
                            attr_loc = attr_name.loc}}

    | _ ->
        default_mapper.signature_item mapper item
  and structure_item mapper item =
    match item with
    | {pstr_desc =
        Pstr_module
          ({pmb_name = {txt = Some name};
            pmb_expr =
              ({pmod_desc =
                  Pmod_ident
                    ({txt = Lident ident} as alias)} as type_)} as decl)}
      when !prefix_aliases && name = ident ->
        let pmb_expr =
          let pmod_desc =
            Pmod_ident {alias with txt = Lident ("Stdlib__" ^ name)}
          in
          {type_ with pmod_desc}
        and pmb_attributes =
          (mk_canonical ~loc:decl.pmb_name.loc name)::decl.pmb_attributes
        in
        {item with pstr_desc = Pstr_module {decl with pmb_expr; pmb_attributes}}

    | {pstr_desc =
        Pstr_extension
          ((({txt = "ocaml.stdlib_aliases"} as attr_name), PStr []), _)} ->
          prefix_aliases := true;
          {item with pstr_desc =
            Pstr_attribute {attr_name;
                            attr_payload = PStr [];
                            attr_loc = attr_name.loc}}

    | _ ->
        default_mapper.structure_item mapper item
  in
    {default_mapper with signature_item; structure_item}

(* Search [s] for [/@since [^ ]+ (\([^ ]+\) in [^ ]+Labels)/] and replace with
   ["@since \1"] - e.g. ["@since 4.06.0 (4.12.0 in UnixLabels)"] becomes
   ["@since 4.12.0"] *)
let transform_at_since s =
  let len = String.length s in
  let module String = struct
    include String
    let index_from_result s i c =
      match String.index_from s i c with
      | j -> Ok j
      | exception Not_found -> Error len
    let rindex_from_result s i c =
      match String.rindex_from s i c with
      | j -> Ok j
      | exception Not_found -> Error len
  end in
  let (let*) = Result.bind in
  let rec loop i =
    if i < len then
      let step =
        (* Find an '@' *)
        let* at = String.index_from_result s i '@' in
        (* Test for "@since " *)
        let* start =
          if at + 30 < len && String.sub s at 7 = "@since " then
            Ok (at + 7)
          else
            Error (at + 7)
        in
        (* Find ')' *)
        let* rparen_index = String.index_from_result s start ')' in
        (* Check previous EOL was before start *)
        let* () =
          match String.rindex_from_opt s rparen_index '\n' with
          | Some index when index > index ->
              Error len
          | _ ->
              Ok ()
        in
        (* Find previous '(' *)
        let* lparen_index = String.rindex_from_result s rparen_index '(' in
        (* Check ' ' before '(' *)
        let* () = if s.[lparen_index - 1] = ' ' then Ok () else Error len in
        let last_space_index = String.rindex_from s rparen_index ' ' in
        (* Check "@since [^ ]+ ([^ ]* in [^ ]*Labels)" *)
        if String.index_from s start ' ' = lparen_index - 1
           && String.sub s (rparen_index - 6) 6 = "Labels"
           && String.sub s (last_space_index - 3) 4 = " in "
           && String.rindex_from s (last_space_index - 4) ' ' = lparen_index - 1
        then
          let prefix = String.sub s 0 start in
          let version =
            String.sub s (lparen_index + 1)
                         (last_space_index - lparen_index - 4)
          in
          let suffix =
            String.sub s (rparen_index + 1) (len - rparen_index - 1)
          in
          Ok (prefix ^ version ^ suffix)
        else
          Error len
      in
        match step with
        | Ok s -> s
        | Error i -> loop i
    else
      s
  in
  loop 0

let labelled_since () =
  let signature_item mapper item =
    match item with
    | {psig_desc =
        Psig_value
          ({pval_attributes =
             [{attr_name = {txt = "ocaml.doc"};
               attr_payload = PStr
                 [({pstr_desc = Pstr_eval
                   (({pexp_desc = Pexp_constant (Pconst_string (s, loc, None))}
                         as expr), attrs)} as payload)]} as attr]} as value)} ->
         let transform = transform_at_since s in
         if transform <> s then
           let expr =
             {expr with pexp_desc =
               Pexp_constant (Pconst_string (transform, loc, None))}
           in
           let payload = {payload with pstr_desc = Pstr_eval (expr, attrs)} in
           {item with psig_desc =
             Psig_value {value with pval_attributes =
               [{attr with attr_payload = PStr [payload]}]}}
         else
           default_mapper.signature_item mapper item
    | _ ->
        default_mapper.signature_item mapper item
  in
    {default_mapper with signature_item}
