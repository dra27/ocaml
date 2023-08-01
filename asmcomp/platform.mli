(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*                         David Allsopp, Tarides                         *)
(*                                                                        *)
(*   Copyright 2023 David Allsopp Ltd.                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

module type S = sig
  val command_line_options: (string * Arg.spec * string) list
  val big_endian: bool
  val size_addr: int
  val size_int: int
  val size_float: int
  val allow_unaligned_access: bool
  val division_crashes_on_overflow: bool
  val num_register_classes: int
  val register_class: Reg.t -> int
  val num_available_registers: int array
  val first_available_register: int array
  val register_name: int -> string
  val phys_reg: int -> Reg.t
  val rotate_registers: bool
  val loc_exn_bucket: Reg.t
  val max_arguments_for_tailcalls: int
end

type platform = private {
  mutable command_line_options: (string * Arg.spec * string) list;
  mutable big_endian: bool;
  mutable size_addr: int;
  mutable size_int: int;
  mutable size_float: int;
  mutable allow_unaligned_access: bool;
  mutable division_crashes_on_overflow: bool;
  mutable num_register_classes: int;
  mutable register_class: Reg.t -> int;
  mutable num_available_registers: int array;
  mutable first_available_register: int array;
  mutable register_name: int -> string;
  mutable phys_reg: int -> Reg.t;
  mutable rotate_registers: bool;
  mutable loc_exn_bucket: Reg.t;
  mutable max_arguments_for_tailcalls: int
}

val info : platform

val load_info : (module S) -> unit

val platform_hook : (platform -> unit) -> unit
