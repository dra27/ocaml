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

(* Open a DLL to check the existence of symbols (no need to do full
     symbol resolution).  Raise [Failure msg] in case of error. *)
val open_dll_for_checking: string -> unit

(* Close all opened DLLs *)
val close_all_dlls: unit -> unit

(* Find a primitive in the DLLs currently opened for checking and return
   its address. Return [None] if the primitive is not found. *)
val find_primitive_for_checking:
  string -> CamlinternalDynlink.primitive_address option

(* Initialization for separate compilation.
   Initialize the DLL search path to the directories given in the
   environment variable CAML_LD_LIBRARY_PATH, plus contents of ld.conf file
   if argument is [false].  If argument is [true], ignore ld.conf. *)
val init_compile: bool -> unit
