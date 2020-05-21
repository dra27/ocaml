(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*             Xavier Leroy, projet Cristal, INRIA Rocquencourt           *)
(*                                                                        *)
(*   Copyright 1996 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

val command_line_options: (string * Arg.spec * string) list

val spacetime_node_hole_pointer_is_live_before:
  Specifics.specific_operation -> bool

val big_endian: bool

val size_addr: int

val size_int: int

val size_float: int

val allow_unaligned_access: bool

val division_crashes_on_overflow: bool

val identity_addressing: Specifics.addressing_mode

val offset_addressing:
  Specifics.addressing_mode -> int -> Specifics.addressing_mode

val num_args_addressing: Specifics.addressing_mode -> int

val print_addressing:
  (Format.formatter -> 'a -> unit) -> Specifics.addressing_mode ->
  Format.formatter -> 'a array -> unit

val print_specific_operation:
  (Format.formatter -> 'a -> unit) -> Specifics.specific_operation ->
  Format.formatter -> 'a array -> unit
