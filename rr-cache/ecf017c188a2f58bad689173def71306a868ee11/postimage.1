(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*             Xavier Leroy, projet Cristal, INRIA Rocquencourt           *)
(*                                                                        *)
(*   Copyright 2000 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

(* Handling of sections in bytecode executable files *)

(** Recording sections written to a bytecode executable file *)

val init_record: out_channel -> unit
    (* Start recording sections from the current position in out_channel *)

val record: out_channel -> string -> unit
    (* Record the current position in the out_channel as the end of
       the section with the given name *)

val write_toc_and_trailer: out_channel -> unit
    (* Write the table of contents and the standard trailer for bytecode
       executable files *)

(** Reading sections from a bytecode executable file *)

val read_toc: in_channel -> unit
    (* Read the table of sections from a bytecode executable *)

exception Bad_magic_number
    (* Raised by [read_toc] if magic number doesn't match *)

val toc: unit -> (string * int) list
    (* Return the current table of contents as a list of
       (section name, section length) pairs. *)

val seek_section: in_channel -> string -> int
    (* Position the input channel at the beginning of the section named "name",
       and return the length of that section.  Raise Not_found if no
       such section exists. *)

val read_section_string: in_channel -> string -> string
    (* Return the contents of a section, as a string *)

val read_section_struct: in_channel -> string -> 'a
    (* Return the contents of a section, as marshalled data *)

val pos_first_section: in_channel -> int
   (* Return the position of the beginning of the first section *)

val reset: unit -> unit

(** Search methods used by a tendered bytecode image to find a runtime. *)
type search_mode =
| Absolute of string
    (** Check fixed location only *)
| Absolute_then_search of string
    (** Check given location first then search for the interpreter *)
| Search
    (** Always search for the interpreter *)

val read_runtime : in_channel -> string * Misc.RuntimeID.t option * search_mode
(** Returns the runtime used by this tendered/standalone image

    @raise Not_found For an image linked using -without-runtime *)
