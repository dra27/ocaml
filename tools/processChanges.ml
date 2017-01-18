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

type _ output_token =
  Start : (unit -> unit) output_token
| Version : (string -> unit) output_token
| Breaking : (bool -> unit) output_token
| Section : (string -> unit) output_token
| Change : (bool -> string list -> unit) output_token
| Stop : (unit -> unit) output_token

type poly_pass = {generate: 'a . 'a output_token -> 'a}

(* Process changes files found within a version directory within root. The
   rules are relaxed after OCaml 4.01.0 has been processed, and this fact is
   folded in [old]. *)
let process_version titles root {generate} old item =
  let old = old || (item = "4.01.0") in
  let dir = Filename.concat root item in
  if Sys.is_directory dir then begin
    let s = Hashtbl.find titles item in
    if s = item ^ ": ocaml-changes-title: unspecified" then begin
      if item <> "archive" then
        Printf.eprintf "Directory %s skipped: ocaml-changes-title attribute not set\n%!" dir;
    end else
      let extract_and_escape s key =
        String.sub s (23 + String.length key) (String.length s - 23 - String.length key)
        |> String.map (function '+' -> ' ' | c -> c)
      in
      generate Version (extract_and_escape s item);
      let output = Queue.create () in
      (* ocaml-changes-sequence gives a list of subdirectories to search for in
         order. There is a further check below to warn about directories which
         are ignored because they are not listed in ocaml-changes-sequence. *)
      let c =
        Unix.open_process_in ("git check-attr ocaml-changes-sequence " ^ dir ^ " | tr ':' '\\012'")
      in
      input_line c |> ignore;
      input_line c |> ignore;
      let rec f ((breaking, scanned) as acc) =
        match input_line c with
          subitem ->
            let acc =
              (* It is possible to have changes items at the top-level. This
                 case is marked almost by accident as the special directory " "
                 which requires a certain amount of special handling. *)
              let key = if subitem = " " then item else item ^ "/" ^ subitem in
              let dir =
                Filename.concat dir (if subitem = " " then "." else subitem)
              in
              if Sys.file_exists dir then
                let scanned =
                  if subitem = " " then
                    scanned
                  else
                    subitem::scanned in
                if Sys.is_directory dir then begin
                  let s = Hashtbl.find titles key in
                  if s = key ^ ": ocaml-changes-title: unspecified" then begin
                    Printf.eprintf "Directory %s skipped: ocaml-changes-title attribute not set\n%!" dir;
                    (breaking, scanned)
                  end else begin
                    let title = extract_and_escape s key in
                    if subitem <> " " then
                      Queue.add (`S title) output;
                    let process_file (breaking, feature) (item, (prefix, (index, subindex))) =
                      let file = Filename.concat dir item in
                      match prefix with
                        "pr" | "gpr" | "feature" ->
                          if Sys.is_directory file then begin
                            Printf.eprintf "%s should be a file, not a directory!\n%!" file;
                            (breaking, 1)
                          end else
                            let c = open_in file in
                            let l1 = input_line c in
                            let change =
                              if l1.[0] = '*' then
                                [String.sub l1 1 (String.length l1 - 1)]
                              else
                                [l1] in
                            let rec f acc =
                              match input_line c with
                                line ->
                                  f (line::acc)
                              | exception End_of_file ->
                                  close_in c;
                                  List.rev acc
                            in
                            let change = f change in
                            let warn () n w =
                              let msg = ChangesLexer.standard_warning w in
                              Printf.eprintf "[%s:%d]: %s\n%!" file n msg
                            in
                            let ((tag_type, index') as tag, ()) =
                              ChangesLexer.validate_change_entry old warn () 1 change
                            in
                            let (tag, feature', bad_subindex) =
                              if tag_type = BadTag then
                                if subindex <> 0 then
                                  let tag = (tag_type_of_string prefix, index) in
                                  (tag, succ feature, subindex <> feature)
                                else
                                  ((BadTag, feature), succ feature, subindex <> 0)
                              else
                                (tag, succ subindex, subindex > feature) in
                            if tag <> (tag_type_of_string prefix, index) || bad_subindex then
                              begin
                                let tag = string_of_tag_type tag_type ^ "#" ^ string_of_int index' in
                                Printf.eprintf "File %s contains the wrong PR (%s)\n%!" file tag
                              end;
                            Queue.add (`C (l1.[0] = '*', change)) output;
                            (breaking || l1.[0] = '*', feature')
                      | _ ->
                          Printf.eprintf "File %s skipped: unrecognised file name\n%!" file;
                          (breaking, 1)
                    in
                    let validate acc s =
                      match String.index s '#' with
                        i ->
                          begin
                            try
                              match String.index s '-' with
                                j ->
                                  let tag =
                                    let index =
                                      String.sub s (i + 1) (j - i - 1)
                                      |> ChangesLexer.uint_of_string
                                    in
                                    let subindex =
                                       String.sub s (j + 1) (String.length s - j - 1)
                                       |> ChangesLexer.uint_of_string
                                    in
                                      (index, subindex)
                                  in
                                  (s, (String.sub s 0 i, tag))::acc
                              | exception Not_found ->
                                  let index =
                                    String.sub s (i + 1) (String.length s - i - 1)
                                    |> ChangesLexer.uint_of_string
                                  in
                                  (s, (String.sub s 0 i, (index, 0)))::acc
                            with Scanf.Scan_failure _ ->
                              let file = Filename.concat dir s in
                              Printf.eprintf "File %s skipped: unrecognised file name\n%!" file;
                              acc
                          end
                      | exception Not_found ->
                          acc
                    in
                    let order (_, (kl, il)) (_, (kr, ir)) =
                      let c1 = -compare kl kr in
                      if c1 = 0 then
                        compare il ir
                      else
                        c1
                    in
                    let changes = Sys.readdir dir in
                    let changes = Array.fold_left validate [] changes in
                    let (breaking, _) =
                      let changes = List.sort order changes in
                      List.fold_left process_file (breaking, 1) changes
                    in
                    let scanned =
                      if subitem = " " then
                        List.rev_append (List.rev_map fst changes) scanned
                      else
                        scanned
                    in
                    (breaking, scanned)
                  end
                end else begin
                  Printf.eprintf "File %s has been ignored\n%!" dir;
                  (breaking, scanned)
                end
              else
                (breaking, scanned)
            in
            f acc
        | exception End_of_file ->
            close_in c;
            acc
      in
      let (breaking, scanned) = f (false, []) in
      let rec f scanned entries =
        match (scanned, entries) with
          (s::ss, e::es) when s = e ->
            f ss es
        | (ss, e::es) ->
            if e <> ".gitattributes" then
              Filename.concat item e |> Printf.eprintf "Skipped %s\n%!";
            f ss es
        | (_, []) ->
            ()
      in
      let scanned = List.sort compare scanned in
      f scanned (Sys.readdir dir |> Array.to_list |> List.sort compare);
      generate Breaking breaking;
      let f = function
        `S title ->
          generate Section title
      | `C (breaking, change) ->
          generate Change breaking change
      in
      Queue.iter f output
  end;
  old

(* Process files found in root to produce Changes output *)
let generate_changes root {generate} =
  let titles = Hashtbl.create 64 in
  let process_version = process_version titles root {generate} in
  let dirs = Sys.readdir root in
  let compare l r =
    if l = r then
      0
    else
      match (l, r) with
        ("next", _) ->
          -1
      | (_, "next") ->
          1
      | ("next-minor", _) ->
          -1
      | (_, "next-minor") ->
          1
      | (l, r) ->
          -compare l r in
  (* If [item] is a directory in root, add it and any directories it contains
     to dirs. It is intentional that the forward slash is used here, even on
     Windows. *)
  let scan_dir dirs item =
    let full_dir = Filename.concat root item in
    if Sys.is_directory full_dir then
      let dirs = item::dirs in
      let f dirs subitem =
        let full_item = Filename.concat full_dir subitem in
        if Sys.is_directory full_item then
          (item ^ "/" ^ subitem)::dirs
        else
          dirs in
      Array.fold_left f dirs (Sys.readdir full_dir)
    else
      dirs in
  Array.sort compare dirs;
  (* Coalescing the reading of ocaml-changes-title into a single git call makes
     this script an order of magnitude faster with Git for Windows. Globbing
     hasn't been correctly implemented for Git for Windows check-attr command
     either! *)
  let cmd = Array.fold_left scan_dir [] dirs in
  let c =
    let cwd = Unix.getcwd () in
    Unix.chdir root;
    let c =
      Unix.open_process_in ("git check-attr ocaml-changes-title " ^ String.concat " " cmd)
    in
    Unix.chdir cwd;
    c in
  let rec read c =
    match input_line c with
      s ->
        Hashtbl.add titles (String.sub s 0 (String.index s ':')) s;
        read c
    | exception End_of_file ->
        close_in c in
  read c;
  (* titles hash table initialised, now process the versions *)
  Array.fold_left process_version false dirs |> ignore

(* Produce "classic" text Changes file *)
let generate : type s . s output_token -> s = function
  Start ->
    ignore
| Version ->
    fun title ->
      Printf.printf "%s:\n%s\n\n%!" title (String.make (String.length title + 1) '-')
| Breaking ->
    (function
       true -> Printf.printf "%s\n\n%!" ChangesLexer.breaking_message
     | false -> ())
| Section ->
    Printf.printf "### %s:\n\n%!"
| Change ->
    fun breaking change ->
      let bullet = if breaking then '*' else '-' in
      Printf.printf "%c %s%!" bullet (String.concat "\n  " change);
      Printf.printf "\n\n%!"
| Stop ->
    ignore

let _ =
  generate_changes Sys.argv.(1) {generate}
