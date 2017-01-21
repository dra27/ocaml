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

open ChangesLexer.Types

let fold_tokens warnings warnings_acc g acc l =
  let rec f ws acc state old =
    let (n, token) = ChangesLexer.get_token l in
    let warning ws fmt = Printf.ksprintf (warnings ws n) fmt in
    let (token, state, ws) =
      if token = Heading "OCaml 3.12.1 (4 Jul 2011):" then
        let ws =
          if match state with `Changes (`Running _) -> false | _ -> true then
            warning ws "Unexpected heading"
          else
            ws in
        (EOF, `Blank (`Changes `Start), ws)
      else
        (token, state, ws) in
    let (state, ws) =
      match token with
        EOF ->
          let ws =
            if match state with `Blank (`Changes _) -> false | _ -> true then
              warning ws "Unexpected end-of-file"
            else
              ws in
          (state, ws)
      | Section section ->
          let ws =
            match state with
              `Changes _ | `Section | `Breaking | `Release ->
              ws
            | _ ->
              warning ws "Unexpected section" in
          let ws =
            if section = "" || section.[String.length section - 1] <> ':' then
              warning ws "Corrupt section: %s" section
            else
              ws in
          (`Blank (`Changes `Start), ws)
      | Breaking ->
          let ws =
            if state <> `Breaking then
              warning ws "Unexpected breaking changes warning"
            else
              ws in
          (`Blank `Release, ws)
      | Blank ->
          let state =
            match state with
              `Blank state ->
                (state, ws)
            | _ ->
                (state, warning ws "Unexpected blank line")
          in
            state
      | Change (_, change) ->
          let (tag, ws, _) =
            let warn ws n w =
              warnings ws n (ChangesLexer.standard_warning w)
            in
            ChangesLexer.validate_change_entry old warn ws n change
          in
            let (state, ws) =
              match state with
                `Blank _ ->
                  (`Changes (`Running tag), warning ws "A blank line was expected; not a change entry")
              | `Changes `Start
              | `Release ->
                  (`Changes (`Running tag), ws)
              | `Changes (`Running tag') ->
                  begin
                    match (tag, tag') with
                      ((MPR, n), (MPR, n'))
                    | ((GPR, n), (GPR, n')) ->
                        let ws =
                          if n < n' then
                            warning ws "Change doesn't appear to be in the correct place"
                          else
                            ws in
                        (`Changes (`Running tag), ws)
                    | ((MPR, _), (BadTag, _))
                    | ((GPR, _), (BadTag, _)) ->
                        (`Changes (`Running tag), warning ws "Assuming previous change was an addendum of some kind")
                    | ((BadTag, _), (MPR, _))
                    | ((BadTag, _), (GPR, _))
                    | ((BadTag, _), (BadTag, _))
                    | ((GPR, _), (MPR, _)) ->
                        (`Changes (`Running tag), ws)
                    | ((MPR, _), (GPR, _)) ->
                        (`Changes (`Running tag), warning ws "MPRs should be listed before GPRs")
                  end
              | _ ->
                  (`Changes (`Running tag), warning ws "Unexpected change entry")
            in
              (`Blank state, ws)
      | Underlining l ->
          let (l', ws) =
            match state with
              `Heading l ->
                (l, ws)
            | _ ->
                (l, warning ws "Unexpected underlining")
          in
            let ws =
              if l <> l' then
                warning ws "Incorrect number of hyphens (%d given; %d expected)" l' l
              else
                ws in
            (`Blank `Breaking, ws)
      | Heading heading ->
          let ws =
            if match state with `Changes (`Running _) -> false | _ -> true then
              warning ws "Unexpected heading"
            else
              ws in
          (`Heading (String.length heading), ws)
      | Corrupt line ->
          (state, warning ws "Corrupt line: %s" line)
    in
      let acc = g ws acc n token in
      if token <> EOF
      then f ws acc state (old || token = Heading "OCaml 4.01.0 (12 Sep 2013):")
      else acc
  in
    f warnings_acc acc (`Changes (`Running (BadTag, 0))) false

let changes_to_directory root =
  let table =
    let sections = [
      ("Bug fixes", "bugs");
      ("Compiler distribution build system", "build");
      ("Code generation and optimizations", "codegen");
      ("Compiler user-interface and warnings", "compilers");
      ("Internal/compiler-libs changes", "internals");
      ("Toplevel, debugger and profiler", "debugging");
      ("Feature wishes", "features");
      ("Installation procedure", "install");
      ("Language features", "language");
      ("Manual and documentation", "manual");
      ("Other libraries", "otherlibs");
      ("Shedding weight", "pruning");
      ("Runtime system", "runtime");
      ("Standard library", "stdlib");
      ("Tools", "tools");
      ("Type system", "typing")]
    and table = Hashtbl.create 32 in
    List.iter (fun (k, v) -> Hashtbl.add table (k ^ ":") v) sections;
    table
  and replaced_sections =
    let sections = [
      ("Native-code compiler", "codegen");
      ("Compilers", "compilers");
      ("Internals", "internals")]
    in
    List.rev_map (fun (k, v) -> (k ^ ":", v)) sections
  and isnt_attributable_string s =
    (* Using String.escaped is an admittedly hacky way of detecting
       UTF-8/non-ASCII *)
    let s = String.escaped s
    in
    List.fold_left (fun a c -> a || String.contains s c) false ['+'; '\\']
  in
  let explode root c _ ((before_4_04, state) as acc) _ = function
    EOF ->
      let _ =
        match state with
        | None ->
            ()
        | Some (attributes, state) ->
            close_out attributes;
            match state with
              Some (attributes, _, _, _) ->
                close_out attributes
            | None ->
                ()
      in
      close_in c;
      acc
  | Heading heading ->
      let before_4_04 =
        if heading = "OCaml 4.03.0 (25 Apr 2016):" then
          let f _ (k, v) = Hashtbl.add table k v = () in
          List.fold_left f true replaced_sections
        else
          before_4_04
      in
      let state =
        let dir =
          if String.length heading < 12 then
            ""
          else
            match String.sub heading 0 5 with
              "OCaml" ->
                String.sub heading 6 6
            | "Next " ->
                if heading.[5] = 'm' then
                  "next-minor"
                else
                  "next"
            | _ ->
                "" in
        let version attributes =
          if dir = "" then begin
            Printf.eprintf "Skipping unrecognised version %s\n%!" heading;
            None
          end else begin
            if isnt_attributable_string heading then
              assert false;
            let title =
              let f = function ' ' -> '+' | c -> c in
              String.map f (String.sub heading 0 (String.length heading - 1))
            in
            Printf.fprintf attributes "%s ocaml-changes-title=%s\n" dir title;
            let full_dir = Filename.concat root dir in
            if Sys.file_exists full_dir |> not then
              Unix.mkdir full_dir 0o775;
            let attributes =
              Filename.concat full_dir ".gitattributes" |> open_out
            in
            Some (attributes, dir, full_dir, Some (full_dir, 1, [], ""))
          end
        in
        match state with
          Some (attributes, Some (version_attributes, _, _, _)) ->
            close_out version_attributes;
            Some (attributes, version attributes)
        | Some (attributes, None) ->
            Some (attributes, version attributes)
        | None ->
            if dir <> "" then
              let attributes =
                Filename.concat root ".gitattributes"
                |> open_out_gen [Open_append; Open_creat; Open_text] 0o664
              in
              Some (attributes, version attributes)
            else
              None
      in
        (before_4_04, state)
  | Section section ->
      begin
        match state with
          None
        | Some (_, None) ->
            acc
        | Some (attributes, Some (version_attributes, version, version_dir, _)) ->
            begin
              match Hashtbl.find table section with
                name ->
                  if isnt_attributable_string section then
                    assert false;
                  let title =
                    let f = function ' ' -> '+' | c -> c in
                    String.map f (String.sub section 0 (String.length section - 1))
                  in
                  Printf.fprintf version_attributes "%s ocaml-changes-title=%s\n" name title;
                  let dir = Filename.concat version_dir name in
                  if Sys.file_exists dir |> not then
                    Unix.mkdir dir 0o755;
                  let name = Filename.concat version_dir name in
                  let state =
                    (attributes, Some (version_attributes, version, version_dir, Some (name, 1, [], "")))
                  in
                  (before_4_04, Some state)
              | exception Not_found ->
                  Printf.eprintf "Warning: skipping unrecognised section %s\n%!" section;
                  (before_4_04, Some (attributes, Some (version_attributes, version, version_dir, None)))
            end
      end
  | Change (breaking, change) ->
      begin
        match state with
          None
        | Some (_, None)
        | Some (_, Some (_, _, _, None)) ->
            acc
        | Some (attributes,
                Some (version_attributes, version, version_dir, Some (section_dir, feature, renames, prefix))) ->
            let (tag_type, n) =
              let tag = List.hd change in
              let tag =
                match String.index tag ':' with
                  i ->
                    begin
                      let tag = String.sub tag 0 i in
                      match String.index tag ',' with
                        i ->
                          String.sub tag 0 i
                      | exception Not_found ->
                          tag
                    end
                | exception Not_found ->
                    ""
              in
                match ChangesLexer.parse_tag (Lexing.from_string tag) with
                  ((BadTag, _), _)
                | (_, true) ->
                    (BadTag, feature)
                | (((GPR, _) as tag), false)
                | (((MPR, _) as tag), false) ->
                    tag
            in
            let (file, feature, renames, prefix) =
              let i = string_of_int n in
              let file = string_of_tag_type tag_type ^ "#" ^ i
                         |> Filename.concat section_dir
              in
              if tag_type = BadTag then
                let feature = succ feature in
                if prefix = "" then
                  (file, feature, renames, prefix)
                else
                  (file, feature, (file, prefix ^ i)::renames, prefix)
              else begin
                let rename (from_name, to_name) =
                  Sys.rename from_name to_name
                in
                List.iter rename renames;
                let prefix' = file ^ "-" in
                if prefix' = prefix then
                  (prefix ^ string_of_int feature, succ feature, [], prefix)
                else
                  (file, 1, [], prefix')
              end
            in
            let c = open_out_bin file in
            if breaking then
              output_char c '*';
            output_string c (String.concat "\r\n" change);
            close_out c;
            let state = (section_dir, feature, renames, prefix) in
            (before_4_04, Some (attributes, Some (version_attributes, version, version_dir, Some state)))
      end
  | Breaking
  | Underlining _
  | Corrupt _
  | Blank ->
      acc
  in
  explode root

let cat_changes c _ _ _ = function
  EOF ->
    close_in c
| Section section ->
    Printf.printf "### %s\n" section
| Breaking ->
    Printf.printf "%s\n" ChangesLexer.breaking_message
| Blank ->
    Printf.printf "\n"
| Change (breaking, change) ->
    Printf.printf "%c %s\n" (if breaking then '*' else '-') (String.concat "\n  " change)
| Underlining l ->
    Printf.printf "%s\n" (String.make l '-')
| Heading heading ->
    Printf.printf "%s\n" heading
| Corrupt line ->
    Printf.printf "%s\n" line

let warn () = Printf.eprintf "[%05d]: %s\n%!"

let with_changes_file file f a =
  let c = open_in_bin file in
  fold_tokens warn () (f c) a (Lexing.from_channel c) |> ignore

let cat_changes file =
  with_changes_file file cat_changes ()

let convert_changes file root =
  with_changes_file file (changes_to_directory root) (false, None) |> ignore

let _ =
  convert_changes "Changes" "changes.d"
