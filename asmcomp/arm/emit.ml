#2 "asmcomp/arm/emit.ml"
(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*                 Benedikt Meurer, University of Siegen                  *)
(*                                                                        *)
(*   Copyright 1998 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*   Copyright 2012 Benedikt Meurer.                                      *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

(* Emission of ARM assembly code *)

open Misc
open Cmm
open Specifics
open Arch
open Proc
open Reg
open Mach
open Linear
open Emitaux

(* Tradeoff between code size and code speed *)

let fastcode_flag = ref true

(* Output a label *)

let emit_label lbl =
  emit_string ".L"; emit_int lbl

(* Symbols *)

let emit_symbol s =
  Emitaux.emit_symbol '$' s

let emit_call s =
  if !Clflags.dlcode || !Clflags.pic_code
  then `bl	{emit_symbol s}(PLT)`
  else `bl	{emit_symbol s}`

let emit_jump s =
  if !Clflags.dlcode || !Clflags.pic_code
  then `b	{emit_symbol s}(PLT)`
  else `b	{emit_symbol s}`

(* Output a pseudo-register *)

let emit_reg = function
    {loc = Reg r} -> emit_string (register_name r)
  | _ -> fatal_error "Emit_arm.emit_reg"

(* Layout of the stack frame *)

let stack_offset = ref 0

let num_stack_slots = Array.make Proc.num_register_classes 0

let prologue_required = ref false

let contains_calls = ref false

let frame_size () =
  let sz =
    !stack_offset +
    4 * num_stack_slots.(0) +
    8 * num_stack_slots.(1) +
    8 * num_stack_slots.(2) +
    (if !contains_calls then 4 else 0)
  in Misc.align sz 8

let slot_offset loc cl =
  match loc with
    Incoming n ->
      assert (n >= 0);
      frame_size() + n
  | Local n ->
      if cl = 0
      then !stack_offset + n * 4
      else !stack_offset + num_stack_slots.(0) * 4 + n * 8
  | Outgoing n ->
      assert (n >= 0);
      n

(* Output a stack reference *)

let emit_stack r =
  match r.loc with
  | Stack s ->
      let ofs = slot_offset s (register_class r) in `[sp, #{emit_int ofs}]`
  | _ -> fatal_error "Emit_arm.emit_stack"

(* Output an addressing mode *)

let emit_addressing addr r n =
  match addr with
    Iindexed ofs ->
      `[{emit_reg r.(n)}, #{emit_int ofs}]`

(* Record live pointers at call points *)

let record_frame_label ?label live dbg =
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
  lbl

let record_frame ?label live dbg =
  let lbl = record_frame_label ?label live dbg in `{emit_label lbl}:`

(* Record calls to the GC -- we've moved them out of the way *)

type gc_call =
  { gc_lbl: label;                      (* Entry label *)
    gc_return_lbl: label;               (* Where to branch after GC *)
    gc_frame_lbl: label }               (* Label of frame descriptor *)

let call_gc_sites = ref ([] : gc_call list)

let emit_call_gc gc =
  `{emit_label gc.gc_lbl}:	{emit_call "caml_call_gc"}\n`;
  `{emit_label gc.gc_frame_lbl}:	b	{emit_label gc.gc_return_lbl}\n`

(* Record calls to caml_ml_array_bound_error.
   In debug mode, we maintain one call to caml_ml_array_bound_error
   per bound check site. Otherwise, we can share a single call. *)

type bound_error_call =
  { bd_lbl: label;                    (* Entry label *)
    bd_frame_lbl: label }             (* Label of frame descriptor *)

let bound_error_sites = ref ([] : bound_error_call list)

let bound_error_label ?label dbg =
  if !Clflags.debug || !bound_error_sites = [] then begin
    let lbl_bound_error = new_label() in
    let lbl_frame = record_frame_label ?label Reg.Set.empty (Dbg_other dbg) in
    bound_error_sites :=
      { bd_lbl = lbl_bound_error;
        bd_frame_lbl = lbl_frame } :: !bound_error_sites;
    lbl_bound_error
  end else begin
    let bd = List.hd !bound_error_sites in bd.bd_lbl
  end

let emit_call_bound_error bd =
  `{emit_label bd.bd_lbl}:	{emit_call "caml_ml_array_bound_error"}\n`;
  `{emit_label bd.bd_frame_lbl}:\n`

(* Negate a comparison *)

let negate_integer_comparison = function
  | Isigned cmp   -> Isigned(negate_integer_comparison cmp)
  | Iunsigned cmp -> Iunsigned(negate_integer_comparison cmp)

(* Names of various instructions *)

let name_for_comparison = function
    Isigned Ceq -> "eq" | Isigned Cne -> "ne" | Isigned Cle -> "le"
  | Isigned Cge -> "ge" | Isigned Clt -> "lt" | Isigned Cgt -> "gt"
  | Iunsigned Ceq -> "eq" | Iunsigned Cne -> "ne" | Iunsigned Cle -> "ls"
  | Iunsigned Cge -> "cs" | Iunsigned Clt -> "cc" | Iunsigned Cgt -> "hi"

let name_for_int_operation = function
  (* Use adds,subs,... to enable 16-bit T1 encoding *)
    Iadd  -> "adds"
  | Isub  -> "subs"
  | Imul  -> "mul"
  | Imulh -> "smmul"
  | Iand  -> "ands"
  | Ior   -> "orrs"
  | Ixor  -> "eors"
  | Ilsl  -> "lsls"
  | Ilsr  -> "lsrs"
  | Iasr  -> "asrs"
  | _ -> assert false

let name_for_shift_operation = function
    Ishiftlogicalleft -> "lsl"
  | Ishiftlogicalright -> "lsr"
  | Ishiftarithmeticright -> "asr"

(* General functional to decompose a non-immediate integer constant
   into 8-bit chunks shifted left 0 ... 30 bits. *)

let decompose_intconst n fn =
  let i = ref n in
  let shift = ref 0 in
  let ninstr = ref 0 in
  while !i <> 0l do
    if Int32.logand (Int32.shift_right !i !shift) 3l = 0l then
      shift := !shift + 2
    else begin
      let bits = Int32.logand !i (Int32.shift_left 0xffl !shift) in
      i := Int32.sub !i bits;
      shift := !shift + 8;
      incr ninstr;
      fn bits
    end
  done;
  !ninstr

(* Load an integer constant into a register *)

let emit_intconst dst n =
  let nr = Int32.lognot n in
  if is_immediate n then begin
    (* Use movs here to enable 16-bit T1 encoding *)
    `	movs	{emit_reg dst}, #{emit_int32 n}\n`; 1
  end else if is_immediate nr then begin
    `	mvn	{emit_reg dst}, #{emit_int32 nr}\n`; 1
  end else if !arch > ARMv6 then begin
    let nl = Int32.logand 0xffffl n in
    let nh = Int32.logand 0xffffl (Int32.shift_right_logical n 16) in
    if nh = 0l then begin
      `	movw	{emit_reg dst}, #{emit_int32 nl}\n`; 1
    end else if Int32.logand nl 0xffl = nl then begin
      `	movs	{emit_reg dst}, #{emit_int32 nl}\n`;
      `	movt	{emit_reg dst}, #{emit_int32 nh}\n`; 2
    end else begin
      `	movw	{emit_reg dst}, #{emit_int32 nl}\n`;
      `	movt	{emit_reg dst}, #{emit_int32 nh}\n`; 2
    end
  end else begin
    let first = ref true in
    decompose_intconst n
      (fun bits ->
        if !first
        (* Use movs,adds here to enable 16-bit T1 encoding *)
        then `	movs	{emit_reg dst}, #{emit_int32 bits} @ {emit_int32 n}\n`
        else `	adds	{emit_reg dst}, {emit_reg dst}, #{emit_int32 bits}\n`;
        first := false)
  end

(* Adjust sp (up or down) by the given byte amount *)

let emit_stack_adjustment n =
  if n = 0 then 0 else begin
    let instr = if n < 0 then "sub" else "add" in
    let ninstr = decompose_intconst (Int32.of_int (abs n))
                   (fun bits ->
                     `	{emit_string instr}	sp, sp, #{emit_int32 bits}\n`) in
    cfi_adjust_cfa_offset (-n);
    ninstr
  end

(* Deallocate the stack frame before a return or tail call *)

let output_epilogue f =
  let n = frame_size() in
  if n > 0 then begin
    let ninstr = emit_stack_adjustment n in
    let ninstr = ninstr + f () in
    (* reset CFA back cause function body may continue *)
    cfi_adjust_cfa_offset n;
    ninstr
  end else
    f ()

(* Name of current function *)
let function_name = ref ""
(* Entry point for tail recursive calls *)
let tailrec_entry_point = ref 0
(* Pending floating-point literals *)
let float_literals = ref ([] : (int64 * label) list)
(* Pending relative references to the global offset table *)
let gotrel_literals = ref ([] : (label * label) list)
(* Pending symbol literals *)
let symbol_literals = ref ([] : (string * label) list)
(* Total space (in words) occupied by pending literals *)
let size_literals = ref 0

(* Pending offset computations : {lbl; dst; src;} --> lbl: .word dst-(src+N) *)
type offset_computation =
  { lbl : label;
    dst : label;
    src : label;
  }
let offset_literals = ref ([] : offset_computation list)

(* Label a floating-point literal *)
let float_literal f =
  try
    List.assoc f !float_literals
  with Not_found ->
    let lbl = new_label() in
    size_literals := !size_literals + 2;
    float_literals := (f, lbl) :: !float_literals;
    lbl

(* Label a GOTREL literal *)
let gotrel_literal l =
  let lbl = new_label() in
  size_literals := !size_literals + 1;
  gotrel_literals := (l, lbl) :: !gotrel_literals;
  lbl

(* Label a symbol literal *)
let symbol_literal s =
  try
    List.assoc s !symbol_literals
  with Not_found ->
    let lbl = new_label() in
    size_literals := !size_literals + 1;
    symbol_literals := (s, lbl) :: !symbol_literals;
    lbl

(* Add an offset computation *)
let offset_literal dst src =
  let lbl = new_label() in
  size_literals := !size_literals + 1;
  offset_literals := { lbl; dst; src; } :: !offset_literals;
  lbl

(* Emit all pending literals *)
let emit_literals() =
  if !float_literals <> [] then begin
    `	.align	3\n`;
    List.iter
      (fun (f, lbl) ->
        `{emit_label lbl}:`; emit_float64_split_directive ".long" f)
      !float_literals;
    float_literals := []
  end;
  if !symbol_literals <> [] then begin
    let offset = if !thumb then 4 else 8 in
    let suffix = if !Clflags.pic_code then "(GOT)" else "" in
    `	.align	2\n`;
    List.iter
      (fun (l, lbl) ->
        `{emit_label lbl}:	.word	_GLOBAL_OFFSET_TABLE_-({emit_label l}+{emit_int offset})\n`)
      !gotrel_literals;
    List.iter
      (fun (s, lbl) ->
        `{emit_label lbl}:	.word	{emit_symbol s}{emit_string suffix}\n`)
      !symbol_literals;
    gotrel_literals := [];
    symbol_literals := []
  end;
  if !offset_literals <> [] then begin
    (* Additions using the pc register read a value 4 or 8 bytes greater than
       the instruction's address, depending on the Thumb setting.  However in
       Thumb mode we must follow interworking conventions and ensure that the
       bottom bit of the pc value is set when reloaded from the trap frame.
       Hence "3" not "4". *)
    let offset = if !thumb then 3 else 8 in
    `	.align	2\n`;
    List.iter
      (fun { lbl; dst; src; } ->
         `{emit_label lbl}:	.word	{emit_label dst}-({emit_label src}+{emit_int offset})\n`)
      !offset_literals;
    offset_literals := []
  end;
  size_literals := 0

(* Emit code to load the address of a symbol *)

let emit_load_symbol_addr dst s =
  if !Clflags.pic_code then begin
    let lbl_pic = new_label() in
    let lbl_got = gotrel_literal lbl_pic in
    let lbl_sym = symbol_literal s in
    (* Both r3 and r12 are marked as clobbered in PIC mode (cf. proc.ml),
       so use r12 as temporary scratch register unless the destination is
       r12, then we use r3 instead. *)
    let tmp = if dst.loc = Reg 8 (*r12*)
              then phys_reg 3 (*r3*)
              else phys_reg 8 (*r12*) in
    `	ldr	{emit_reg tmp}, {emit_label lbl_got}\n`;
    `	ldr	{emit_reg dst}, {emit_label lbl_sym}\n`;
    `{emit_label lbl_pic}:	add	{emit_reg tmp}, pc, {emit_reg tmp}\n`;
    `	ldr	{emit_reg dst}, [{emit_reg tmp}, {emit_reg dst}] @ {emit_symbol s}\n`;
    4
  end else if !arch > ARMv6 && not !Clflags.dlcode && !fastcode_flag then begin
    `	movw	{emit_reg dst}, #:lower16:{emit_symbol s}\n`;
    `	movt	{emit_reg dst}, #:upper16:{emit_symbol s}\n`;
    2
  end else begin
    let lbl = symbol_literal s in
    `	ldr	{emit_reg dst}, {emit_label lbl} @ {emit_symbol s}\n`;
    1
  end

(* Emit instructions that set [rd] to 1 if integer condition [cmp] holds
   and set [rd] to 0 otherwise. *)

let emit_set_condition cmp rd =
  let compthen = name_for_comparison cmp in
  let compelse = name_for_comparison (negate_integer_comparison cmp) in
  if !arch < ARMv8 || not !thumb then begin
    `	ite	{emit_string compthen}\n`;
    `	mov{emit_string	compthen}	{emit_reg rd}, #1\n`;
    `	mov{emit_string compelse}	{emit_reg rd}, #0\n`;
    3
  end else begin
    (* T32 mode in ARMv8 deprecates general ITE blocks
       and favors IT blocks containing only one 16-bit instruction.
       mov <reg>, #<imm> is 16 bits if <reg> is R0...R7
                                   and <imm> fits in 8 bits. *)
    let temp =
      match rd.loc with
      | Reg r when r < 8 -> rd  (* can assign rd directly *)
      | _ -> phys_reg 3  (* use r3 as temporary *) in
    `	it	{emit_string compthen}\n`;
    `	mov{emit_string	compthen}	{emit_reg temp}, #1\n`;
    `	it	{emit_string compelse}\n`;
    `	mov{emit_string compelse}	{emit_reg temp}, #0\n`;
    if temp.loc = rd.loc then 4 else begin
      `	movs	{emit_reg rd}, {emit_reg temp}\n`; 5
    end
  end

(* Emit code to load the address of a label in the lr register *)
let emit_load_handler_address handler =
  (* PIC code *)
  let lbl_src = new_label() in
  let lbl_offset = offset_literal handler lbl_src in
  `	ldr	lr, {emit_label lbl_offset}\n`;
  `{emit_label lbl_src}:\n`;
  `	add	lr, pc, lr\n`;
  2


(* Output .text section directive, or named .text.caml.<name> if enabled. *)

let emit_named_text_section func_name =
  if !Clflags.function_sections then begin
    `	.section .text.caml.{emit_symbol func_name},{emit_string_literal "ax"},%progbits\n`
  end
  else
    `	.text\n`

(* Output the assembly code for an instruction *)

let emit_instr i =
    emit_debug_info i.dbg;
    match i.desc with
    | Lend -> 0
    | Lprologue ->
      assert (!prologue_required);
      let n = frame_size() in
      let num_instrs =
        if n > 0 then begin
          let num_instrs = emit_stack_adjustment (-n) in
          if !contains_calls then begin
            cfi_offset ~reg:14 (* lr *) ~offset:(-4);
            `	str	lr, [sp, #{emit_int(n - 4)}]\n`;
            num_instrs + 1
          end else begin
            num_instrs
          end
        end else begin
          0
        end
      in
      `{emit_label !tailrec_entry_point}:\n`;
      num_instrs
    | Lop(Imove | Ispill | Ireload) ->
        let src = i.arg.(0) and dst = i.res.(0) in
        if src.loc = dst.loc then 0 else begin
          begin match (src, dst) with
            {loc = Reg _; typ = Float}, {loc = Reg _} ->
              `	fcpyd	{emit_reg dst}, {emit_reg src}\n`
          | {loc = Reg _}, {loc = Reg _} ->
              `	mov	{emit_reg dst}, {emit_reg src}\n`
          | {loc = Reg _; typ = Float}, _ ->
              `	fstd	{emit_reg src}, {emit_stack dst}\n`
          | {loc = Reg _}, _ ->
              `	str	{emit_reg src}, {emit_stack dst}\n`
          | {typ = Float}, _ ->
              `	fldd	{emit_reg dst}, {emit_stack src}\n`
          | _ ->
              `	ldr	{emit_reg dst}, {emit_stack src}\n`
          end; 1
        end
    | Lop(Iconst_int n) ->
        emit_intconst i.res.(0) (Nativeint.to_int32 n)
    | Lop(Iconst_float f) when !fpu = Soft ->
        let high_bits = Int64.to_int32 (Int64.shift_right_logical f 32)
        and low_bits = Int64.to_int32 f in
        if is_immediate low_bits || is_immediate high_bits then begin
          let ninstr_low = emit_intconst i.res.(0) low_bits
          and ninstr_high = emit_intconst i.res.(1) high_bits in
          ninstr_low + ninstr_high
        end else begin
          let lbl = float_literal f in
          `	ldr	{emit_reg i.res.(0)}, {emit_label lbl}\n`;
          `	ldr	{emit_reg i.res.(1)}, {emit_label lbl} + 4\n`;
          2
        end
    | Lop(Iconst_float f) when !fpu = VFPv2 ->
        let lbl = float_literal f in
        `	fldd	{emit_reg i.res.(0)}, {emit_label lbl}\n`;
        1
    | Lop(Iconst_float f) ->
        let encode imm =
          let sg = Int64.to_int (Int64.shift_right_logical imm 63) in
          let ex = Int64.to_int (Int64.shift_right_logical imm 52) in
          let ex = (ex land 0x7ff) - 1023 in
          let mn = Int64.logand imm 0xfffffffffffffL in
          if Int64.logand mn 0xffffffffffffL <> 0L || ex < -3 || ex > 4
          then
            None
          else begin
            let mn = Int64.to_int (Int64.shift_right_logical mn 48) in
            if mn land 0x0f <> mn then
              None
            else
              let ex = ((ex + 3) land 0x07) lxor 0x04 in
              Some((sg lsl 7) lor (ex lsl 4) lor mn)
          end in
        begin match encode f with
          None ->
            let lbl = float_literal f in
            `	fldd	{emit_reg i.res.(0)}, {emit_label lbl}\n`
        | Some imm8 ->
            `	fconstd	{emit_reg i.res.(0)}, #{emit_int imm8}\n`
        end; 1
    | Lop(Iconst_symbol s) ->
        emit_load_symbol_addr i.res.(0) s
    | Lop(Icall_ind { label_after; }) ->
        if !arch >= ARMv5 then begin
          `	blx	{emit_reg i.arg.(0)}\n`;
          `{record_frame i.live (Dbg_other i.dbg) ~label:label_after}\n`; 1
        end else begin
          `	mov	lr, pc\n`;
          `	bx	{emit_reg i.arg.(0)}\n`;
          `{record_frame i.live (Dbg_other i.dbg) ~label:label_after}\n`; 2
        end
    | Lop(Icall_imm { func; label_after; }) ->
        `	{emit_call func}\n`;
        `{record_frame i.live (Dbg_other i.dbg) ~label:label_after}\n`; 1
    | Lop(Itailcall_ind { label_after = _; }) ->
        output_epilogue begin fun () ->
          if !contains_calls then
            `	ldr	lr, [sp, #{emit_int (-4)}]\n`;
          `	bx	{emit_reg i.arg.(0)}\n`; 2
        end
    | Lop(Itailcall_imm { func; label_after = _; }) ->
        if func = !function_name then begin
          `	b	{emit_label !tailrec_entry_point}\n`; 1
        end else begin
          output_epilogue begin fun () ->
            if !contains_calls then
              `	ldr	lr, [sp, #{emit_int (-4)}]\n`;
            `	{emit_jump func}\n`; 2
          end
        end
    | Lop(Iextcall { func; alloc = false; }) ->
        `	{emit_call func}\n`; 1
    | Lop(Iextcall { func; alloc = true; label_after; }) ->
        let ninstr = emit_load_symbol_addr (phys_reg 7 (* r7 *)) func in
        `	{emit_call "caml_c_call"}\n`;
        `{record_frame i.live (Dbg_other i.dbg) ~label:label_after}\n`;
        1 + ninstr
    | Lop(Istackoffset n) ->
        assert (n mod 8 = 0);
        let ninstr = emit_stack_adjustment (-n) in
        stack_offset := !stack_offset + n;
        ninstr
    | Lop(Iload(Single, addr)) when !fpu >= VFPv2 ->
        `	flds	s14, {emit_addressing addr i.arg 0}\n`;
        `	fcvtds	{emit_reg i.res.(0)}, s14\n`; 2
    | Lop(Iload((Double | Double_u), addr)) when !fpu = Soft ->
        (* Use LDM or LDRD if possible *)
        begin match i.res.(0), i.res.(1), addr with
          {loc = Reg rt}, {loc = Reg rt2}, Iindexed 0
          when rt < rt2 ->
            `	ldm	{emit_reg i.arg.(0)}, \{{emit_reg i.res.(0)}, {emit_reg i.res.(1)}}\n`; 1
        | {loc = Reg rt}, {loc = Reg rt2}, addr
          when !arch >= ARMv5TE && rt mod 2 == 0 && rt2 = rt + 1 ->
            `	ldrd	{emit_reg i.res.(0)}, {emit_reg i.res.(1)}, {emit_addressing addr i.arg 0}\n`; 1
        | _ ->
            let addr' = offset_addressing addr 4 in
            if i.res.(0).loc <> i.arg.(0).loc then begin
              `	ldr	{emit_reg i.res.(0)}, {emit_addressing addr i.arg 0}\n`;
              `	ldr	{emit_reg i.res.(1)}, {emit_addressing addr' i.arg 0}\n`
            end else begin
              `	ldr	{emit_reg i.res.(1)}, {emit_addressing addr' i.arg 0}\n`;
              `	ldr	{emit_reg i.res.(0)}, {emit_addressing addr i.arg 0}\n`
            end; 2
        end
    | Lop(Iload(size, addr)) ->
        let r = i.res.(0) in
        let instr =
          match size with
            Byte_unsigned -> "ldrb"
          | Byte_signed -> "ldrsb"
          | Sixteen_unsigned -> "ldrh"
          | Sixteen_signed -> "ldrsh"
          | Double
          | Double_u -> "fldd"
          | _ (* 32-bit quantities *) -> "ldr" in
        `	{emit_string instr}	{emit_reg r}, {emit_addressing addr i.arg 0}\n`; 1
    | Lop(Istore(Single, addr, _)) when !fpu >= VFPv2 ->
        `	fcvtsd	s14, {emit_reg i.arg.(0)}\n`;
        `	fsts	s14, {emit_addressing addr i.arg 1}\n`; 2
    | Lop(Istore((Double | Double_u), addr, _)) when !fpu = Soft ->
        (* Use STM or STRD if possible *)
        begin match i.arg.(0), i.arg.(1), addr with
          {loc = Reg rt}, {loc = Reg rt2}, Iindexed 0
          when rt < rt2 ->
            `	stm	{emit_reg i.arg.(2)}, \{{emit_reg i.arg.(0)}, {emit_reg i.arg.(1)}}\n`; 1
        | {loc = Reg rt}, {loc = Reg rt2}, addr
          when !arch >= ARMv5TE && rt mod 2 == 0 && rt2 = rt + 1 ->
            `	strd	{emit_reg i.arg.(0)}, {emit_reg i.arg.(1)}, {emit_addressing addr i.arg 2}\n`; 1
        | _ ->
            let addr' = offset_addressing addr 4 in
            `	str	{emit_reg i.arg.(0)}, {emit_addressing addr i.arg 2}\n`;
            `	str	{emit_reg i.arg.(1)}, {emit_addressing addr' i.arg 2}\n`; 2
        end
    | Lop(Istore(size, addr, _)) ->
        let r = i.arg.(0) in
        let instr =
          match size with
            Byte_unsigned
          | Byte_signed -> "strb"
          | Sixteen_unsigned
          | Sixteen_signed -> "strh"
          | Double
          | Double_u -> "fstd"
          | _ (* 32-bit quantities *) -> "str" in
        `	{emit_string instr}	{emit_reg r}, {emit_addressing addr i.arg 1}\n`; 1
    | Lop(Ialloc { bytes = n; label_after_call_gc; dbginfo }) ->
        let lbl_frame =
          record_frame_label i.live (Dbg_alloc dbginfo) ?label:label_after_call_gc
        in
        if !fastcode_flag then begin
          let ninstr = decompose_intconst
                         (Int32.of_int n)
                         (fun i ->
                           `   sub     alloc_ptr, alloc_ptr, #{emit_int32 i}\n`) in
          let offset = Domainstate.(idx_of_field Domain_young_limit) * 8 in
          `	ldr	{emit_reg i.res.(0)}, [domain_state_ptr, {emit_int offset}]\n`;
          `     cmp     alloc_ptr, {emit_reg i.res.(0)}\n`;
          let lbl_call_gc = new_label() in
          `     bcc     {emit_label lbl_call_gc}\n`;
          let lbl_after_alloc = new_label() in
          `{emit_label lbl_after_alloc}:`;
          `     add     {emit_reg i.res.(0)}, alloc_ptr, #4\n`;
          call_gc_sites :=
            { gc_lbl = lbl_call_gc;
              gc_return_lbl = lbl_after_alloc;
              gc_frame_lbl = lbl_frame } :: !call_gc_sites;
          4 + ninstr
        end else begin
          let ninstr =
            begin match n with
               8 -> `	{emit_call "caml_alloc1"}\n`; 1
            | 12 -> `	{emit_call "caml_alloc2"}\n`; 1
            | 16 -> `	{emit_call "caml_alloc3"}\n`; 1
            |  _ -> let ninstr = emit_intconst (phys_reg 7) (Int32.of_int n) in
                    `	{emit_call "caml_allocN"}\n`; 1 + ninstr
            end in
          `{emit_label lbl_frame}:	add	{emit_reg i.res.(0)}, alloc_ptr, #4\n`;
          1 + ninstr
        end
    | Lop(Iintop(Icomp cmp)) ->
        `	cmp	{emit_reg i.arg.(0)}, {emit_reg i.arg.(1)}\n`;
        1 + emit_set_condition cmp i.res.(0)
    | Lop(Iintop_imm(Icomp cmp, n)) ->
        `	cmp	{emit_reg i.arg.(0)}, #{emit_int n}\n`;
        1 + emit_set_condition cmp i.res.(0)
    | Lop(Iintop (Icheckbound { label_after_error; } )) ->
        let lbl = bound_error_label ?label:label_after_error i.dbg in
        `	cmp	{emit_reg i.arg.(0)}, {emit_reg i.arg.(1)}\n`;
        `	bls	{emit_label lbl}\n`; 2
    | Lop(Iintop_imm(Icheckbound { label_after_error; }, n)) ->
        let lbl = bound_error_label ?label:label_after_error i.dbg in
        `	cmp	{emit_reg i.arg.(0)}, #{emit_int n}\n`;
        `	bls	{emit_label lbl}\n`; 2
    | Lop(Ispecific(Ishiftcheckbound(shiftop, n))) ->
        let lbl = bound_error_label i.dbg in
        let op = name_for_shift_operation shiftop in
        `	cmp	{emit_reg i.arg.(1)}, {emit_reg i.arg.(0)}, {emit_string op} #{emit_int n}\n`;
        `	bcs	{emit_label lbl}\n`; 2
    | Lop(Iintop Imulh) when !arch < ARMv6 ->
        `	smull	r12, {emit_reg i.res.(0)}, {emit_reg i.arg.(0)}, {emit_reg i.arg.(1)}\n`; 1
    | Lop(Ispecific Imulhadd) ->
        `	smmla	{emit_reg i.res.(0)}, {emit_reg i.arg.(0)}, {emit_reg i.arg.(1)}, {emit_reg i.arg.(2)}\n`; 1
    | Lop(Iintop op) ->
        let instr = name_for_int_operation op in
        `	{emit_string instr}	{emit_reg i.res.(0)}, {emit_reg i.arg.(0)}, {emit_reg i.arg.(1)}\n`; 1
    | Lop(Iintop_imm(op, n)) ->
        let instr = name_for_int_operation op in
        `	{emit_string instr}	{emit_reg i.res.(0)}, {emit_reg i.arg.(0)}, #{emit_int n}\n`; 1
    | Lop(Iabsf | Inegf as op) when !fpu = Soft ->
        assert (i.res.(0).loc = i.arg.(0).loc);
        let instr = (match op with
                       Iabsf -> "bic"
                     | Inegf -> "eor"
                     | _     -> assert false) in
        `	{emit_string instr}	{emit_reg i.res.(1)}, {emit_reg i.arg.(1)}, #0x80000000\n`; 1
    | Lop(Iabsf | Inegf | Ispecific Isqrtf as op) ->
        let instr = (match op with
                       Iabsf            -> "fabsd"
                     | Inegf            -> "fnegd"
                     | Ispecific Isqrtf -> "fsqrtd"
                     | _                -> assert false) in
        `	{emit_string instr}	{emit_reg i.res.(0)}, {emit_reg i.arg.(0)}\n`; 1
    | Lop(Ifloatofint) ->
        `	fmsr	s14, {emit_reg i.arg.(0)}\n`;
        `	fsitod	{emit_reg i.res.(0)}, s14\n`; 2
    | Lop(Iintoffloat) ->
        `	ftosizd	s14, {emit_reg i.arg.(0)}\n`;
        `	fmrs	{emit_reg i.res.(0)}, s14\n`; 2
    | Lop(Iaddf | Isubf | Imulf | Idivf | Ispecific Inegmulf as op) ->
        let instr = (match op with
                       Iaddf              -> "faddd"
                     | Isubf              -> "fsubd"
                     | Imulf              -> "fmuld"
                     | Idivf              -> "fdivd"
                     | Ispecific Inegmulf -> "fnmuld"
                     | _                  -> assert false) in
        `	{emit_string instr}	{emit_reg i.res.(0)}, {emit_reg i.arg.(0)}, {emit_reg i.arg.(1)}\n`;
        1
    | Lop(Ispecific(Imuladdf | Inegmuladdf | Imulsubf | Inegmulsubf as op)) ->
        assert (i.res.(0).loc = i.arg.(0).loc);
        let instr = (match op with
                       Imuladdf    -> "fmacd"
                     | Inegmuladdf -> "fnmacd"
                     | Imulsubf    -> "fmscd"
                     | Inegmulsubf -> "fnmscd"
                     | _ -> assert false) in
        `	{emit_string instr}	{emit_reg i.res.(0)}, {emit_reg i.arg.(1)}, {emit_reg i.arg.(2)}\n`;
        1
    | Lop(Ispecific(Ishiftarith(op, shiftop, n))) ->
        let instr = (match op with
                       Ishiftadd    -> "add"
                     | Ishiftsub    -> "sub"
                     | Ishiftsubrev -> "rsb"
                     | Ishiftand    -> "and"
                     | Ishiftor     -> "orr"
                     | Ishiftxor    -> "eor") in
        let op = name_for_shift_operation shiftop in
        `	{emit_string instr}	{emit_reg i.res.(0)}, {emit_reg i.arg.(0)}, \
                                        {emit_reg i.arg.(1)}, {emit_string op} #{emit_int n}\n`; 1
    | Lop(Ispecific(Irevsubimm n)) ->
        `	rsb	{emit_reg i.res.(0)}, {emit_reg i.arg.(0)}, #{emit_int n}\n`; 1
    | Lop(Ispecific(Imuladd | Imulsub as op)) ->
        let instr = (match op with
                       Imuladd -> "mla"
                     | Imulsub -> "mls"
                     | _ -> assert false) in
        `	{emit_string instr}	{emit_reg i.res.(0)}, {emit_reg i.arg.(0)}, {emit_reg i.arg.(1)}, {emit_reg i.arg.(2)}\n`; 1
    | Lop(Ispecific(Ibswap size)) ->
        begin match size with
          16 ->
            `	rev16	{emit_reg i.res.(0)}, {emit_reg i.arg.(0)}\n`;
            `	movt	{emit_reg i.res.(0)}, #0\n`; 2
        | 32 ->
            `	rev	{emit_reg i.res.(0)}, {emit_reg i.arg.(0)}\n`; 1
        | _ ->
            assert false
        end
    | Lop (Iname_for_debugger _) -> 0
    | Lreloadretaddr ->
        let n = frame_size() in
        `	ldr	lr, [sp, #{emit_int(n-4)}]\n`; 1
    | Lreturn ->
        output_epilogue begin fun () ->
          `	bx	lr\n`; 1
        end
    | Llabel lbl ->
        `{emit_label lbl}:\n`; 0
    | Lbranch lbl ->
        `	b	{emit_label lbl}\n`; 1
    | Lcondbranch(tst, lbl) ->
        begin match tst with
          Itruetest ->
            `	cmp	{emit_reg i.arg.(0)}, #0\n`;
            `	bne	{emit_label lbl}\n`; 2
        | Ifalsetest ->
            `	cmp	{emit_reg i.arg.(0)}, #0\n`;
            `	beq	{emit_label lbl}\n`; 2
        | Iinttest cmp ->
            `	cmp	{emit_reg i.arg.(0)}, {emit_reg i.arg.(1)}\n`;
            let comp = name_for_comparison cmp in
            `	b{emit_string comp}	{emit_label lbl}\n`; 2
        | Iinttest_imm(cmp, n) ->
            `	cmp	{emit_reg i.arg.(0)}, #{emit_int n}\n`;
            let comp = name_for_comparison cmp in
            `	b{emit_string comp}	{emit_label lbl}\n`; 2
        | Ifloattest cmp ->
            let comp =
              match cmp with
              | CFeq -> "eq"
              | CFneq -> "ne"
              | CFlt -> "cc"
              | CFnlt -> "cs"
              | CFle -> "ls"
              | CFnle -> "hi"
              | CFgt -> "gt"
              | CFngt -> "le"
              | CFge -> "ge"
              | CFnge -> "lt"
            in
            `	fcmpd	{emit_reg i.arg.(0)}, {emit_reg i.arg.(1)}\n`;
            `	fmstat\n`;
            `	b{emit_string comp}	{emit_label lbl}\n`; 3
        | Ioddtest ->
            `	tst	{emit_reg i.arg.(0)}, #1\n`;
            `	bne	{emit_label lbl}\n`; 2
        | Ieventest ->
            `	tst	{emit_reg i.arg.(0)}, #1\n`;
            `	beq	{emit_label lbl}\n`; 2
        end
    | Lcondbranch3(lbl0, lbl1, lbl2) ->
        `	cmp	{emit_reg i.arg.(0)}, #1\n`;
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
        end;
        4
    | Lswitch jumptbl ->
        if !arch > ARMv6 && !thumb then begin
          (* The Thumb-2 TBH instruction supports only forward branches,
             so we need to generate appropriate trampolines for all labels
             that appear before this switch instruction (PR#5623) *)
          let tramtbl = Array.copy jumptbl in
          `	tbh	[pc, {emit_reg i.arg.(0)}, lsl #1]\n`;
          for j = 0 to Array.length tramtbl - 1 do
            let rec label i =
              match i.desc with
                Lend -> new_label()
              | Llabel lbl when lbl = tramtbl.(j) -> lbl
              | _ -> label i.next in
            tramtbl.(j) <- label i.next;
            `	.short	({emit_label tramtbl.(j)}-.)/2+{emit_int j}\n`
          done;
          let sz = ref (1 + (Array.length jumptbl + 1) / 2) in
          (* Generate the necessary trampolines *)
          for j = 0 to Array.length tramtbl - 1 do
            if tramtbl.(j) <> jumptbl.(j) then begin
              `{emit_label tramtbl.(j)}:	b	{emit_label jumptbl.(j)}\n`;
              incr sz
            end
          done;
          !sz
        end else if not !Clflags.pic_code then begin
          `	ldr	pc, [pc, {emit_reg i.arg.(0)}, lsl #2]\n`;
          `	nop\n`;
          for j = 0 to Array.length jumptbl - 1 do
            `	.word	{emit_label jumptbl.(j)}\n`
          done;
          2 + Array.length jumptbl
        end else begin
          (* Slightly slower, but position-independent *)
          `	add	pc, pc, {emit_reg i.arg.(0)}, lsl #2\n`;
          `	nop\n`;
          for j = 0 to Array.length jumptbl - 1 do
            `	b	{emit_label jumptbl.(j)}\n`
          done;
          2 + Array.length jumptbl
        end
    | Lentertrap ->
        0
    | Ladjust_trap_depth { delta_traps } ->
        (* each trap occupies 8 bytes on the stack *)
        let delta = 8 * delta_traps in
        cfi_adjust_cfa_offset delta;
        stack_offset := !stack_offset + delta; 0
    | Lpushtrap { lbl_handler; } ->
        let s = emit_load_handler_address lbl_handler in
        stack_offset := !stack_offset + 8;
        `	push	\{trap_ptr, lr}\n`;
        cfi_adjust_cfa_offset 8;
        `	mov	trap_ptr, sp\n`; s + 2
    | Lpoptrap ->
        `	pop	\{trap_ptr, lr}\n`;
        cfi_adjust_cfa_offset (-8);
        stack_offset := !stack_offset - 8; 1
    | Lraise k ->
        begin match k with
        | Lambda.Raise_regular ->
          let offset = Domainstate.(idx_of_field Domain_backtrace_pos) * 8 in
          `	mov	r12, #0\n`;
          `	str	r12, [domain_state_ptr, {emit_int offset}]\n`;
          `	{emit_call "caml_raise_exn"}\n`;
          `{record_frame Reg.Set.empty (Dbg_raise i.dbg)}\n`; 3
        | Lambda.Raise_reraise ->
          `	{emit_call "caml_raise_exn"}\n`;
          `{record_frame Reg.Set.empty (Dbg_raise i.dbg)}\n`; 1
        | Lambda.Raise_notrace ->
          `	mov	sp, trap_ptr\n`;
          `	pop	\{trap_ptr, pc}\n`; 2
        end

(* Upper bound on the size of the code sequence for a Linear instruction,
   in 32-bit words. *)

let max_instruction_size i =
  match i.desc with
  | Lswitch jumptbl ->
      if !arch > ARMv6 && !thumb
      then 1 + (Array.length jumptbl + 1) / 2 + Array.length jumptbl
      else 2 + Array.length jumptbl
  | _ ->
      8   (* conservative upper bound; the true upper bound is probably 5 *)

(* Emission of an instruction sequence *)

let rec emit_all ninstr fallthrough i =
  (* ninstr = number of 32-bit code words emitted since last constant island *)
  (* fallthrough is true if previous instruction can fall through *)
  if i.desc = Lend then () else begin
    (* Make sure literals not yet emitted remain addressable,
       or emit them in a new constant island. *)
    (* fldd can address up to +/-1KB, ldr can address up to +/-4KB *)
    let limit = (if !fpu >= VFPv2 && !float_literals <> []
                 then 127
                 else 511) in
    let limit = limit - !size_literals - max_instruction_size i in
    let ninstr' =
      if ninstr >= limit - 64 && not fallthrough then begin
        emit_literals();
        0
      end else if !size_literals != 0 && ninstr >= limit then begin
        let lbl = new_label() in
        `	b	{emit_label lbl}\n`;
        emit_literals();
        `{emit_label lbl}:\n`;
        0
      end else
        ninstr in
    let n = emit_instr i in
    emit_all (ninstr' + n) (has_fallthrough i.desc) i.next
  end

(* Emission of a function declaration *)

let fundecl fundecl =
  function_name := fundecl.fun_name;
  fastcode_flag := fundecl.fun_fast;
  tailrec_entry_point := fundecl.fun_tailrec_entry_point_label;
  float_literals := [];
  gotrel_literals := [];
  symbol_literals := [];
  stack_offset := 0;
  call_gc_sites := [];
  bound_error_sites := [];
  for i = 0 to Proc.num_register_classes - 1 do
    num_stack_slots.(i) <- fundecl.fun_num_stack_slots.(i);
  done;
  contains_calls := fundecl.fun_contains_calls;
  prologue_required := fundecl.fun_prologue_required;
  emit_named_text_section !function_name;
  `	.align	2\n`;
  `	.globl	{emit_symbol fundecl.fun_name}\n`;
  if !arch > ARMv6 && !thumb then
    `	.thumb\n`
  else
    `	.arm\n`;
  `	.type	{emit_symbol fundecl.fun_name}, %function\n`;
  `{emit_symbol fundecl.fun_name}:\n`;
  emit_debug_info fundecl.fun_dbg;
  cfi_startproc();
  emit_all 0 true fundecl.fun_body;
  emit_literals();
  List.iter emit_call_gc !call_gc_sites;
  List.iter emit_call_bound_error !bound_error_sites;
  cfi_endproc();
  `	.type	{emit_symbol fundecl.fun_name}, %function\n`;
  `	.size	{emit_symbol fundecl.fun_name}, .-{emit_symbol fundecl.fun_name}\n`

(* Emission of data *)

let emit_item = function
    Cglobal_symbol s -> `	.globl	{emit_symbol s}\n`;
  | Cdefine_symbol s -> `{emit_symbol s}:\n`
  | Cint8 n -> `	.byte	{emit_int n}\n`
  | Cint16 n -> `	.short	{emit_int n}\n`
  | Cint32 n -> `	.long	{emit_int32 (Nativeint.to_int32 n)}\n`
  | Cint n -> `	.long	{emit_int32 (Nativeint.to_int32 n)}\n`
  | Csingle f -> emit_float32_directive ".long" (Int32.bits_of_float f)
  | Cdouble f -> emit_float64_split_directive ".long" (Int64.bits_of_float f)
  | Csymbol_address s -> `	.word	{emit_symbol s}\n`
  | Cstring s -> emit_string_directive "	.ascii  " s
  | Cskip n -> if n > 0 then `	.space	{emit_int n}\n`
  | Calign n -> `	.align	{emit_int(Misc.log2 n)}\n`

let data l =
  `	.data\n`;
  List.iter emit_item l

(* Beginning / end of an assembly file *)

let begin_assembly() =
  reset_debug_info();
  `	.file	\"\"\n`;  (* PR#7037 *)
  `	.syntax	unified\n`;
  begin match !arch with
  | ARMv4   -> `	.arch	armv4t\n`
  | ARMv5   -> `	.arch	armv5t\n`
  | ARMv5TE -> `	.arch	armv5te\n`
  | ARMv6   -> `	.arch	armv6\n`
  | ARMv6T2 -> `	.arch	armv6t2\n`
  | ARMv7   -> `	.arch	armv7-a\n`
  | ARMv8   -> `	.arch	armv8-a\n`
  end;
  begin match !fpu with
    Soft      -> `	.fpu	softvfp\n`
  | VFPv2     -> `	.fpu	vfpv2\n`
  | VFPv3_D16 -> `	.fpu	vfpv3-d16\n`
  | VFPv3     -> `	.fpu	vfpv3\n`
  end;
  `trap_ptr	.req	r8\n`;
  `alloc_ptr	.req	r10\n`;
  `domain_state_ptr	.req	r11\n`;
  let lbl_begin = Compilenv.make_symbol (Some "data_begin") in
  `	.data\n`;
  `	.globl	{emit_symbol lbl_begin}\n`;
  `{emit_symbol lbl_begin}:\n`;
  let lbl_begin = Compilenv.make_symbol (Some "code_begin") in
  emit_named_text_section lbl_begin;
  `	.globl	{emit_symbol lbl_begin}\n`;
  `{emit_symbol lbl_begin}:\n`

let end_assembly () =
  let lbl_end = Compilenv.make_symbol (Some "code_end") in
  emit_named_text_section lbl_end;
  `	.globl	{emit_symbol lbl_end}\n`;
  `{emit_symbol lbl_end}:\n`;
  let lbl_end = Compilenv.make_symbol (Some "data_end") in
  `	.data\n`;
  `	.long 0\n`;  (* PR#6329 *)
  `	.globl	{emit_symbol lbl_end}\n`;
  `{emit_symbol lbl_end}:\n`;
  `	.long	0\n`;
  let lbl = Compilenv.make_symbol (Some "frametable") in
  `	.globl	{emit_symbol lbl}\n`;
  `{emit_symbol lbl}:\n`;
  emit_frames
    { efa_code_label = (fun lbl ->
                       `	.type	{emit_label lbl}, %function\n`;
                       `	.word	{emit_label lbl}\n`);
      efa_data_label = (fun lbl ->
                       `	.type	{emit_label lbl}, %object\n`;
                       `	.word	{emit_label lbl}\n`);
      efa_8 = (fun n -> `	.byte	{emit_int n}\n`);
      efa_16 = (fun n -> `	.short	{emit_int n}\n`);
      efa_32 = (fun n -> `	.long	{emit_int32 n}\n`);
      efa_word = (fun n -> `	.word	{emit_int n}\n`);
      efa_align = (fun n -> `	.align	{emit_int(Misc.log2 n)}\n`);
      efa_label_rel = (fun lbl ofs ->
                           `	.word	{emit_label lbl} - . + {emit_int32 ofs}\n`);
      efa_def_label = (fun lbl -> `{emit_label lbl}:\n`);
      efa_string = (fun s -> emit_string_directive "	.asciz	" s) };
  `	.type	{emit_symbol lbl}, %object\n`;
  `	.size	{emit_symbol lbl}, .-{emit_symbol lbl}\n`;
  begin match Config.system with
    "linux_eabihf" | "linux_eabi" | "netbsd" ->
      (* Mark stack as non-executable *)
      `	.section	.note.GNU-stack,\"\",%progbits\n`
  | _ -> ()
  end
