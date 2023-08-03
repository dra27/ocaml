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

(* Representation of machine code by sequences of pseudoinstructions *)

type integer_comparison =
    Isigned of Cmm.integer_comparison
  | Iunsigned of Cmm.integer_comparison

type integer_operation =
    Iadd | Isub | Imul | Imulh | Idiv | Imod
  | Iand | Ior | Ixor | Ilsl | Ilsr | Iasr
  | Icomp of integer_comparison
  | Icheckbound

type float_comparison = Cmm.float_comparison

type test =
    Itruetest
  | Ifalsetest
  | Iinttest of integer_comparison
  | Iinttest_imm of integer_comparison * int
  | Ifloattest of float_comparison
  | Ioddtest
  | Ieventest

type ('am, 'so) gen_operation =
    Imove
  | Ispill
  | Ireload
  | Iconst_int of nativeint
  | Iconst_float of int64
  | Iconst_symbol of string
  | Icall_ind
  | Icall_imm of { func : string; }
  | Itailcall_ind
  | Itailcall_imm of { func : string; }
  | Iextcall of { func : string;
                  ty_res : Cmm.machtype; ty_args : Cmm.exttype list;
                  alloc : bool;
                  stack_ofs : int; }
  | Istackoffset of int
  | Iload of { memory_chunk : Cmm.memory_chunk;
               addressing_mode : 'am;
               mutability : Asttypes.mutable_flag;
               is_atomic : bool }
  | Istore of Cmm.memory_chunk * 'am * bool
  | Ialloc of { bytes : int; dbginfo : Debuginfo.alloc_dbginfo; }
  | Iintop of integer_operation
  | Iintop_imm of integer_operation * int
  | Icompf of float_comparison
  | Inegf | Iabsf | Iaddf | Isubf | Imulf | Idivf
  | Ifloatofint | Iintoffloat
  | Iopaque
  | Ispecific of 'so
  | Ipoll of { return_label: Cmm.label option }
  | Idls_get
  | Ireturn_addr

type operation =
  (Operations.addressing_modes, Operations.specific_operations) gen_operation

type instruction =
  { desc: instruction_desc;
    next: instruction;
    arg: Reg.t array;
    res: Reg.t array;
    dbg: Debuginfo.t;
    mutable live: Reg.Set.t
  }

and instruction_desc =
    Iend
  | Iop of operation
  | Ireturn
  | Iifthenelse of test * instruction * instruction
  | Iswitch of int array * instruction array
  | Icatch of Cmm.rec_flag * (int * instruction) list * instruction
  | Iexit of int
  | Itrywith of instruction * instruction
  | Iraise of Lambda.raise_kind

type fundecl =
  { fun_name: string;
    fun_args: Reg.t array;
    fun_body: instruction;
    fun_codegen_options : Cmm.codegen_option list;
    fun_dbg : Debuginfo.t;
    fun_poll: Lambda.poll_attribute;
    fun_num_stack_slots: int array;
    fun_contains_calls: bool;
  }

let dummy_instr () =
  let rec dummy_instr =
    { desc = Iend;
      next = dummy_instr;
      arg = [||];
      res = [||];
      dbg = Debuginfo.none;
      live = Reg.Set.empty
    }
  in dummy_instr

let end_instr () =
  { desc = Iend;
    next = dummy_instr ();
    arg = [||];
    res = [||];
    dbg = Debuginfo.none;
    live = Reg.Set.empty
  }

let instr_cons d a r n =
  { desc = d; next = n; arg = a; res = r;
    dbg = Debuginfo.none; live = Reg.Set.empty
  }

let instr_cons_debug d a r dbg n =
  { desc = d; next = n; arg = a; res = r; dbg = dbg; live = Reg.Set.empty }

let rec instr_iter f i =
  match i.desc with
    Iend -> ()
  | _ ->
      f i;
      match i.desc with
        Iend -> ()
      | Ireturn | Iop Itailcall_ind | Iop(Itailcall_imm _) -> ()
      | Iifthenelse(_tst, ifso, ifnot) ->
          instr_iter f ifso; instr_iter f ifnot; instr_iter f i.next
      | Iswitch(_index, cases) ->
          for i = 0 to Array.length cases - 1 do
            instr_iter f cases.(i)
          done;
          instr_iter f i.next
      | Icatch(_, handlers, body) ->
          instr_iter f body;
          List.iter (fun (_n, handler) -> instr_iter f handler) handlers;
          instr_iter f i.next
      | Iexit _ -> ()
      | Itrywith(body, handler) ->
          instr_iter f body; instr_iter f handler; instr_iter f i.next
      | Iraise _ -> ()
      | _ ->
          instr_iter f i.next

let map_op map_addressing_mode map_specific_operation = function
| Iload { memory_chunk; addressing_mode; mutability; is_atomic } ->
    let addressing_mode = map_addressing_mode addressing_mode in
    Iload { memory_chunk; addressing_mode; mutability; is_atomic}
| Istore (memory_chunk, addressing_mode, is_assignment) ->
    let addressing_mode = map_addressing_mode addressing_mode in
    Istore (memory_chunk, addressing_mode, is_assignment)
| Ispecific sop ->
    Ispecific (map_specific_operation sop)
| (Imove | Ispill | Ireload | Iconst_int _ | Iconst_float _ | Iconst_symbol _
   | Icall_ind | Icall_imm _ | Itailcall_ind | Itailcall_imm _ | Iextcall _
   | Istackoffset _ | Ialloc _ | Iintop _ | Iintop_imm (_, _) | Icompf _ | Inegf
   | Iabsf | Iaddf | Isubf | Imulf | Idivf | Ifloatofint | Iintoffloat | Iopaque
   | Ipoll _ | Idls_get | Ireturn_addr) as desc -> desc

let operation_is_pure = function
  | Icall_ind | Icall_imm _ | Itailcall_ind | Itailcall_imm _
  | Iextcall _ | Istackoffset _ | Istore _ | Ialloc _ | Ipoll _
  | Idls_get
  | Iintop(Icheckbound) | Iintop_imm(Icheckbound, _) | Iopaque -> false
  | Ispecific sop -> Operations.operation_is_pure sop
  | _ -> true

let operation_can_raise op =
  match op with
  | Icall_ind | Icall_imm _ | Iextcall _
  | Iintop (Icheckbound) | Iintop_imm (Icheckbound, _)
  | Ialloc _ | Ipoll _ -> true
  | Ispecific sop -> Operations.operation_can_raise sop
  | _ -> false
