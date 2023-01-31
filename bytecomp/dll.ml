(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*             Xavier Leroy, projet Cristal, INRIA Rocquencourt           *)
(*                                                                        *)
(*   Copyright 2001 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

(* Handling of dynamically-linked libraries *)

type dll_handle
type dll_address

external dll_open: string -> dll_handle = "caml_dynlink_open_lib"
external dll_close: dll_handle -> unit = "caml_dynlink_close_lib"
external dll_sym: dll_handle -> string -> dll_address
                = "caml_dynlink_lookup_symbol"
         (* returned dll_address may be Val_unit *)
external add_primitive: dll_address -> int = "caml_dynlink_add_primitive"
external get_current_dlls: unit -> dll_handle array
                                           = "caml_dynlink_get_current_libs"

(* Current search path for DLLs *)
let search_path = ref ([] : string list)

(* DLLs currently opened for checking *)
let dlls_opened_for_checking = ref ([] : (string * Binutils.t) list)

(* DLLs currently opened for execution *)
let dlls_opened_for_execution = ref ([] : (string * dll_handle) list)

(* Add the given directories to the search path for DLLs. *)
let add_path dirs =
  search_path := dirs @ !search_path

let remove_path dirs =
  search_path := List.filter (fun d -> not (List.mem d dirs)) !search_path

let fullname_of_name name =
  let name = name ^ Config.ext_dll in
  try
    let fullname = Misc.find_in_path !search_path name in
    if Filename.is_implicit fullname then
      Filename.concat Filename.current_dir_name fullname
    else fullname
  with Not_found -> name

let open_dll_for_checking name =
  let fullname = fullname_of_name name in
  match List.assoc_opt fullname !dlls_opened_for_checking with
  | Some _ -> () (* DLL already opened *)
  | None ->
      begin match Binutils.read fullname with
      | Ok t -> dlls_opened_for_checking :=
        (fullname, t) :: !dlls_opened_for_checking
      | Error err ->
          failwith (fullname ^ ": " ^ Binutils.error_to_string err)
      end

let open_dll_for_execution name =
  let fullname = fullname_of_name name in
  match List.assoc_opt fullname !dlls_opened_for_execution with
  | Some _ -> () (* DLL has already been opened *)
  | None ->
      begin match dll_open fullname with
      | dll ->
          dlls_opened_for_execution :=
            (fullname, dll) :: !dlls_opened_for_execution
      | exception Failure msg ->
          failwith (fullname ^ ": " ^ msg)
      end

(* Close all DLLs *)

let close_all_dlls () =
  List.iter (fun (_, dll) -> dll_close dll) !dlls_opened_for_execution;
  dlls_opened_for_checking := [];
  dlls_opened_for_execution := []

(* Find a primitive in the currently opened DLLs. *)

type primitive_address =
  | Prim_loaded of dll_address
  | Prim_exists

let find_primitive_for_checking prim_name =
  let rec find seen = function
    [] ->
      None
  | (_,t) as curr :: rem ->
      if Binutils.defines_symbol t prim_name then
        Some Prim_exists
      else
        find (curr :: seen) rem
  in
  find [] !dlls_opened_for_checking

let find_primitive_for_execution prim_name =
  let rec find seen = function
    [] ->
      None
  | (_, dll) as curr :: rem ->
      let addr = dll_sym dll prim_name in
      if addr == Obj.magic () then find (curr :: seen) rem else begin
        if seen <> [] then dlls_opened_for_execution :=
          curr :: List.rev_append seen rem;
        Some (Prim_loaded addr)
      end
  in
  find [] !dlls_opened_for_execution

(* If linking in core (dynlink or toplevel), synchronize the VM
   table of primitive with the linker's table of primitive
   by storing the given primitive function at the given position
   in the VM table of primitives.  *)

let linking_in_core = ref false

let synchronize_primitive num symb =
  if !linking_in_core then begin
    let actual_num = add_primitive symb in
    assert (actual_num = num)
  end

(* Read the [ld.conf] file and return the corresponding list of directories *)

let ld_conf_contents () =
  let path = ref [] in
  begin try
    let ic = open_in (Filename.concat Config.standard_library "ld.conf") in
    begin try
      while true do
        path := input_line ic :: !path
      done
    with End_of_file -> ()
    end;
    close_in ic
  with Sys_error _ -> ()
  end;
  List.rev !path

(* Split the CAML_LD_LIBRARY_PATH environment variable and return
   the corresponding list of directories.  *)
let ld_library_path_contents () =
  match Sys.getenv "CAML_LD_LIBRARY_PATH" with
  | exception Not_found ->
      []
  | s ->
      Misc.split_path_contents s

let split_dll_path path =
  Misc.split_path_contents ~sep:'\000' path

(* Initialization for separate compilation *)

let init_compile nostdlib =
  search_path :=
    ld_library_path_contents() @
    (if nostdlib then [] else ld_conf_contents())

(* Initialization for linking in core (dynlink or toplevel) *)

let init_toplevel dllpath =
  search_path :=
    ld_library_path_contents() @
    split_dll_path dllpath @
    ld_conf_contents();
  dlls_opened_for_execution :=
    List.map (fun dll -> "", dll)
      (Array.to_list (get_current_dlls()));
  linking_in_core := true
