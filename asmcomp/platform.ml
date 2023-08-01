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

type platform = {
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

let info = {
  command_line_options = [];
  big_endian = false;
  size_addr = 1;
  size_int = 1;
  size_float = 1;
  allow_unaligned_access = false;
  division_crashes_on_overflow = false;
  num_register_classes = 0;
  register_class = Fun.const 0;
  num_available_registers = [| |];
  first_available_register = [| |];
  register_name = Fun.const "";
  phys_reg = Fun.const Reg.dummy;
  rotate_registers = false;
  loc_exn_bucket = Reg.dummy;
  max_arguments_for_tailcalls = 0
}

let platform_hooks = Queue.create ()

let platform_hook f =
  Queue.push f platform_hooks;
  f info

let load_info platform =
  let open (val platform : S) in
  info.command_line_options <- command_line_options;
  info.big_endian <- big_endian;
  info.size_addr <- size_addr;
  info.size_int <- size_int;
  info.size_float <- size_float;
  info.allow_unaligned_access <- allow_unaligned_access;
  info.division_crashes_on_overflow <- division_crashes_on_overflow;
  info.num_register_classes <- num_register_classes;
  info.register_class <- register_class;
  info.num_available_registers <- num_available_registers;
  info.first_available_register <- first_available_register;
  info.register_name <- register_name;
  info.phys_reg <- phys_reg;
  info.rotate_registers <- rotate_registers;
  info.loc_exn_bucket <- loc_exn_bucket;
  info.max_arguments_for_tailcalls <- max_arguments_for_tailcalls;
  Queue.iter (fun f -> f info) platform_hooks
