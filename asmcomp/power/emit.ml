#2 "asmcomp/power/emit.ml"
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

(* Emission of PowerPC assembly code *)

open Cmm
open Specifics
open Arch
open Proc
open Reg
open Mach
open Linear
open Emitaux

(* Reserved space at bottom of stack *)

let reserved_stack_space =
  match abi with
  | ELF32 -> 0
  | ELF64v1 -> 48
  | ELF64v2 -> 32

(* Layout of the stack.  The stack is kept 16-aligned. *)

let stack_offset = ref 0

let num_stack_slots = Array.make Proc.num_register_classes 0

let prologue_required = ref false

let contains_calls = ref false

let frame_size () =
  let size =
    reserved_stack_space +
    !stack_offset +                     (* Trap frame, outgoing parameters *)
    size_int * num_stack_slots.(0) +    (* Local int variables *)
    size_float * num_stack_slots.(1) +  (* Local float variables *)
    (if !contains_calls && abi = ELF32 then size_int else 0) in
                                        (* The return address *)
  Misc.align size 16

let slot_offset loc cls =
  match loc with
    Local n ->
      reserved_stack_space + !stack_offset +
      (if cls = 0 then num_stack_slots.(1) * size_float + n * size_int
                  else n * size_float)
  | Incoming n -> frame_size() + reserved_stack_space + n
  | Outgoing n -> reserved_stack_space + n

let retaddr_offset () =
  match abi with
  | ELF32 -> frame_size() - size_addr
  | ELF64v1 | ELF64v2 -> frame_size() + 16

let toc_save_offset () =
  match abi with
  | ELF32 -> assert false
  | ELF64v1 | ELF64v2 -> frame_size() + 8

let (trap_size, trap_handler_offset, trap_previous_offset) =
  match abi with
  | ELF32 -> (16, 0, 4)
  | ELF64v1 -> (32, 56, 64)
  | ELF64v2 -> (32, 40, 48)

(* Output a symbol *)

let emit_symbol s = Emitaux.emit_symbol '.' s

(* Output a label *)

let label_prefix = ".L"

let emit_label lbl =
  emit_string label_prefix; emit_int lbl

(* Section switching *)

let code_space =
  "	.section \".text\"\n"

let function_descr_space =
  match abi with
  | ELF32 -> code_space
  | ELF64v1 -> "	.section \".opd\",\"aw\"\n"
  | ELF64v2 -> code_space

let data_space =
  "	.section \".data\"\n"

let rodata_space =
  "	.section \".rodata\"\n"

let toc_space =
  " .section \".toc\",\"aw\"\n"

(* Names of instructions that differ in 32 and 64-bit modes *)

let lg = if ppc64 then "ld" else "lwz"
let stg = if ppc64 then "std" else "stw"
let lwa = if ppc64 then "lwa" else "lwz"
let cmpg = if ppc64 then "cmpd" else "cmpw"
let cmplg = if ppc64 then "cmpld" else "cmplw"
let datag = if ppc64 then ".quad" else ".long"
let mullg = if ppc64 then "mulld" else "mullw"
let divg = if ppc64 then "divd" else "divw"
let tglle = if ppc64 then "tdlle" else "twlle"

(* Output a processor register *)

let emit_gpr = emit_int

(* Output a pseudo-register *)

let emit_reg r =
  match r.loc with
  | Reg r -> emit_string (register_name r)
  | _ -> Misc.fatal_error "Emit.emit_reg"

(* Output a stack reference *)

let emit_stack r =
  match r.loc with
  | Stack s ->
      let ofs = slot_offset s (register_class r) in `{emit_int ofs}(1)`
  | _ -> Misc.fatal_error "Emit.emit_stack"

(* Output the name of a symbol plus an optional offset *)

let emit_symbol_offset (s, d) =
  emit_symbol s;
  if d > 0 then `+`;
  if d <> 0 then emit_int d

(* Split a 32-bit integer constants in two 16-bit halves *)

let low_high_u n = (n land 0xFFFF, n asr 16)
  (* unsigned low half, for use with "ori" *)

let native_low_high_u n =
  (Nativeint.(to_int (logand n 0xFFFFn)),
   Nativeint.(to_int (shift_right n 16)))
  (* unsigned low half, for use with "ori" *)

let low_high_s n =
  let lo = ((n + 0x8000) land 0xFFFF) - 0x8000 in
  (lo, (n - lo) asr 16)
  (* signed low half, for use with "addi" *)

let native_low_high_s n =
  let lo = Nativeint.(sub (logand (add n 0x8000n) 0xFFFFn) 0x8000n) in
  (Nativeint.to_int lo,
   Nativeint.(to_int (shift_right (sub n lo) 16)))
  (* signed low half, for use with "addi" *)

let is_immediate n =
  n <= 32767 && n >= -32768

let is_native_immediate n =
  n <= 32767n && n >= -32768n

(* Record TOC entries *)

type tocentry =
  | TocSym of string
  | TocLabel of int
  | TocInt of nativeint
  | TocFloat of int64

let tocref_entries : (tocentry, label) Hashtbl.t = Hashtbl.create 64

let emit_tocentry = function
  | TocSym s -> emit_symbol s
  | TocInt i -> emit_nativeint i
  | TocFloat f -> emit_printf "0x%Lx # %.12g" f (Int64.float_of_bits f)
  | TocLabel lbl -> emit_label lbl

let label_for_tocref entry =
  try
    Hashtbl.find tocref_entries entry
  with Not_found ->
    let lbl = new_label() in
    Hashtbl.add tocref_entries entry lbl;
    lbl

let emit_toctable () =
  Hashtbl.iter
    (fun entry lbl ->
      `{emit_label lbl}:	.quad	{emit_tocentry entry}\n`)
    tocref_entries

(* Emit a load from a TOC entry.

   The [dest] should not be r0, since [dest] is used as the index register for a
   ld instruction, but r0 reads as zero when used as an index register.
*)
let emit_tocload emit_dest dest entry =
  let lbl = label_for_tocref entry in
  if !big_toc || !Clflags.for_package <> None then begin
    `	addis	{emit_dest dest}, 2, {emit_label lbl}@toc@ha\n`;
    `	ld	{emit_dest dest}, {emit_label lbl}@toc@l({emit_dest dest}) # {emit_tocentry entry}\n`
  end else begin
    `	ld	{emit_dest dest}, {emit_label lbl}@toc(2) # {emit_tocentry entry}\n`
  end

(* Output a "upper 16 bits" or "lower 16 bits" operator. *)

let emit_upper emit_fun arg =
  emit_fun arg; emit_string "@ha"

let emit_lower emit_fun arg =
  emit_fun arg; emit_string "@l"

(* Output a load or store operation *)

let valid_offset instr ofs =
  ofs land 3 = 0 || (instr <> "ld" && instr <> "std" && instr <> "lwa")

let emit_load_store instr addressing_mode addr n arg =
  match addressing_mode with
  | Ibased(s, d) ->
      begin match abi with
      | ELF32 ->
        `	addis	11, 0, {emit_upper emit_symbol_offset (s,d)}\n`;
        `	{emit_string instr}	{emit_reg arg}, {emit_lower emit_symbol_offset (s,d)}(11)\n`
      | ELF64v1 | ELF64v2 ->
        emit_tocload emit_gpr 11 (TocSym s);
        let (lo, hi) = low_high_s d in
        if hi <> 0 then
          `	addis	11, 11, {emit_int hi}\n`;
        `	{emit_string instr}	{emit_reg arg}, {emit_int lo}(11)\n`
      end
  | Iindexed ofs ->
      if is_immediate ofs && valid_offset instr ofs then
        `	{emit_string instr}	{emit_reg arg}, {emit_int ofs}({emit_reg addr.(n)})\n`
      else begin
        let (lo, hi) = low_high_u ofs in
        `	addis	0, 0, {emit_int hi}\n`;
        if lo <> 0 then
          `	ori	0, 0, {emit_int lo}\n`;
        `	{emit_string instr}x	{emit_reg arg}, {emit_reg addr.(n)}, 0\n`
      end
  | Iindexed2 ->
      `	{emit_string instr}x	{emit_reg arg}, {emit_reg addr.(n)}, {emit_reg addr.(n+1)}\n`

(* After a comparison, extract the result as 0 or 1 *)

let emit_set_comp cmp res =
  `	mfcr	0\n`;
  let bitnum =
    match cmp with
      Ceq | Cne -> 2
    | Cgt | Cle -> 1
    | Clt | Cge -> 0 in
`	rlwinm	{emit_reg res}, 0, {emit_int(bitnum+1)}, 31, 31\n`;
  begin match cmp with
    Cne | Cle | Cge -> `	xori	{emit_reg res}, {emit_reg res}, 1\n`
  | _ -> ()
  end

(* Free the stack frame *)

let emit_free_frame () =
  let n = frame_size() in
  if n > 0 then
    `	addi	1, 1, {emit_int n}\n`

(* Emit a "bl" instruction to a given symbol *)

let emit_call s =
  match abi with
  | ELF32 when !Clflags.dlcode || !Clflags.pic_code ->
    `	bl	{emit_symbol s}@plt\n`
  | _ ->
    `	bl	{emit_symbol s}\n`

(* Add a nop after a "bl" call for ELF64 *)

let emit_call_nop () =
  match abi with
  | ELF32 -> ()
  | ELF64v1 | ELF64v2 -> `	nop	\n`

(* Reload the TOC register r2 from the value saved on the stack *)

let emit_reload_toc () =
  `	ld	2, {emit_int (toc_save_offset())}(1)\n`

(* Adjust stack_offset and emit corresponding CFI directive *)

let adjust_stack_offset delta =
  stack_offset := !stack_offset + delta;
  cfi_adjust_cfa_offset delta

(* Record live pointers at call points *)

let record_frame ?label live dbg =
  let lbl =
    match label with
    | None -> new_label()
    | Some label -> label
  in
  let live_offset = ref [] in
  Reg.Set.iter
    (function
      | {typ = Val; loc = Reg r} ->
          live_offset := ((r lsl 1) + 1) :: !live_offset
      | {typ = Val; loc = Stack s} as reg ->
          live_offset := slot_offset s (register_class reg) :: !live_offset
      | {typ = Addr} as r ->
          Misc.fatal_error ("bad GC root " ^ Reg.name r)
      | _ -> ())
    live;
  record_frame_descr ~label:lbl ~frame_size:(frame_size())
    ~live_offset:!live_offset dbg;
  `{emit_label lbl}:\n`

(* Record floating-point literals (for PPC32) *)

let float_literals = ref ([] : (int64 * int) list)

(* Record jump tables (for PPC64).  In order to reduce the size of the TOC,
   we concatenate all jumptables and emit them at the end of the compilation
   unit. *)

let jumptables = ref ([] : label list)  (* in reverse order *)
let jumptables_lbl = ref (-1)

(* Names for conditional branches after comparisons *)

let branch_for_comparison = function
    Ceq -> "beq" | Cne -> "bne"
  | Cle -> "ble" | Cgt -> "bgt"
  | Cge -> "bge" | Clt -> "blt"

let name_for_int_comparison = function
    Isigned cmp -> (cmpg, branch_for_comparison cmp)
  | Iunsigned cmp -> (cmplg, branch_for_comparison cmp)

(* Names for various instructions *)

let name_for_intop = function
    Iadd  -> "add"
  | Imul  -> if ppc64 then "mulld" else "mullw"
  | Imulh -> if ppc64 then "mulhd" else "mulhw"
  | Idiv  -> if ppc64 then "divd" else "divw"
  | Iand  -> "and"
  | Ior   -> "or"
  | Ixor  -> "xor"
  | Ilsl  -> if ppc64 then "sld" else "slw"
  | Ilsr  -> if ppc64 then "srd" else "srw"
  | Iasr  -> if ppc64 then "srad" else "sraw"
  | _ -> Misc.fatal_error "Emit.Intop"

let name_for_intop_imm = function
    Iadd -> "addi"
  | Imul -> "mulli"
  | Iand -> "andi."
  | Ior  -> "ori"
  | Ixor -> "xori"
  | Ilsl -> if ppc64 then "sldi" else "slwi"
  | Ilsr -> if ppc64 then "srdi" else "srwi"
  | Iasr -> if ppc64 then "sradi" else "srawi"
  | _ -> Misc.fatal_error "Emit.Intop_imm"

let name_for_floatop1 = function
    Inegf -> "fneg"
  | Iabsf -> "fabs"
  | _ -> Misc.fatal_error "Emit.Iopf1"

let name_for_floatop2 = function
    Iaddf -> "fadd"
  | Isubf -> "fsub"
  | Imulf -> "fmul"
  | Idivf -> "fdiv"
  | _ -> Misc.fatal_error "Emit.Iopf2"

let name_for_specific = function
    Imultaddf -> "fmadd"
  | Imultsubf -> "fmsub"
  | _ -> Misc.fatal_error "Emit.Ispecific"

(* Name of current function *)
let function_name = ref ""
(* Entry point for tail recursive calls *)
let tailrec_entry_point = ref 0
(* Label of glue code for calling the GC *)
let call_gc_label = ref 0

(* Relaxation of branches that exceed the span of a relative branch. *)

module BR = Branch_relaxation.Make (struct
  type distance = int

  module Cond_branch = struct
    type t = Branch

    let all = [Branch]

    let max_displacement = function
      (* 14-bit signed offset in words. *)
      | Branch -> 8192

    let classify_instr = function
      | Lop (Ialloc _)
      (* [Ialloc_far] does not need to be here, since its code sequence
         never involves any conditional branches that might need relaxing. *)
      | Lcondbranch _
      | Lcondbranch3 _ -> Some Branch
      | _ -> None
  end

  let offset_pc_at_branch = 1

  let size =
    match abi with
    | ELF32 -> (fun a _ _ -> a)
    | ELF64v1 -> (fun _ b _ -> b)
    | ELF64v2 -> (fun _ _ c -> c)

  let profiling_prologue_size () =
    match abi with
    | ELF32 -> 5
    | ELF64v1 | ELF64v2 -> 6

  let prologue_size () =
    profiling_prologue_size ()
      + (if frame_size () > 0 then 1 else 0)
      + (if !contains_calls then
           2 +
             match abi with
             | ELF32 -> 0
             | ELF64v1 | ELF64v2 -> 1
         else 0)

  let tocload_size() =
    if !big_toc || !Clflags.for_package <> None then 2 else 1

  let load_store_size = function
    | Ibased(_s, d) ->
        if abi = ELF32 then 2 else begin
          let (_lo, hi) = low_high_s d in
          tocload_size() + (if hi = 0 then 1 else 2)
        end
    | Iindexed ofs -> if is_immediate ofs then 1 else 3
    | Iindexed2 -> 1

  let instr_size = function
    | Lend -> 0
    | Lprologue -> prologue_size ()
    | Lop(Imove | Ispill | Ireload) -> 1
    | Lop(Iconst_int n) ->
      if is_native_immediate n then 1
      else if (let (_lo, hi) = native_low_high_s n in
               hi >= -0x8000 && hi <= 0x7FFF) then 2
      else if (let (_lo, hi) = native_low_high_u n in
               hi >= -0x8000 && hi <= 0x7FFF) then 2
      else tocload_size()
    | Lop(Iconst_float _) -> if abi = ELF32 then 2 else tocload_size()
    | Lop(Iconst_symbol _) -> if abi = ELF32 then 2 else tocload_size()
    | Lop(Icall_ind _) -> size 2 5 4
    | Lop(Icall_imm _) -> size 1 3 3
    | Lop(Itailcall_ind _) -> size 5 7 6
    | Lop(Itailcall_imm { func; _ }) ->
        if func = !function_name
        then 1
        else size 4 (7 + tocload_size()) (6 + tocload_size())
    | Lop(Iextcall { alloc = true; _ }) ->
      size 3 (2 + tocload_size()) (2 + tocload_size())
    | Lop(Iextcall { alloc = false; _}) -> size 1 2 2
    | Lop(Istackoffset _) -> 1
    | Lop(Iload(chunk, addr)) ->
      if chunk = Byte_signed
      then load_store_size addr + 1
      else load_store_size addr
    | Lop(Istore(_chunk, addr, _)) -> load_store_size addr
    | Lop(Ialloc _) -> 4
    | Lop(Ispecific(Ialloc_far _)) -> 5
    | Lop(Iintop Imod) -> 3
    | Lop(Iintop(Icomp _)) -> 4
    | Lop(Iintop _) -> 1
    | Lop(Iintop_imm(Icomp _, _)) -> 4
    | Lop(Iintop_imm _) -> 1
    | Lop(Inegf | Iabsf | Iaddf | Isubf | Imulf | Idivf) -> 1
    | Lop(Ifloatofint) -> 9
    | Lop(Iintoffloat) -> 4
    | Lop(Ispecific _) -> 1
    | Lop (Iname_for_debugger _) -> 0
    | Lreloadretaddr -> 2
    | Lreturn -> 2
    | Llabel _ -> 0
    | Lbranch _ -> 1
    | Lcondbranch _ -> 2
    | Lcondbranch3(lbl0, lbl1, lbl2) ->
      1 + (if lbl0 = None then 0 else 1)
        + (if lbl1 = None then 0 else 1)
        + (if lbl2 = None then 0 else 1)
    | Lswitch _ -> size 7 (5 + tocload_size()) (5 + tocload_size())
    | Lentertrap -> size 0 (tocload_size()) (tocload_size())
    | Ladjust_trap_depth _ -> 0
    | Lpushtrap _ -> size 5 (4 + tocload_size()) (4 + tocload_size())
    | Lpoptrap -> 2
    | Lraise _ -> 6

  let relax_allocation ~num_bytes:bytes ~label_after_call_gc ~dbginfo =
    Lop (Ispecific (Ialloc_far { bytes; label_after_call_gc; dbginfo }))

  (* [classify_addr], above, never identifies these instructions as needing
     relaxing.  As such, these functions should never be called. *)
  let relax_specific_op _ = assert false
  let relax_intop_checkbound ~label_after_error:_ = assert false
  let relax_intop_imm_checkbound ~bound:_ ~label_after_error:_ = assert false
end)

(* Output the assembly code for an instruction *)

let emit_instr i =
    emit_debug_info i.dbg;
    match i.desc with
    | Lend -> ()
    | Lprologue ->
      assert (!prologue_required);
      let n = frame_size() in
      if n > 0 then begin
        `	addi	1, 1, {emit_int(-n)}\n`;
        cfi_adjust_cfa_offset n
      end;
      if !contains_calls then begin
        let ra = retaddr_offset() in
        `	mflr	0\n`;
        `	{emit_string stg}	0, {emit_int ra}(1)\n`;
        cfi_offset ~reg: 65 (* LR *) ~offset: (ra - n);
        match abi with
        | ELF32 -> ()
        | ELF64v1 | ELF64v2 ->
          `	std	2, {emit_int(toc_save_offset())}(1)\n`
      end
    | Lop(Imove | Ispill | Ireload) ->
        let src = i.arg.(0) and dst = i.res.(0) in
        if src.loc <> dst.loc then begin
           match (src, dst) with
           |  {loc = Reg _; typ = (Val | Int | Addr)}, {loc = Reg _} ->
                `	mr	{emit_reg dst}, {emit_reg src}\n`
            | {loc = Reg _; typ = Float}, {loc = Reg _; typ = Float} ->
                `	fmr	{emit_reg dst}, {emit_reg src}\n`
            | {loc = Reg _; typ = (Val | Int | Addr)}, {loc = Stack _} ->
                `	{emit_string stg}	{emit_reg src}, {emit_stack dst}\n`
            | {loc = Reg _; typ = Float}, {loc = Stack _} ->
                `	stfd	{emit_reg src}, {emit_stack dst}\n`
            | {loc = Stack _; typ = (Val | Int | Addr)}, {loc = Reg _} ->
                `	{emit_string lg}	{emit_reg dst}, {emit_stack src}\n`
            | {loc = Stack _; typ = Float}, {loc = Reg _} ->
                `	lfd	{emit_reg dst}, {emit_stack src}\n`
            | (_, _) ->
                Misc.fatal_error "Emit: Imove"
        end
    | Lop(Iconst_int n) ->
        if is_native_immediate n then
          `	li	{emit_reg i.res.(0)}, {emit_nativeint n}\n`
        else begin
        (* Try a signed decomposition first, because the sequence
           addis/addi is eligible for instruction fusion. *)
        let (lo, hi) = native_low_high_s n in
        if hi >= -0x8000 && hi <= 0x7FFF then begin
          `	addis	{emit_reg i.res.(0)}, 0, {emit_int hi}\n`;
          if lo <> 0 then
          `	addi	{emit_reg i.res.(0)}, {emit_reg i.res.(0)}, {emit_int lo}\n`
        end else begin
        (* Now try an unsigned decomposition *)
        let (lo, hi) = native_low_high_u n in
        if hi >= -0x8000 && hi <= 0x7FFF then begin
          `	addis	{emit_reg i.res.(0)}, 0, {emit_int hi}\n`;
          if lo <> 0 then
          `	ori	{emit_reg i.res.(0)}, {emit_reg i.res.(0)}, {emit_int lo}\n`
        end else begin
          match abi with
          | ELF32 -> assert false
          | ELF64v1 | ELF64v2 ->
              emit_tocload emit_reg i.res.(0) (TocInt n)
        end end end
    | Lop(Iconst_float f) ->
        begin match abi with
        | ELF32 ->
          let lbl = new_label() in
          float_literals := (f, lbl) :: !float_literals;
          `	addis	11, 0, {emit_upper emit_label lbl}\n`;
          `	lfd	{emit_reg i.res.(0)}, {emit_lower emit_label lbl}(11)\n`
        | ELF64v1 | ELF64v2 ->
          let entry = TocFloat f in
          let lbl = label_for_tocref entry in
          if !big_toc || !Clflags.for_package <> None then begin
            `	addis	11, 2, {emit_label lbl}@toc@ha\n`;
            `	lfd	{emit_reg i.res.(0)}, {emit_label lbl}@toc@l(11) # {emit_tocentry entry}\n`
          end else begin
            `	lfd	{emit_reg i.res.(0)}, {emit_label lbl}@toc(2) # {emit_tocentry entry}\n`
          end
        end
    | Lop(Iconst_symbol s) ->
        begin match abi with
        | ELF32 ->
          `	addis	{emit_reg i.res.(0)}, 0, {emit_upper emit_symbol s}\n`;
          `	addi	{emit_reg i.res.(0)}, {emit_reg i.res.(0)}, {emit_lower emit_symbol s}\n`
        | ELF64v1 | ELF64v2 ->
          emit_tocload emit_reg i.res.(0) (TocSym s)
        end
    | Lop(Icall_ind { label_after; }) ->
        begin match abi with
        | ELF32 ->
          `	mtctr	{emit_reg i.arg.(0)}\n`;
          `	bctrl\n`;
          record_frame i.live (Dbg_other i.dbg) ~label:label_after
        | ELF64v1 ->
          `	ld	0, 0({emit_reg i.arg.(0)})\n`;  (* code pointer *)
          `	mtctr	0\n`;
          `	ld	2, 8({emit_reg i.arg.(0)})\n`;  (* TOC for callee *)
          `	bctrl\n`;
          record_frame i.live (Dbg_other i.dbg) ~label:label_after;
          emit_reload_toc()
        | ELF64v2 ->
          `	mtctr	{emit_reg i.arg.(0)}\n`;
          `	mr	12, {emit_reg i.arg.(0)}\n`;  (* addr of fn in r12 *)
          `	bctrl\n`;
          record_frame i.live (Dbg_other i.dbg) ~label:label_after;
          emit_reload_toc()
        end
    | Lop(Icall_imm { func; label_after; }) ->
        begin match abi with
        | ELF32 ->
            emit_call func;
            record_frame i.live (Dbg_other i.dbg) ~label:label_after
        | ELF64v1 | ELF64v2 ->
        (* For PPC64, we cannot just emit a "bl s; nop" sequence, because
           of the following scenario:
              - current function f1 calls f2 that has the same TOC
              - f2 tailcalls f3 that has a different TOC
           Because f1 and f2 have the same TOC, the linker inserted no
           code in f1 to save and restore r2 around the call to f2.
           Because f2 tailcalls f3, r2 will not be restored to f2's TOC
           when f3 returns.  So, we're back into f1, with the wrong TOC in r2.
           We have two options:
             1- Turn the call into an indirect call, like we do for
                Itailcall_imm.  Cost: 6 instructions.
             2- Follow the "bl" with an instruction to restore r2
                explicitly.  If the called function has a different TOC,
                this instruction is redundant with those inserted
                by the linker, but this is harmless.
                Cost: 3 instructions if same TOC, 7 if different TOC.
           Let's try option 2. *)
            emit_call func;
            record_frame i.live (Dbg_other i.dbg) ~label:label_after;
            `	nop\n`;
            emit_reload_toc()
        end
    | Lop(Itailcall_ind { label_after = _; }) ->
        begin match abi with
        | ELF32 ->
          `	mtctr	{emit_reg i.arg.(0)}\n`
        | ELF64v1 ->
          `	ld	0, 0({emit_reg i.arg.(0)})\n`;  (* code pointer *)
          `	mtctr	0\n`;
          `	ld	2, 8({emit_reg i.arg.(0)})\n`   (* TOC for callee *)
        | ELF64v2 ->
          `	mtctr	{emit_reg i.arg.(0)}\n`;
          `	mr	12, {emit_reg i.arg.(0)}\n`   (* addr of fn in r12 *)
        end;
        if !contains_calls then begin
          `	{emit_string lg}	11, {emit_int(retaddr_offset())}(1)\n`;
          `	mtlr	11\n`
        end;
        emit_free_frame();
        `	bctr\n`
    | Lop(Itailcall_imm { func; label_after = _; }) ->
        if func = !function_name then
          `	b	{emit_label !tailrec_entry_point}\n`
        else begin
          begin match abi with
          | ELF32 ->
            ()
          | ELF64v1 ->
            emit_tocload emit_gpr 11 (TocSym func);
            `	ld	0, 0(11)\n`;  (* code pointer *)
            `	mtctr	0\n`;
            `	ld	2, 8(11)\n`   (* TOC for callee *)
          | ELF64v2 ->
            emit_tocload emit_gpr 12 (TocSym func); (* addr of fn must be in r12 *)
            `	mtctr	12\n`
          end;
          if !contains_calls then begin
            `	{emit_string lg}	11, {emit_int(retaddr_offset())}(1)\n`;
            `	mtlr	11\n`
          end;
          emit_free_frame();
          begin match abi with
          | ELF32 ->
            `	b	{emit_symbol func}\n`
          | ELF64v1 | ELF64v2 ->
            `	bctr\n`
          end
        end
    | Lop(Iextcall { func; alloc; }) ->
        if not alloc then begin
          emit_call func;
          emit_call_nop()
        end else begin
          match abi with
          | ELF32 ->
            `	addis	25, 0, {emit_upper emit_symbol func}\n`;
            `	addi	25, 25, {emit_lower emit_symbol func}\n`;
            emit_call "caml_c_call";
            record_frame i.live (Dbg_other i.dbg)
          | ELF64v1 | ELF64v2 ->
            emit_tocload emit_gpr 25 (TocSym func);
            emit_call "caml_c_call";
            record_frame i.live (Dbg_other i.dbg);
            `	nop\n`
        end
    | Lop(Istackoffset n) ->
        `	addi	1, 1, {emit_int (-n)}\n`;
        adjust_stack_offset n
    | Lop(Iload(chunk, addr)) ->
        let loadinstr =
          match chunk with
          | Byte_unsigned -> "lbz"
          | Byte_signed -> "lbz"
          | Sixteen_unsigned -> "lhz"
          | Sixteen_signed -> "lha"
          | Thirtytwo_unsigned -> "lwz"
          | Thirtytwo_signed -> if ppc64 then "lwa" else "lwz"
	  | Word_int | Word_val -> lg
          | Single -> "lfs"
          | Double | Double_u -> "lfd" in
        emit_load_store loadinstr addr i.arg 0 i.res.(0);
        if chunk = Byte_signed then
          `	extsb	{emit_reg i.res.(0)}, {emit_reg i.res.(0)}\n`
    | Lop(Istore(chunk, addr, _)) ->
        let storeinstr =
          match chunk with
          | Byte_unsigned | Byte_signed -> "stb"
          | Sixteen_unsigned | Sixteen_signed -> "sth"
	  | Thirtytwo_unsigned | Thirtytwo_signed -> "stw"
	  | Word_int | Word_val -> stg
          | Single -> "stfs"
          | Double | Double_u -> "stfd" in
        emit_load_store storeinstr addr i.arg 1 i.arg.(0)
    | Lop(Ialloc { bytes = n; label_after_call_gc; dbginfo }) ->
        if !call_gc_label = 0 then begin
          match label_after_call_gc with
          | None -> call_gc_label := new_label ()
          | Some label -> call_gc_label := label
        end;
        `	addi    31, 31, {emit_int(-n)}\n`;
        `	{emit_string cmplg}	31, 30\n`;
        `	bltl	{emit_label !call_gc_label}\n`;
        record_frame i.live (Dbg_alloc dbginfo);
        `	addi	{emit_reg i.res.(0)}, 31, {emit_int size_addr}\n`;
    | Lop(Ispecific(Ialloc_far { bytes = n; label_after_call_gc; dbginfo })) ->
        if !call_gc_label = 0 then begin
          match label_after_call_gc with
          | None -> call_gc_label := new_label ()
          | Some label -> call_gc_label := label
        end;
        let lbl = new_label() in
        `	addi    31, 31, {emit_int(-n)}\n`;
        `	{emit_string cmplg}	31, 30\n`;
        `	bge	{emit_label lbl}\n`;
        `	bl	{emit_label !call_gc_label}\n`;
        record_frame i.live (Dbg_alloc dbginfo);
        `{emit_label lbl}:	addi	{emit_reg i.res.(0)}, 31, {emit_int size_addr}\n`
    | Lop(Iintop Isub) ->               (* subfc has swapped arguments *)
        `	subfc	{emit_reg i.res.(0)}, {emit_reg i.arg.(1)}, {emit_reg i.arg.(0)}\n`
    | Lop(Iintop Imod) ->
        `	{emit_string divg}	0, {emit_reg i.arg.(0)}, {emit_reg i.arg.(1)}\n`;
        `	{emit_string mullg}	0, 0, {emit_reg i.arg.(1)}\n`;
        `	subfc	{emit_reg i.res.(0)}, 0, {emit_reg i.arg.(0)}\n`
    | Lop(Iintop(Icomp cmp)) ->
        begin match cmp with
          Isigned c ->
            `	{emit_string cmpg}	{emit_reg i.arg.(0)}, {emit_reg i.arg.(1)}\n`;
            emit_set_comp c i.res.(0)
        | Iunsigned c ->
            `	{emit_string cmplg}	{emit_reg i.arg.(0)}, {emit_reg i.arg.(1)}\n`;
            emit_set_comp c i.res.(0)
        end
    | Lop(Iintop (Icheckbound { label_after_error; })) ->
        if !Clflags.debug then
          record_frame Reg.Set.empty (Dbg_other i.dbg) ?label:label_after_error;
        `	{emit_string tglle}   {emit_reg i.arg.(0)}, {emit_reg i.arg.(1)}\n`
    | Lop(Iintop op) ->
        let instr = name_for_intop op in
        `	{emit_string instr}	{emit_reg i.res.(0)}, {emit_reg i.arg.(0)}, {emit_reg i.arg.(1)}\n`
    | Lop(Iintop_imm(Isub, n)) ->
        `	addi	{emit_reg i.res.(0)}, {emit_reg i.arg.(0)}, {emit_int(-n)}\n`
    | Lop(Iintop_imm(Icomp cmp, n)) ->
        begin match cmp with
          Isigned c ->
            `	{emit_string cmpg}i	{emit_reg i.arg.(0)}, {emit_int n}\n`;
            emit_set_comp c i.res.(0)
        | Iunsigned c ->
            `	{emit_string cmplg}i	{emit_reg i.arg.(0)}, {emit_int n}\n`;
            emit_set_comp c i.res.(0)
        end
    | Lop(Iintop_imm(Icheckbound { label_after_error; }, n)) ->
        if !Clflags.debug then
          record_frame Reg.Set.empty (Dbg_other i.dbg) ?label:label_after_error;
        `	{emit_string tglle}i   {emit_reg i.arg.(0)}, {emit_int n}\n`
    | Lop(Iintop_imm(op, n)) ->
        let instr = name_for_intop_imm op in
        `	{emit_string instr}	{emit_reg i.res.(0)}, {emit_reg i.arg.(0)}, {emit_int n}\n`
    | Lop(Inegf | Iabsf as op) ->
        let instr = name_for_floatop1 op in
        `	{emit_string instr}	{emit_reg i.res.(0)}, {emit_reg i.arg.(0)}\n`
    | Lop(Iaddf | Isubf | Imulf | Idivf as op) ->
        let instr = name_for_floatop2 op in
        `	{emit_string instr}	{emit_reg i.res.(0)}, {emit_reg i.arg.(0)}, {emit_reg i.arg.(1)}\n`
    | Lop(Ifloatofint) ->
	if ppc64 then begin
          (* Can use protected zone (288 bytes below r1 *)
	  `	std	{emit_reg i.arg.(0)}, -16(1)\n`;
          `	lfd	{emit_reg i.res.(0)}, -16(1)\n`;
          `	fcfid	{emit_reg i.res.(0)}, {emit_reg i.res.(0)}\n`
	end else begin
          let lbl = new_label() in
          float_literals := (0x4330000080000000L, lbl) :: !float_literals;
          `	addis	11, 0, {emit_upper emit_label lbl}\n`;
          `	lfd	0, {emit_lower emit_label lbl}(11)\n`;
          `	lis	0, 0x4330\n`;
          `	stwu	0, -16(1)\n`;
          `	xoris	0, {emit_reg i.arg.(0)}, 0x8000\n`;
          `	stw	0, 4(1)\n`;
          `	lfd	{emit_reg i.res.(0)}, 0(1)\n`;
          `	addi	1, 1, 16\n`;
          `	fsub	{emit_reg i.res.(0)}, {emit_reg i.res.(0)}, 0\n`
	end
    | Lop(Iintoffloat) ->
        if ppc64 then begin
          (* Can use protected zone (288 bytes below r1 *)
          `	fctidz	0, {emit_reg i.arg.(0)}\n`;
          `	stfd	0, -16(1)\n`;
          `	ld	{emit_reg i.res.(0)}, -16(1)\n`
        end else begin
          `	fctiwz	0, {emit_reg i.arg.(0)}\n`;
          `	stfdu	0, -16(1)\n`;
          `	lwz	{emit_reg i.res.(0)}, 4(1)\n`;
          `	addi	1, 1, 16\n`
        end
    | Lop(Ispecific sop) ->
        let instr = name_for_specific sop in
        `	{emit_string instr}	{emit_reg i.res.(0)}, {emit_reg i.arg.(0)}, {emit_reg i.arg.(1)}, {emit_reg i.arg.(2)}\n`
    | Lop (Iname_for_debugger _) -> ()
    | Lreloadretaddr ->
        `	{emit_string lg}	11, {emit_int(retaddr_offset())}(1)\n`;
        `	mtlr	11\n`
    | Lreturn ->
        emit_free_frame();
        `	blr\n`
    | Llabel lbl ->
        `{emit_label lbl}:\n`
    | Lbranch lbl ->
        `	b	{emit_label lbl}\n`
    | Lcondbranch(tst, lbl) ->
        begin match tst with
          Itruetest ->
            `	{emit_string cmpg}i	{emit_reg i.arg.(0)}, 0\n`;
            `	bne	{emit_label lbl}\n`
        | Ifalsetest ->
            `	{emit_string cmpg}i	{emit_reg i.arg.(0)}, 0\n`;
            `	beq	{emit_label lbl}\n`
        | Iinttest cmp ->
            let (comp, branch) = name_for_int_comparison cmp in
            `	{emit_string comp}	{emit_reg i.arg.(0)}, {emit_reg i.arg.(1)}\n`;
            `	{emit_string branch}	{emit_label lbl}\n`
        | Iinttest_imm(cmp, n) ->
            let (comp, branch) = name_for_int_comparison cmp in
            `	{emit_string comp}i	{emit_reg i.arg.(0)}, {emit_int n}\n`;
            `	{emit_string branch}	{emit_label lbl}\n`
        | Ifloattest cmp -> begin
            `	fcmpu	0, {emit_reg i.arg.(0)}, {emit_reg i.arg.(1)}\n`;
            (* bit 0 = lt, bit 1 = gt, bit 2 = eq *)
            let bitnum =
              match cmp with
              | CFeq | CFneq -> 2
              | CFle | CFnle ->
                `	cror	3, 0, 2\n`; (* lt or eq *)
                3
              | CFgt | CFngt -> 1
              | CFge | CFnge ->
                `	cror	3, 1, 2\n`; (* gt or eq *)
                3
              | CFlt | CFnlt -> 0
            in
            match cmp with
            | CFneq | CFngt | CFnge | CFnlt | CFnle ->
               `	bf	{emit_int bitnum}, {emit_label lbl}\n`
            | CFeq | CFgt | CFge | CFlt | CFle ->
               `	bt	{emit_int bitnum}, {emit_label lbl}\n`
          end
        | Ioddtest ->
            `	andi.	0, {emit_reg i.arg.(0)}, 1\n`;
            `	bne	{emit_label lbl}\n`
        | Ieventest ->
            `	andi.	0, {emit_reg i.arg.(0)}, 1\n`;
            `	beq	{emit_label lbl}\n`
        end
    | Lcondbranch3(lbl0, lbl1, lbl2) ->
        `	{emit_string cmpg}i	{emit_reg i.arg.(0)}, 1\n`;
        begin match lbl0 with
          None -> ()
        | Some lbl -> `	blt	{emit_label lbl}\n`
        end;
        begin match lbl1 with
          None -> ()
        | Some lbl -> `	beq	{emit_label lbl}\n`
        end;
        begin match lbl2 with
          None -> ()
        | Some lbl -> `	bgt	{emit_label lbl}\n`
        end
    | Lswitch jumptbl ->
        let lbl = new_label() in
        if ppc64 then begin
          if !jumptables_lbl < 0 then jumptables_lbl := lbl;
          let start = List.length !jumptables in
          let (start_lo, start_hi) = low_high_s start in
          emit_tocload emit_gpr 11 (TocLabel !jumptables_lbl);
          `	addi	12, {emit_reg i.arg.(0)}, {emit_int start_lo}\n`;
          if start_hi <> 0 then
            `	addis	12, 12, {emit_int start_hi}\n`;
          `	sldi	12, 12, 2\n`
        end else begin
          `	addis	11, 0, {emit_upper emit_label lbl}\n`;
          `	addi	11, 11, {emit_lower emit_label lbl}\n`;
          `	slwi	12, {emit_reg i.arg.(0)}, 2\n`
        end;
        `	{emit_string lwa}x	0, 11, 12\n`;
        `	add	0, 11, 0\n`;
        `	mtctr	0\n`;
        `	bctr\n`;
        if ppc64 then begin
          jumptables := List.rev_append (Array.to_list jumptbl) !jumptables
        end else begin
          emit_string rodata_space;
          `{emit_label lbl}:`;
          for i = 0 to Array.length jumptbl - 1 do
            `	.long	{emit_label jumptbl.(i)} - {emit_label lbl}\n`
          done;
          emit_string code_space
        end
    | Lentertrap ->
        begin match abi with
        | ELF32 -> ()
        | ELF64v1 | ELF64v2 -> emit_reload_toc()
        end
    | Ladjust_trap_depth { delta_traps } ->
        adjust_stack_offset (trap_size * delta_traps)
    | Lpushtrap { lbl_handler; } ->
        begin match abi with
        | ELF32 ->
          `	addis	11, 0, {emit_upper emit_label lbl_handler}\n`;
          `	addi	11, 11, {emit_lower emit_label lbl_handler}\n`;
          `	stwu    11, -16(1)\n`;
          adjust_stack_offset 16;
          `	stw	29, 4(1)\n`;
          `	mr	29, 1\n`
        | ELF64v1 | ELF64v2 ->
          `	addi	1, 1, {emit_int (-trap_size)}\n`;
          adjust_stack_offset trap_size;
          `	std	29, {emit_int trap_previous_offset}(1)\n`;
          emit_tocload emit_gpr 29 (TocLabel lbl_handler);
          `	std     29, {emit_int trap_handler_offset}(1)\n`;
          `	mr	29, 1\n`
          end
    | Lpoptrap ->
        `	{emit_string lg}	29, {emit_int trap_previous_offset}(1)\n`;
        `	addi	1, 1, {emit_int trap_size}\n`;
        adjust_stack_offset (-trap_size)
    | Lraise k ->
        begin match k with
        | Lambda.Raise_regular ->
            `	li	0, 0\n`;
            let backtrace_pos =
              Domainstate.(idx_of_field Domain_backtrace_pos)
            in
            begin match abi with
            | ELF32 -> `	stw	0, {emit_int (backtrace_pos * 8)}(28)\n`
            | _ -> `	std	0, {emit_int (backtrace_pos * 8)}(28)\n`
            end;
            emit_call "caml_raise_exn";
            record_frame Reg.Set.empty (Dbg_raise i.dbg);
            emit_call_nop()
        | Lambda.Raise_reraise ->
            emit_call "caml_raise_exn";
            record_frame Reg.Set.empty (Dbg_raise i.dbg);
            emit_call_nop()
        | Lambda.Raise_notrace ->
            `	{emit_string lg}	0, {emit_int trap_handler_offset}(29)\n`;
            `	mr	1, 29\n`;
            `	mtctr   0\n`;
            `	{emit_string lg}	29, {emit_int trap_previous_offset}(1)\n`;
            `	addi	1, 1, {emit_int trap_size}\n`;
            `	bctr\n`
        end

(* Emit a sequence of instructions *)

let rec emit_all i =
  match i.desc with
  | Lend -> ()
  |  _   -> emit_instr i; emit_all i.next

(* Emission of a function declaration *)

let fundecl fundecl =
  function_name := fundecl.fun_name;
  tailrec_entry_point := fundecl.fun_tailrec_entry_point_label;
  stack_offset := 0;
  call_gc_label := 0;
  float_literals := [];
  jumptables := []; jumptables_lbl := -1;
  for i = 0 to Proc.num_register_classes - 1 do
    num_stack_slots.(i) <- fundecl.fun_num_stack_slots.(i);
  done;
  prologue_required := fundecl.fun_prologue_required;
  contains_calls := fundecl.fun_contains_calls;
  begin match abi with
  | ELF32 ->
    emit_string code_space;
    `	.globl	{emit_symbol fundecl.fun_name}\n`;
    `	.type	{emit_symbol fundecl.fun_name}, @function\n`;
    `	.align	2\n`;
    `{emit_symbol fundecl.fun_name}:\n`
  | ELF64v1 ->
    emit_string function_descr_space;
    `	.align 3\n`;
    `	.globl	{emit_symbol fundecl.fun_name}\n`;
    `	.type   {emit_symbol fundecl.fun_name}, @function\n`;
    `{emit_symbol fundecl.fun_name}:\n`;
    `	.quad .L.{emit_symbol fundecl.fun_name}, .TOC.@tocbase\n`;
    emit_string code_space;
    `	.align  2\n`;
    `.L.{emit_symbol fundecl.fun_name}:\n`
  | ELF64v2 ->
    emit_string code_space;
    `	.globl	{emit_symbol fundecl.fun_name}\n`;
    `	.type	{emit_symbol fundecl.fun_name}, @function\n`;
    `	.align	2\n`;
    `{emit_symbol fundecl.fun_name}:\n`;
    `0:	addis	2, 12, (.TOC. - 0b)@ha\n`;
    `	addi	2, 2, (.TOC. - 0b)@l\n`;
    `	.localentry {emit_symbol fundecl.fun_name}, . - 0b\n`
  end;
  emit_debug_info fundecl.fun_dbg;
  cfi_startproc();
  (* On this target, there is at most one "out of line" code block per
     function: a single "call GC" point.  It comes immediately after the
     function's body. *)
  BR.relax fundecl.fun_body ~max_out_of_line_code_offset:0;
  emit_all fundecl.fun_body;
  (* Emit the glue code to call the GC *)
  if !call_gc_label > 0 then begin
    `{emit_label !call_gc_label}:\n`;
    match abi with
    | ELF32 ->
      `	b	{emit_symbol "caml_call_gc"}\n`
    | ELF64v1 ->
      `	std	2, 40(1)\n`;
             (* save our TOC, will be restored by caml_call_gc *)
      emit_tocload emit_gpr 11 (TocSym "caml_call_gc");
      `	ld	0, 0(11)\n`;
      `	mtctr	0\n`;
      `	ld	2, 8(11)\n`;
      `	bctr\n`
    | ELF64v2 ->
      `	std	2, 24(1)\n`;
             (* save our TOC, will be restored by caml_call_gc *)
      emit_tocload emit_gpr 12 (TocSym "caml_call_gc");
      `	mtctr	12\n`;
      `	bctr\n`
  end;
  cfi_endproc();
  begin match abi with
  | ELF32 | ELF64v2 ->
    `	.size	{emit_symbol fundecl.fun_name}, . - {emit_symbol fundecl.fun_name}\n`
  | ELF64v1 ->
    `	.size	{emit_symbol fundecl.fun_name}, . - .L.{emit_symbol fundecl.fun_name}\n`
  end;
  (* Emit the numeric literals *)
  if !float_literals <> [] then begin
    emit_string rodata_space;
    `	.align	3\n`;
    List.iter
      (fun (f, lbl) ->
        `{emit_label lbl}:`;
        emit_float64_split_directive ".long" f)
      !float_literals
  end;
  (* Emit the jump tables *)
  if !jumptables <> [] then begin
    emit_string rodata_space;
    `	.align	2\n`;
    `{emit_label !jumptables_lbl}:`;
    List.iter
      (fun  lbl ->
          `	.long	{emit_label lbl} - {emit_label !jumptables_lbl}\n`)
      (List.rev !jumptables)
  end

(* Emission of data *)

let declare_global_data s =
  `	.globl	{emit_symbol s}\n`;
  `	.type	{emit_symbol s}, @object\n`

let emit_item = function
    Cglobal_symbol s ->
      declare_global_data s
  | Cdefine_symbol s ->
      `{emit_symbol s}:\n`;
  | Cint8 n ->
      `	.byte	{emit_int n}\n`
  | Cint16 n ->
      `	.short	{emit_int n}\n`
  | Cint32 n ->
      `	.long	{emit_nativeint n}\n`
  | Cint n ->
      `	{emit_string datag}	{emit_nativeint n}\n`
  | Csingle f ->
      emit_float32_directive ".long" (Int32.bits_of_float f)
  | Cdouble f ->
      if ppc64
      then emit_float64_directive ".quad" (Int64.bits_of_float f)
      else emit_float64_split_directive ".long" (Int64.bits_of_float f)
  | Csymbol_address s ->
      `	{emit_string datag}	{emit_symbol s}\n`
  | Cstring s ->
      emit_bytes_directive "	.byte	" s
  | Cskip n ->
      if n > 0 then `	.space	{emit_int n}\n`
  | Calign n ->
      `	.align	{emit_int (Misc.log2 n)}\n`

let data l =
  emit_string data_space;
  `	.align  {emit_int (if ppc64 then 3 else 2)}\n`;
  List.iter emit_item l

(* Beginning / end of an assembly file *)

let begin_assembly() =
  reset_debug_info();
  `	.file	\"\"\n`;  (* PR#7037 *)
  begin match abi with
  | ELF64v2 -> `	.abiversion 2\n`
  | _ -> ()
  end;
  Hashtbl.clear tocref_entries;
  (* Emit the beginning of the segments *)
  let lbl_begin = Compilenv.make_symbol (Some "data_begin") in
  emit_string data_space;
  declare_global_data lbl_begin;
  `{emit_symbol lbl_begin}:\n`;
  let lbl_begin = Compilenv.make_symbol (Some "code_begin") in
  emit_string function_descr_space;
  (* For the ELF64v1 ABI, we must make sure that the .opd and .data
     sections are in different pages.  .opd comes after .data,
     so aligning .opd is enough.  To save space, we do it only
     for the startup file, not for every OCaml compilation unit. *)
  let c = Compilenv.current_unit_name() in
  if abi = ELF64v1 && (c = "_startup" || c = "_shared_startup") then begin
    `	.p2align	12\n`
  end;
  declare_global_data lbl_begin;
  `{emit_symbol lbl_begin}:\n`

let end_assembly() =
  (* Emit the end of the segments *)
  emit_string function_descr_space;
  let lbl_end = Compilenv.make_symbol (Some "code_end") in
  declare_global_data lbl_end;
  `{emit_symbol lbl_end}:\n`;
  if abi <> ELF64v1 then `	.long	0\n`;
  emit_string data_space;
  let lbl_end = Compilenv.make_symbol (Some "data_end") in
  declare_global_data lbl_end;
  `	{emit_string datag}	0\n`;  (* PR#6329 *)
  `{emit_symbol lbl_end}:\n`;
  `	{emit_string datag}	0\n`;
  (* Emit the frame descriptors *)
  emit_string data_space;  (* not rodata_space because it contains relocations *)
  if ppc64 then `	.align  3\n`;   (* #7887 *)
  let lbl = Compilenv.make_symbol (Some "frametable") in
  declare_global_data lbl;
  `{emit_symbol lbl}:\n`;
  emit_frames
    { efa_code_label =
         (fun l -> `	{emit_string datag}	{emit_label l}\n`);
      efa_data_label =
         (fun l -> `	{emit_string datag}	{emit_label l}\n`);
      efa_8 = (fun n -> `	.byte	{emit_int n}\n`);
      efa_16 = (fun n -> `	.short	{emit_int n}\n`);
      efa_32 = (fun n -> `	.long	{emit_int32 n}\n`);
      efa_word = (fun n -> `	{emit_string datag}	{emit_int n}\n`);
      efa_align = (fun n -> `	.balign	{emit_int n}\n`);
      efa_label_rel = (fun lbl ofs ->
                           `	.long	({emit_label lbl} - .) + {emit_int32 ofs}\n`);
      efa_def_label = (fun l -> `{emit_label l}:\n`);
      efa_string = (fun s -> emit_bytes_directive "	.byte	" (s ^ "\000"))
     };
  (* Emit the TOC entries *)
  begin match abi with
  | ELF32 -> ()
  | ELF64v1 | ELF64v2 ->
      emit_string toc_space;
      emit_toctable();
      Hashtbl.clear tocref_entries
  end;
  `	.section .note.GNU-stack,\"\",%progbits\n`
