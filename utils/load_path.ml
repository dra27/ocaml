(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*                   Jeremie Dimino, Jane Street Europe                   *)
(*                                                                        *)
(*   Copyright 2018 Jane Street Group LLC                                 *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

module SMap = Misc.Stdlib.String.Map

(* Mapping from basenames to full filenames *)
type registry = string SMap.t ref

let scans : string list SMap.t ref = ref SMap.empty
let files : registry = ref SMap.empty
let files_uncap : registry = ref SMap.empty

module Dir = struct
  type t = {
    path : string;
    files : string list;
  }

  let path t = t.path
  let files t = t.files

  (* For backward compatibility reason, simulate the behavior of
     [Misc.find_in_path]: silently ignore directories that don't exist
     + treat [""] as the current directory. *)
  let readdir_compat dir =
    let dir = if dir = "" then Filename.current_dir_name else dir in
    match SMap.find_opt dir !scans with
    | Some entries -> entries
    | None ->
        let entries =
          try
            Sys.readdir dir |> Array.to_list
          with Sys_error _ -> []
        in
          scans := SMap.add dir entries !scans;
          entries

  let create path =
    { path; files = readdir_compat path }
end

let dirs = ref []

let reset () =
  files := SMap.empty;
  files_uncap := SMap.empty;
  dirs := []

let get () = !dirs
let get_paths () = List.map Dir.path !dirs

let add dir =
  let add_file base =
    let fn = Filename.concat dir.Dir.path base in
    files := SMap.add base fn !files;
    files_uncap := SMap.add (String.uncapitalize_ascii base) fn !files_uncap;
  in
  List.iter add_file dir.Dir.files;
  dirs := dir :: !dirs

let add_file file =
  let base = Filename.basename file in
  let dir = Filename.dirname file in
  files := SMap.add base file !files;
  files_uncap := SMap.add (String.uncapitalize_ascii base) file !files_uncap;
  try
    scans := SMap.add dir (file :: SMap.find dir !scans) !scans
  with Not_found -> ()

let remove_dir dir =
  let new_dirs = List.filter (fun d -> Dir.path d <> dir) !dirs in
  if new_dirs <> !dirs then begin
    reset ();
    List.iter add (List.rev new_dirs)
  end

let add_dir dir = add (Dir.create dir)

let init l =
  reset ();
  List.iter add_dir (List.rev l)

let is_basename fn = Filename.basename fn = fn

let find fn =
  if is_basename fn then
    SMap.find fn !files
  else
    Misc.find_in_path (get_paths ()) fn

let find_uncap fn =
  if is_basename fn then
    SMap.find (String.uncapitalize_ascii fn) !files_uncap
  else
    Misc.find_in_path_uncap (get_paths ()) fn
