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

let dummy_mach_fundecl = Mach.({
  fun_name = ""; fun_args = [| |]; fun_body = dummy_instr ();
  fun_codegen_options = []; fun_dbg = Debuginfo.none;
  fun_poll = Lambda.Default_poll; fun_num_stack_slots = [| |]
})

let dummy_linear_fundecl = Linear.({
  fun_name = ""; fun_args = Reg.Set.empty; fun_body = end_instr ();
  fun_fast = false; fun_dbg = Debuginfo.none;
  fun_tailrec_entry_point_label = 0; fun_contains_nontail_calls = false;
  fun_num_stack_slots = [| |]; fun_frame_required = false;
  fun_extra_stack_used = 0
})

module Empty = struct
  module Arch = struct
    let command_line_options = []
    type addressing_mode = unit
    type specific_operation = unit
    let box_addressing_mode () =
      (Operations.Amd64 (Iindexed 0) : Operations.addressing_modes)
    let box_specific_operation () =
      (Operations.Amd64 Isextend32 : Operations.specific_operations)
    let unbox_addressing_mode _ = ()
    let unbox_specific_operation _ = ()
    let big_endian = false
    let allow_unaligned_access = false
    let division_crashes_on_overflow = false
    let size_addr = 8
    let size_int = 8
    let size_float = 8
    let identity_addressing = ()
    let offset_addressing () _ = ()
  end
  module CSE = struct
    let fundecl _ = dummy_mach_fundecl
  end
  module Emit = struct
    let fundecl _ = ()
    let data _ = ()
    let begin_assembly () = ()
    let end_assembly () = ()
  end
  module Proc = struct
    let num_register_classes = 0
    let register_class _ = 0
    let num_available_registers = [| |]
    let first_available_register = [| |]
    let register_name _ = ""
    let phys_reg _ = Reg.dummy
    let rotate_registers = false
    let loc_arguments _ = [| |], 0
    let loc_results _ = [| |]
    let loc_parameters _ = [| |]
    let loc_external_arguments _ = [| |], 0
    let loc_external_results _ = [| |]
    let loc_exn_bucket = Reg.dummy
    let max_arguments_for_tailcalls = 0
    let safe_register_pressure _ = 0
    let max_register_pressure _ = [| |]
    let destroyed_at_oper _ = [| |]
    let destroyed_at_raise = [| |]
    let destroyed_at_reloadretaddr = [| |]
    let dwarf_register_numbers ~reg_class:(_ : int) = [| |]
    let stack_ptr_dwarf_register_number = 0
    let assemble_file _ _ = 0
    let init () = ()
  end
  module Reload = struct
    let fundecl _ _ = dummy_mach_fundecl, false
  end
  module Scheduling = struct
    let fundecl _ = dummy_linear_fundecl
  end
  module Selection = struct
    let fundecl ~future_funcnames:(_ : Misc.Stdlib.String.Set.t) _ =
      dummy_mach_fundecl
  end
  module Stackframe = struct
    let trap_handler_size = 0
    let analyze _ =
      Stackframegen.{
        contains_nontail_calls = false;
        frame_required = false;
        extra_stack_used = 0
      }
  end
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
  mutable max_arguments_for_tailcalls: int;
  mutable backend: (module Backend)
}

let info = {
  command_line_options = [];
  big_endian = false;
  size_addr = 8;
  size_int = 8;
  size_float = 8;
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
  max_arguments_for_tailcalls = 0;
  backend = (module Empty : Backend)
}

let platform_hooks = Queue.create ()

let platform_hook f =
  Queue.push f platform_hooks;
  f info

let load_backend backend =
  let open (val backend : Backend) in
  info.command_line_options <- Arch.command_line_options;
  info.big_endian <- Arch.big_endian;
  info.size_addr <- Arch.size_addr;
  info.size_int <- Arch.size_int;
  info.size_float <- Arch.size_float;
  info.allow_unaligned_access <- Arch.allow_unaligned_access;
  info.division_crashes_on_overflow <- Arch.division_crashes_on_overflow;
  info.num_register_classes <- Proc.num_register_classes;
  info.register_class <- Proc.register_class;
  info.num_available_registers <- Proc.num_available_registers;
  info.first_available_register <- Proc.first_available_register;
  info.register_name <- Proc.register_name;
  info.phys_reg <- Proc.phys_reg;
  info.rotate_registers <- Proc.rotate_registers;
  info.loc_exn_bucket <- Proc.loc_exn_bucket;
  info.max_arguments_for_tailcalls <- Proc.max_arguments_for_tailcalls;
  info.backend <- backend;
  Queue.iter (fun f -> f info) platform_hooks
