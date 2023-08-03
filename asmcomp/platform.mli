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

module type Backend = sig
  module Arch : Operations.S
  module CSE : sig
    val fundecl: Mach.fundecl -> Mach.fundecl
  end
  module Emit : sig
    val fundecl: Linear.fundecl -> unit
    val data: Cmm.data_item list -> unit
    val begin_assembly: unit -> unit
    val end_assembly: unit -> unit
  end
  module Proc : module type of Proc
  module Reload : sig
    val fundecl: Mach.fundecl -> int array -> Mach.fundecl * bool
  end
  module Scheduling : sig
    val fundecl: Linear.fundecl -> Linear.fundecl
  end
  module Selection : sig
    val fundecl:
      future_funcnames:Misc.Stdlib.String.Set.t -> Cmm.fundecl -> Mach.fundecl
  end
  module Stackframe : sig
    val trap_handler_size : int
    val analyze : Mach.fundecl -> Stackframegen.analysis_result
  end
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
