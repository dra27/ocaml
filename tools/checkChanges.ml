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

module StringSet = Set.Make(String)

let check_changes root range =
  let c =
    Unix.open_process_in ("git diff --name-only " ^ range ^ " " ^ root ^ "/")
  in
  let rec f warnings success files sections versions =
    match input_line c with
      file ->
        let entry =
          let start = String.length root + 1 in
          let length = String.length file - String.length root - 1 in
          String.sub file start length in
        if Sys.file_exists file && entry <> "archive"
                                && entry <> ".gitattributes" then
          match String.split_on_char '/' entry with
            [version; section; _] ->
              let files = entry::files in
              let sections = StringSet.add (version ^ "/" ^ section) sections in
              let versions = StringSet.add version versions in
              f warnings success files sections versions
          | [version; _] ->
              let files = entry::files in
              f warnings success files sections (StringSet.add version versions)
          | _ ->
              let dirname =
                let d = Filename.dirname entry in
                if d = Filename.current_dir_name then
                  root
                else
                  root ^ "/" ^ d
              in
              let w =
                let entry = Filename.basename entry in
                Printf.sprintf "File %s not expected in %s" entry dirname
              in
              f (w::warnings) false files sections versions
        else
          f warnings success files sections versions
    | exception End_of_file ->
        (warnings, success, files, sections, versions)
  in
  (* Get the details of all altered changes files *)
  let (warnings, success, files, sections, versions) =
    f [] true [] StringSet.empty StringSet.empty in
  let cwd = Unix.getcwd () in
  Unix.chdir root;
  (* Ensure that all the versions have a defined ocaml-changes-sequence and
     ocaml-changes-title and that all sections have ocaml-changes-title. *)
  let git_attribute_exists name item =
    let c = Unix.open_process_in ("git check-attr " ^ name ^ " -- " ^ item) in
    let s = input_line c in
    while match input_line c with _ -> true | exception End_of_file -> false do
      ()
    done;
    String.sub s (String.length s - 13) 13 <> ": unspecified"
  in
  let result =
    let f name item ((warnings, _) as acc) =
      if git_attribute_exists name item then
        acc
      else
        let w =
          Printf.sprintf "%s/%s does not have the %s Git attribute set" root
                                                                        item
                                                                        name
        in
        (w::warnings, false)
    in
    let alldirs = StringSet.union versions sections in
    StringSet.fold (f "ocaml-changes-title") alldirs (warnings, success) |>
    StringSet.fold (f "ocaml-changes-sequence") versions
  in
  let (warnings, success) =
    let f (warnings, success) item =
      let change =
        let c = open_in item in
        let rec f a =
          match input_line c with
            l ->
              f (l::a)
          | exception End_of_file ->
              close_in c;
              List.rev a
        in
        let l =
          match input_line c with
            l ->
              if String.length l > 0 && l.[0] = '*' then
                String.sub l 1 (String.length l - 1)
              else
                l
          | exception End_of_file ->
              ""
        in
        f [l]
      in
      (* No attempt is made to validate that sub-indexes are required or
         contiguous. *)
      let (tag, warnings, success, may_be_untagged) =
        try
          match String.split_on_char '#' (Filename.basename item) with
            ["pr" as prefix; suffix]
          | ["gpr" as prefix; suffix]
          | ["feature" as prefix; suffix] ->
              let process_index index =
                let index = ChangesLexer.uint_of_string index in
                if prefix = "feature" then
                  0
                else
                  index
              in
              begin
                match String.split_on_char '-' suffix with
                  [index; subindex] when prefix <> "feature" ->
                    let tag =
                      (tag_type_of_string prefix, process_index index)
                    in
                    let untagged = ChangesLexer.uint_of_string subindex >= 0 in
                    (tag, warnings, success, untagged)
                | [index] ->
                    let tag =
                      (tag_type_of_string prefix, process_index index)
                    in
                    (tag, warnings, success, false)
                | _ ->
                    raise (Scanf.Scan_failure "")
              end
          | _ ->
              raise (Scanf.Scan_failure "")
        with Scanf.Scan_failure _ ->
          let w =
            let base = Filename.basename item in
            let dir = Filename.dirname item in
            Printf.sprintf "File %s is not correctly named in %s/%s\n" base
                                                                       root
                                                                       dir
          in
          ((BadTag, 0), w::warnings, false, false)
      in
      let warn (ws, success) n issue =
        let success =
          success && issue <> `NoAuthor
        in
        let w =
          let issue = ChangesLexer.standard_warning issue in
          Printf.sprintf "[%s/%s:%d]: %s" root item n issue
        in
        (w::ws, success)
      in
      let (read_tag, ((warnings, _) as result)) =
        let acc = (warnings, success) in
        ChangesLexer.validate_change_entry false warn acc 1 change
      in
      if tag <> read_tag
          && (not may_be_untagged || read_tag <> (BadTag, 0)) then
        let string_of_tag () = function
          (MPR, n) -> Printf.sprintf "PR#%d" n
        | (GPR, n) -> Printf.sprintf "GPR#%d" n
        | (BadTag, _) -> "no tag"
        in
        let w =
          Printf.sprintf "%s is expected to contain %a but contains %a" item
                                        string_of_tag tag string_of_tag read_tag
        in
        (w::warnings, false)
      else
        result
    in
    List.fold_left f result files
  in
  Unix.chdir cwd;
  List.iter (Printf.eprintf "%s\n") (List.rev warnings);
  if not success then
    exit 1

let _ =
  check_changes Sys.argv.(1) Sys.argv.(2)
