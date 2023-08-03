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

module type CSE = sig
  (** Common interface to all architecture-specific CSE modules *)
  val fundecl: Mach.fundecl -> Mach.fundecl
end
module type Emit = sig
  (* Generation of assembly code *)
  val fundecl: Linear.fundecl -> unit
  val data: Cmm.data_item list -> unit
  val begin_assembly: unit -> unit
  val end_assembly: unit -> unit
end
module type Reload = sig
  (* Insert load/stores for pseudoregs that got assigned to stack locations. *)
  val fundecl: Mach.fundecl -> int array -> Mach.fundecl * bool
end
module type Scheduling = sig
  (* Instruction scheduling *)
  val fundecl: Linear.fundecl -> Linear.fundecl
end
module type Selection = sig
  (* Selection of pseudo-instructions, assignment of pseudo-registers,
     sequentialization. *)
  val fundecl:
    future_funcnames:Misc.Stdlib.String.Set.t -> Cmm.fundecl -> Mach.fundecl
end
module type Stackframe = sig
  (* Compute the parameters needed for allocating and managing stack frames
     in the Emit phase. *)
  val trap_handler_size : int
  val analyze : Mach.fundecl -> Stackframegen.analysis_result
end
module type Backend = sig
  module Arch : Operations.S
  module Proc : module type of Processor
  module CSE : CSE
  module Emit : Emit
  module Reload : Reload
  module Scheduling : Scheduling
  module Selection : Selection
  module Stackframe : Stackframe
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
  mutable max_arguments_for_tailcalls: int;
  mutable backend: (module Backend)
}

val info : platform

val load_backend : (module Backend) -> unit

val platform_hook : (platform -> unit) -> unit
