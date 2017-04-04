(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*          Fabrice Le Fessant, projet Gallium, INRIA Rocquencourt        *)
(*                  Mark Shinwell, Jane Street Europe                     *)
(*                                                                        *)
(*   Copyright 2014 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*   Copyright 2016--2017 Jane Street Group LLC                           *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

[@@@ocaml.warning "+a-4-9-30-40-41-42"]
(* CR-someday mshinwell: Eliminate uses of [bprintf] from the assembly
   generation code, then enable this warning. *)
[@@@ocaml.warning "-3"]

module Int8 = Numbers.Int8
module Int16 = Numbers.Int16
module TS = Target_system

type constant =
  | Const of int64
  | This
  | Label of Cmm.label
  | Symbol of string
  | Add of constant * constant
  | Sub of constant * constant

type width =
  | Thirty_two
  | Sixty_four

type dwarf_section =
  | Debug_info
  | Debug_abbrev
  | Debug_aranges
  | Debug_loc
  | Debug_str
  | Debug_line

type section =
  | Text
  | Data
  | Read_only_data
  | Eight_byte_literals
  | Sixteen_byte_literals
  | Jump_tables
  | DWARF of dwarf_section
  | POWER of power_section

let current_section = ref None

let section_is_text = function
  | Text -> true
  | Data
  | Read_only_data
  | Eight_byte_literals
  | Sixteen_byte_literals
  | Jump_tables
  | DWARF _
  | POWER _ -> false

let current_section_is_text () =
  match !current_section with
  | None ->
    Misc.fatal_error "Asm_directives.initialize has not been called"
  | Some section -> section_is_text section

let text_label = Cmm.new_label ()
let data_label = Cmm.new_label ()
let eight_byte_literals_label = Cmm.new_label ()
let sixteen_byte_literals_label = Cmm.new_label ()
let jump_tables_label = Cmm.new_label ()
let debug_info_label = Cmm.new_label ()
let debug_abbrev_label = Cmm.new_label ()
let debug_aranges_label = Cmm.new_label ()
let debug_loc_label = Cmm.new_label ()
let debug_str_label = Cmm.new_label ()
let debug_line_label = Cmm.new_label ()

let label_for_section = function
  | Text -> text_label
  | Data -> data_label
  | Eight_byte_literals -> eight_byte_literals_label
  | Sixteen_byte_literals -> sixteen_byte_literals_label
  | Jump_tables -> jump_tables_label
  | DWARF Debug_info -> debug_info_label
  | DWARF Debug_abbrev -> debug_abbrev_label
  | DWARF Debug_aranges -> debug_aranges_label
  | DWARF Debug_loc -> debug_loc_label
  | DWARF Debug_str -> debug_str_label
  | DWARF Debug_line -> debug_line_label

let label_prefix =
  match TS.platform with
  | X86_32 ->
    begin match TS.system with
    | Linux_elf -> ".L"
    | Bsd_elf -> ".L"
    | Solaris -> ".L"
    | Beos -> ".L"
    | Gnu -> ".L"
    | MacOS
    | Win64
    | Cygwin
    | Win32
    | Mingw
    | Linux
    | Mingw64
    | Unknown -> "L"
    end
  | X86_64 ->
    begin match TS.system with
    | MacOS
    | Win64 -> "L" ^ string_of_int label_name
    | Gnu
    | Cygwin
    | Solaris
    | Win32
    | Linux_elf
    | Bsd_elf
    | Beos
    | Mingw
    | Linux
    | Mingw64
    | Unknown -> ".L" ^ string_of_int label_name
    end
  | AArch64
  | POWER
  | S390 -> ".L"
  | ARM
  | SPARC -> "L"

let string_of_label label_name = label_prefix ^ (string_of_int label_name)

let symbol_prefix =
  match TS.platform with
  | X86_32 ->
    begin match TS.system with
    | Linux_elf
    | Bsd_elf
    | Solaris
    | Beos
    | Gnu -> ""
    | MacOS
    | Win64
    | Cygwin
    | Win32
    | Mingw
    | Linux
    | Mingw64
    | Unknown -> "_"
    end
  | X86_64 ->
    begin match TS.system with
    | MacOS -> "_"
    | Win64
    | Gnu
    | Cygwin
    | Solaris
    | Win32
    | Linux_elf
    | Bsd_elf
    | Beos
    | Mingw
    | Linux
    | Mingw64
    | Unknown -> ""
    end
  | POWER -> "."
  | AArch64 -> "$"
  | S390 -> "."
  | ARM
  | SPARC -> ""

let string_of_symbol s =
  let spec = ref false in
  for i = 0 to String.length s - 1 do
    match String.unsafe_get s i with
    | 'A'..'Z' | 'a'..'z' | '0'..'9' | '_' -> ()
    | _ -> spec := true;
  done;
  if not !spec then if symbol_prefix = "" then s else symbol_prefix ^ s
  else
    let b = Buffer.create (String.length s + 10) in
    Buffer.add_string b symbol_prefix;
    String.iter
      (function
        | ('A'..'Z' | 'a'..'z' | '0'..'9' | '_') as c -> Buffer.add_char b c
        | c -> Printf.bprintf b "$%02x" (Char.code c)
        (* CR mshinwell: may need another char instead of '$' *)
      )
      s;
    Buffer.contents b

type arm_arch = ARMv4 | ARMv5 | ARMv5TE | ARMv6 | ARMv6T2 | ARMv7
type arm_fpu = Soft | VFPv2 | VFPv3_D16 | VFPv3

module Directive = struct
  type constant =
    | Const of int64
    | Float32 of float
    | Float64 of float
    | This
    | Named_thing of string
    | Add of constant * constant
    | Sub of constant * constant

  type thing_after_label =
    | Code
    | Machine_width_data

  type t =
    | Align of { bytes : int; }
    | Bytes of string
    | Comment of string
    | Global of string
    | Const8 of constant
    | Const16 of constant
    | Const32 of constant
    | Const64 of constant
    | New_label of string * thing_after_label
    | Section of string list * string option * string list
    | Space of { bytes : int; }
    | Cfi_adjust_cfa_offset of int
    | Cfi_endproc
    | Cfi_startproc
    | File of { file_num : int option; filename : string; }
    | Indirect_symbol of string
    | Loc of { file_num : int; line : int; col : int; }
    | Private_extern of string
(*    | Set of string * constant*)
    | Size of string * constant
    | Sleb128 of constant
    | Type of string * string
    | Uleb128 of constant
    | Direct_assignment of string * constant

  let bprintf = Printf.bprintf

  let string_of_string_literal s =
    let buf = Buffer.create (String.length s + 2) in
    let last_was_escape = ref false in
    for i = 0 to String.length s - 1 do
      let c = s.[i] in
      if c >= '0' && c <= '9' then
        if !last_was_escape
        then Printf.bprintf buf "\\%o" (Char.code c)
        else Buffer.add_char buf c
      else if c >= ' ' && c <= '~' && c <> '"' (* '"' *) && c <> '\\' then begin
        Buffer.add_char buf c;
        last_was_escape := false
      end else begin
        Printf.bprintf buf "\\%o" (Char.code c);
        last_was_escape := true
      end
    done;
    Buffer.contents buf

  let buf_bytes_directive buf ~directive s =
    let pos = ref 0 in
    for i = 0 to String.length s - 1 do
      if !pos = 0
      then begin
        if i > 0 then Buffer.add_char buf '\n';
        Buffer.add_char buf '\t';
        Buffer.add_string buf directive;
        Buffer.add_char buf '\t';
      end
      else Buffer.add_char buf ',';
      Printf.bprintf buf "%d" (Char.code s.[i]);
      incr pos;
      if !pos >= 16 then begin pos := 0 end
    done

  let rec cst buf = function
    | Named_thing _ | Const _ | Float _ | This as c -> scst buf c
    | Add (c1, c2) -> bprintf buf "%a + %a" scst c1 scst c2
    | Sub (c1, c2) -> bprintf buf "%a - %a" scst c1 scst c2

  and scst buf = function
    | This -> Buffer.add_string buf "."
    | Named_thing name -> Buffer.add_string buf name
    | Const n when n <= 0x7FFF_FFFFL && n >= -0x8000_0000L ->
      Buffer.add_string buf (Int64.to_string n)
    | Const n -> bprintf buf "0x%Lx" n
    | Float32 f -> bprintf buf "\t.long\t0x%lx\n" f
    | Float64 f ->
      begin match TS.machine_width with
      | Sixty_four ->
        bprintf buf "\t.quad\t0x%Lx # %.12g" f (Int64.float_of_bits f)
      | Thirty_two ->
        let lo = Int64.logand x 0xFFFF_FFFFL
        and hi = Int64.shift_right_logical x 32 in
        emit_printf "\t.long\t0x%Lx, 0x%Lx\n"
          directive
          (if Arch.big_endian then hi else lo)
          (if Arch.big_endian then lo else hi)
      end
    | Add (c1, c2) -> bprintf buf "(%a + %a)" scst c1 scst c2
    | Sub (c1, c2) -> bprintf buf "(%a - %a)" scst c1 scst c2

  let print_gas buf = function
    | Align { bytes = n; } ->
      (* Mac OS X's assembler interprets the integer n as a 2^n alignment;
         same apparently for gas on POWER. *)
      let n =
        match TS.system, TS.platform with
        | MacOS, _
        | _, POWER -> Misc.log2 n
        | _ -> n
      in
      bprintf buf "\t.align\t%d" n
    | Const8 n -> bprintf buf "\t.byte\t%a" cst n
    | Const16 n ->
      begin match TS.system with
      | Solaris -> bprintf buf "\t.value\t%a" cst n
      | _ ->
        (* Apple's documentation says that ".word" is i386-specific, so we use
            ".short" instead. *)
        bprintf buf "\t.short\t%a" cst n
      end
    | Const32 n -> bprintf buf "\t.long\t%a" cst n
    | Const64 n -> bprintf buf "\t.quad\t%a" cst n
    | Bytes s ->
      begin match TS.system, TS.platform with
      | Solaris, _
      | _, POWER -> buf_bytes_directive buf ~directive:".byte" s
      | _ -> bprintf buf "\t.ascii\t\"%s\"" (string_of_string_literal s)
      end
    | Comment s -> bprintf buf "\t\t\t\t/* %s */" s
    | Global s ->
      bprintf buf "\t.globl\t%s" s;
      begin match current_section_is_text (), TS.platform with
      | false, (POWER | ARM | AArch64 | S390) ->
        bprintf buf "	.type	{emit_symbol %a}, @object\n" string_of_symbol s
      | _ -> ()
      end
    | New_label (s, _typ) -> bprintf buf "%s:" s
    | Section ([".data" ], _, _) -> bprintf buf "\t.data"
    | Section ([".text" ], _, _) -> bprintf buf "\t.text"
    | Section (name, flags, args) ->
      bprintf buf "\t.section %s" (String.concat "," name);
      begin match flags with
      | None -> ()
      | Some flags -> bprintf buf ",%S" flags
      end;
      begin match args with
      | [] -> ()
      | _ -> bprintf buf ",%s" (String.concat "," args)
      end
    | Space { bytes; } ->
      begin match TS.system with
      | Solaris -> bprintf buf "\t.zero\t%d" bytes
      | _ -> bprintf buf "\t.space\t%d" bytes
      end
    | Cfi_adjust_cfa_offset n -> bprintf buf "\t.cfi_adjust_cfa_offset %d" n
    | Cfi_endproc -> bprintf buf "\t.cfi_endproc"
    | Cfi_offset { reg; offset; } ->
      bprintf buf "\t.cfi_offset %d, %d" reg offset
    | Cfi_startproc -> bprintf buf "\t.cfi_startproc"
    | File { file_num = None; filename; } ->
      bprintf buf "\t.file\t\"%s\""
    | File { file_num = Some file_num; filename; } ->
      bprintf buf "\t.file\t%d\t\"%s\""
        file_num (string_of_string_literal filename)
    | Indirect_symbol s -> bprintf buf "\t.indirect_symbol %s" s
    | Loc { file_num; line; col; } ->
      (* PR#7726: Location.none uses column -1, breaks LLVM assembler *)
      if col >= 0 then bprintf buf "\t.loc\t%d\t%d\t%d" file_num line col
      else bprintf buf "\t.loc\t%d\t%d" file_num line
    | Private_extern s -> bprintf buf "\t.private_extern %s" s
(*
    | Set (arg1, arg2) -> bprintf buf "\t.set %s, %a" arg1 cst arg2
*)
    | Size (s, c) -> bprintf buf "\t.size %s,%a" s cst c
    | Sleb128 c -> bprintf buf "\t.sleb128 %a" cst c
    | Type (s, typ) -> bprintf buf "\t.type %s,%s" s typ
    | Uleb128 c -> bprintf buf "\t.uleb128 %a" cst c
    | Direct_assignment (var, const) ->
      begin match TS.system with
      | MacOS -> bprintf buf "%s = %a" var cst const
      | _ -> failwith "Cannot emit Direct_assignment"
      end

  let rec cst buf = function
    | Named_thing _ | Const _ | This as c -> scst buf c
    | Add (c1, c2) -> bprintf buf "%a + %a" scst c1 scst c2
    | Sub (c1, c2) -> bprintf buf "%a - %a" scst c1 scst c2

  and scst buf = function
    | This -> Buffer.add_string buf "THIS BYTE"
    | Named_thing name -> Buffer.add_string buf name
    | Const n when n <= 0x7FFF_FFFFL && n >= -0x8000_0000L ->
        Buffer.add_string buf (Int64.to_string n)
    | Const n -> bprintf buf "0%LxH" n
    | Add (c1, c2) -> bprintf buf "(%a + %a)" scst c1 scst c2
    | Sub (c1, c2) -> bprintf buf "(%a - %a)" scst c1 scst c2

  let print_masm buf = function
    | Align { bytes; } -> bprintf buf "\tALIGN\t%d" bytes
    | Bytes s -> buf_bytes_directive buf ~directive:"BYTE" s
    | Comment s -> bprintf buf " ; %s " s
    | Const8 n -> bprintf buf "\tBYTE\t%a" cst n
    | Const16 n -> bprintf buf "\tWORD\t%a" cst n
    | Const32 n -> bprintf buf "\tDWORD\t%a" cst n
    | Const64 n -> bprintf buf "\tQUAD\t%a" cst n
    | Global s -> bprintf buf "\tPUBLIC\t%s" s
    | Section ([".data"], None, []) -> bprintf buf "\t.DATA"
    | Section ([".text"], None, []) -> bprintf buf "\t.CODE"
    | Section _ -> assert false
    | Space { bytes; } -> bprintf buf "\tBYTE\t%d DUP (?)" bytes
    | New_label (label, Code) -> bprintf buf "%s:" label
    | New_label (label, Machine_width_data) ->
      begin match TS.machine_width () with
      | Thirty_two -> bprintf buf "%s LABEL DWORD" label
      | Sixty_four -> bprintf buf "%s LABEL QWORD" label
      end
    | Cfi_adjust_cfa_offset _
    | Cfi_endproc
    | Cfi_startproc
    | File _
    | Indirect_symbol _
    | Loc _
    | Private_extern _
    | Size _
    | Sleb128 _
    | Type _
    | Uleb128 _
    | Direct_assignment _
    | POWER_abi_version _
    | ARM_architecture _
    | ARM_floating_point_unit _ ->
      Misc.fatal_error "Unsupported asm directive for MASM"

  let print b t =
    if TS.masm then print_masm b t
    else print_gas b t
end

let rec lower_constant (cst : constant) : Directive.constant =
  match cst with
  | Const i -> Const i
  | This -> This
  | Label lbl -> Named_thing (string_of_label lbl)
  | Symbol sym -> Named_thing (string_of_symbol sym)
  | Add (cst1, cst2) -> Add (lower_constant cst1, lower_constant cst2)
  | Sub (cst1, cst2) -> Sub (lower_constant cst1, lower_constant cst2)

let emit_ref = ref None

let emit (d : Directive.t) =
  match !emit_ref with
  | Some emit -> emit d
  | None -> Misc.fatal_error "initialize not called"

let section segment flags args = emit (Section (segment, flags, args))
let align ~bytes = emit (Align { bytes; })
let cfi_adjust_cfa_offset ~bytes =
  if Config.asm_cfi_supported then emit (Cfi_adjust_cfa_offset bytes)
let cfi_endproc () =
  if Config.asm_cfi_supported then emit Cfi_endproc
let cfi_offset ~reg ~offset =
  if Config.asm_cfi_supported then emit (Cfi_offset { reg; offset; })
let cfi_startproc () =
  if Config.asm_cfi_supported then emit Cfi_startproc
let comment s = emit (Comment s)
let direct_assignment var cst =
  emit (Direct_assignment (string_of_symbol var, lower_constant cst))
let file ~file_num ~file_name =
  emit (File { file_num = Some file_num; filename = file_name; })
let global s = emit (Global (string_of_symbol s))
let indirect_symbol s = emit (Indirect_symbol (string_of_symbol s))
let loc ~file_num ~line ~col = emit (Loc { file_num; line; col; })
let private_extern s = emit (Private_extern (string_of_symbol s))
let size name cst = emit (Size (string_of_symbol name, (lower_constant cst)))
let sleb128 i = emit (Sleb128 (Const i))
let space ~bytes = emit (Space { bytes; })
let string s = emit (Bytes s)
let type_ name ~type_ = emit (Type (string_of_symbol name, type_))
let uleb128 i = emit (Uleb128 (Const i))

let const8 cst = emit (Const8 (lower_constant cst))
let const16 cst = emit (Const16 (lower_constant cst))
let const32 cst = emit (Const32 (lower_constant cst))
let const64 cst = emit (Const64 (lower_constant cst))

let size symbol =
  match TS.system with
  | Gnu | Linux -> size symbol (Sub (This, Symbol symbol))
  | _ -> ()

let label label_name = const64 (Label label_name)

let define_label label_name =
  let typ : Directive.thing_after_label =
    if current_section_is_text () then Code
    else Machine_width_data
  in
  emit (New_label (string_of_label label_name, typ))

let sections_seen = ref []

let switch_to_section (section : section) =
  let first_occurrence =
    if List.mem section !sections_seen then false
    else begin
      sections_seen := section::!sections_seen;
      true
    end
  in
  current_section := Some section;
  let section_name, middle_part, attrs =
    let text () = [".text"], None, [] in
    let data () = [".data"], None, [] in
    match section, TS.system with
    | Text, _ -> text ()
    | Data, _ -> data ()
    | DWARF dwarf, MacOS ->
      let name =
        match dwarf with
        | Debug_info -> "__debug_info"
        | Debug_abbrev -> "__debug_abbrev"
        | Debug_aranges -> "__debug_aranges"
        | Debug_loc -> "__debug_loc"
        | Debug_str -> "__debug_str"
        | Debug_line -> "__debug_line"
      in
      ["__DWARF"; name], None, ["regular"; "debug"]
    | DWARF dwarf, _ ->
      let name =
        match dwarf with
        | Debug_info -> ".debug_info"
        | Debug_abbrev -> ".debug_abbrev"
        | Debug_aranges -> ".debug_aranges"
        | Debug_loc -> ".debug_loc"
        | Debug_str -> ".debug_str"
        | Debug_line -> ".debug_line"
      in
      let middle_part =
        if first_occurrence then
          Some ""
        else
          None
      in
      let attrs =
        if first_occurrence then
          ["%progbits"]
        else
          []
      in
      [name], middle_part, attrs
    | (Eight_byte_literals | Sixteen_byte_literals) when TS.hardware = S390 ->
      (* CR mshinwell: Is this really needed? *)
      [".rodata"], None, []
    | Sixteen_byte_literals, MacOS ->
      ["__TEXT";"__literal16"], None, ["16byte_literals"]
    | Sixteen_byte_literals, (Mingw64 | Cygwin) ->
      [".rdata"], Some "dr", []
    | Sixteen_byte_literals, Win64 ->
      data ()
    | Sixteen_byte_literals, _ ->
      [".rodata.cst8"], Some "a", ["@progbits"]
    | Eight_byte_literals, MacOS ->
      ["__TEXT";"__literal8"], None, ["8byte_literals"]
    | Eight_byte_literals, (Mingw64 | Cygwin) ->
      [".rdata"], Some "dr", []
    | Eight_byte_literals, Win64 ->
      data ()
    | Eight_byte_literals, _ ->
      [".rodata.cst8"], Some "a", ["@progbits"]
    | Jump_tables, (Mingw64 | Cygwin) ->
      [".rdata"], Some "dr", []
    | Jump_tables, (MacOS | Win64) ->
      text () (* with LLVM/OS X and MASM, use the text segment *)
    | Jump_tables, _ ->
      [".rodata"], None, []
    | Read_only_data, (Mingw64 | Cygwin) ->
      [".rdata"], Some "dr", []
    | Read_only_data, _ ->
      [".rodata"], None, []
    | POWER power, _ ->
      begin match TS.hardware with
      | POWER ->
        begin match power with
        | Function_descriptors ->
          [".opd"], Some "aw", []
        | Table_of_contents ->
          [".toc"], Some "aw", []
        end
      | X86_32
      | X86_64
      | ARM
      | AArch64
      | SPARC
      | S390 ->
        Misc.fatal_error "Cannot switch to POWER section on non-POWER \
          architecture"
      end
  in
  emit (Section (section_name, middle_part, attrs));
  if first_occurrence then begin
    define_label (label_for_section section)
  end

let cached_strings = ref ([] : (string * Cmm.label) list)
let temp_var_counter = ref 0

let reset () =
  cached_strings := [];
  sections_seen := [];
  temp_var_counter := 0

let initialize ~emit =
  emit_ref := Some emit;
  reset ();
  switch_to_section Text;
  begin match TS.system with
  | MacOS -> ()
  | _ ->
    if !Clflags.debug then begin
      (* Forward label references are illegal in gas.  Just put them in for
         all assemblers, they won't harm. *)
      switch_to_section Data;
      switch_to_section Eight_byte_literals;
      switch_to_section Sixteen_byte_literals;
      switch_to_section (DWARF Debug_info);
      switch_to_section (DWARF Debug_abbrev);
      switch_to_section (DWARF Debug_aranges);
      switch_to_section (DWARF Debug_loc);
      switch_to_section (DWARF Debug_str);
      switch_to_section (DWARF Debug_line)
    end
  end;
  emit (File { file_num = None; filename = ""; })  (* PR#7037 *)

let define_symbol' symbol_name =
  let typ : Directive.thing_after_label =
    if current_section_is_text () then Code
    else Machine_width_data
  in
  emit (New_label (string_of_symbol symbol_name, typ))

let define_symbol sym =
  define_symbol' (Linkage_name.to_string (Symbol.label sym))

let define_function_symbol' symbol_name =
  if not (current_section_is_text ()) then begin
    Misc.fatal_error "define_function_symbol' can only be called when \
      emitting to a text section"
  end;
  define_symbol' symbol_name;
  begin match TS.system with
  | Gnu | Linux -> type_ symbol_name ~type_:"@function"
  | _ -> ()
  end

let symbol' sym =
  match TS.machine_width with
  | Thirty_two -> const32 (Symbol sym)
  | Sixty_four -> const64 (Symbol sym)

let symbol sym =
  symbol' (Linkage_name.to_string (Symbol.label sym))

let symbol_plus_offset sym ~offset_in_bytes =
  let sym = Linkage_name.to_string (Symbol.label sym) in
  let offset_in_bytes = Targetint.to_int64 offset_in_bytes in
  const64 (Add (Symbol sym, Const offset_in_bytes))

let new_temp_var () =
  let id = !temp_var_counter in
  incr temp_var_counter;
  Printf.sprintf "Ltemp%d" id

(* To avoid callers of this module having to worry about whether operands
   involved in displacement calculations are or are not relocatable, and to
   guard against clever linkers doing e.g. branch relaxation at link time, we
   always force such calculations to be done in a relocatable manner at
   link time.  On Mac OS X this requires use of the "direct assignment"
   syntax rather than ".set": the latter forces expressions to be evaluated
   as absolute assembly-time constants. *)

let force_relocatable expr =
  match TS.system with
  | MacOS ->
    let temp = new_temp_var () in
    direct_assignment temp expr;
    Symbol temp  (* not really a symbol, but this is OK (same below) *)
  | _ ->
    expr

let between_symbols ~upper ~lower =
  let upper = Linkage_name.to_string (Symbol.label upper) in
  let lower = Linkage_name.to_string (Symbol.label lower) in
  let expr = Sub (Symbol upper, Symbol lower) in
  const64 (force_relocatable expr)

let between_labels_32bit ~upper ~lower =
  let expr = Sub (Label upper, Label lower) in
  const32 (force_relocatable expr)

let between_symbol_and_label_offset ~upper ~lower ~offset_upper =
  let lower = Linkage_name.to_string (Symbol.label lower) in
  let offset_upper = Targetint.to_int64 offset_upper in
  let expr =
    Sub (
      Add (Label upper, Const offset_upper),
      Symbol lower)
  in
  const64 (force_relocatable expr)

let between_this_and_label_offset_32bit ~upper ~offset_upper =
  let offset_upper = Targetint.to_int64 offset_upper in
  let expr =
    Sub (Add (Label upper, Const offset_upper), This)
  in
  const32 (force_relocatable expr)

let constant_with_width expr ~(width : width) =
  match width with
  (* CR mshinwell: make sure this behaves properly on 32-bit platforms.
     This width is independent of the natural machine width. *)
  | Thirty_two -> const32 expr
  | Sixty_four -> const64 expr

let offset_into_section_label ~section ~label:upper ~width =
  let lower = label_for_section section in
  let expr : constant =
    (* The meaning of a label reference depends on the assembler:
       - On Mac OS X, it appears to be the distance from the label back to
         the start of the assembly file.
       - On gas, it is the distance from the label back to the start of the
         current section. *)
    match TS.system with
    | MacOS ->
      let temp = new_temp_var () in
      direct_assignment temp (Sub (Label upper, Label lower));
      Symbol temp
    | _ ->
      Label upper
  in
  constant_with_width expr ~width

let offset_into_section_symbol ~section ~symbol ~width =
  let lower = label_for_section section in
  let upper = Linkage_name.to_string (Symbol.label symbol) in
  let expr : constant =
    (* The same thing as for [offset_into_section_label] applies here. *)
    match TS.system with
    | MacOS ->
      let temp = new_temp_var () in
      direct_assignment temp (Sub (Symbol upper, Label lower));
      Symbol temp
    | _ -> Symbol upper
  in
  constant_with_width expr ~width

let int8 i =
  const8 (Const (Int64.of_int (Int8.to_int i)))

let int16 i =
  const16 (Const (Int64.of_int (Int16.to_int i)))

let int32 i =
  const32 (Const (Int64.of_int32 i))

let int64 i =
  const64 (Const i)

let nativeint n =
  match TS.machine_width with
  | Thirty_two -> const32 (Const (Int64.of_nativeint n))
  | Sixty_four -> const64 (Const (Int64.of_nativeint n))

let hex_float f =
  const64 (Hex_float f)

let target_address addr =
  match Targetint.repr addr with
  | Int32 i -> int32 i
  | Int64 i -> int64 i

let cache_string str =
  match List.assoc str !cached_strings with
  | label -> label
  | exception Not_found ->
    let label = Cmm.new_label () in
    cached_strings := (str, label) :: !cached_strings;
    label

let emit_cached_strings () =
  List.iter (fun (str, label_name) ->
      define_label label_name;
      string str;
      int8 Int8.zero)
    !cached_strings;
  cached_strings := []

let mark_stack_non_executable () =
  match TS.system with
  | Linux -> section [".note.GNU-stack"] (Some "") [ "%progbits" ]
  | _ -> ()

let arm_architecture_version arch =

(** Set the ARM floating-point unit kind. *)
val arm_floating_point_unit fpu =
  begin match !arch with
  | ARMv4   -> `	.arch	armv4t\n`
  | ARMv5   -> `	.arch	armv5t\n`
  | ARMv5TE -> `	.arch	armv5te\n`
  | ARMv6   -> `	.arch	armv6\n`
  | ARMv6T2 -> `	.arch	armv6t2\n`
  | ARMv7   -> `	.arch	armv7-a\n`
  end;
  begin match !fpu with
    Soft      -> `	.fpu	softvfp\n`
  | VFPv2     -> `	.fpu	vfpv2\n`
  | VFPv3_D16 -> `	.fpu	vfpv3-d16\n`
  | VFPv3     -> `	.fpu	vfpv3\n`
  end;
