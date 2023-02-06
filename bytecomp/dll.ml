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

(* DLLs currently opened for checking *)
let dlls_opened_for_checking = ref ([] : (string * Binutils.t) list)

let open_dll_for_checking name =
  let fullname = CamlinternalDynlink.fullname_of_name name in
  match List.assoc_opt fullname !dlls_opened_for_checking with
  | Some _ -> () (* DLL already opened *)
  | None ->
      begin match Binutils.read fullname with
      | Ok t -> dlls_opened_for_checking :=
        (fullname, t) :: !dlls_opened_for_checking
      | Error err ->
          failwith (fullname ^ ": " ^ Binutils.error_to_string err)
      end

(* Close all DLLs *)

let close_all_dlls () =
  dlls_opened_for_checking := []

(* Find a primitive in the currently opened DLLs. *)

let find_primitive_for_checking prim_name =
  let rec find seen = function
    [] ->
      None
  | (_,t) as curr :: rem ->
      if Binutils.defines_symbol t prim_name then
        Some CamlinternalDynlink.Prim_exists
      else
        find (curr :: seen) rem
  in
  find [] !dlls_opened_for_checking

(* Initialization for separate compilation *)

let init_compile nostdlib =
  CamlinternalDynlink.set_path
    (CamlinternalDynlink.ld_library_path_contents() @
    (if nostdlib then []
     else CamlinternalDynlink.ld_library_path_contents()))
