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

type cmm_label = int
(* Do not introduce a dependency to Cmm *)

module Amd64 : sig
  (* Specific operations for the AMD64 processor *)

  type addressing_mode =
      Ibased of string * int              (* symbol + displ *)
    | Iindexed of int                     (* reg + displ *)
    | Iindexed2 of int                    (* reg + reg + displ *)
    | Iscaled of int * int                (* reg * scale + displ *)
    | Iindexed2scaled of int * int        (* reg + reg * scale + displ *)

  type specific_operation =
      Ilea of addressing_mode             (* "lea" gives scaled adds *)
    | Istore_int of nativeint * addressing_mode * bool
                                          (* Store an integer constant *)
    | Ioffset_loc of int * addressing_mode (* Add a constant to a location *)
    | Ifloatarithmem of float_operation * addressing_mode
                                         (* Float arith operation with memory *)
    | Ibswap of int                      (* endianness conversion *)
    | Isqrtf                             (* Float square root *)
    | Ifloatsqrtf of addressing_mode     (* Float square root from memory *)
    | Isextend32                         (* 32 to 64 bit conversion with sign
                                            extension *)
    | Izextend32                         (* 32 to 64 bit conversion with zero
                                            extension *)

  and float_operation =
      Ifloatadd | Ifloatsub | Ifloatmul | Ifloatdiv
end

module Arm64 : sig
  (* Addressing modes *)

  type addressing_mode =
    | Iindexed of int                     (* reg + displ *)
    | Ibased of string * int              (* global var + displ *)

  (* We do not support the reg + shifted reg addressing mode, because
     what we really need is reg + shifted reg + displ,
     and this is decomposed in two instructions (reg + shifted reg -> tmp,
     then addressing tmp + displ). *)

  (* Specific operations *)

  type specific_operation =
    | Ifar_poll of { return_label: cmm_label option }
    | Ifar_alloc of { bytes : int; dbginfo : Debuginfo.alloc_dbginfo }
    | Ifar_intop_checkbound
    | Ifar_intop_imm_checkbound of { bound : int; }
    | Ishiftarith of arith_operation * int
    | Ishiftcheckbound of { shift : int; }
    | Ifar_shiftcheckbound of { shift : int; }
    | Imuladd       (* multiply and add *)
    | Imulsub       (* multiply and subtract *)
    | Inegmulf      (* floating-point negate and multiply *)
    | Imuladdf      (* floating-point multiply and add *)
    | Inegmuladdf   (* floating-point negate, multiply and add *)
    | Imulsubf      (* floating-point multiply and subtract *)
    | Inegmulsubf   (* floating-point negate, multiply and subtract *)
    | Isqrtf        (* floating-point square root *)
    | Ibswap of int (* endianness conversion *)
    | Imove32       (* 32-bit integer move *)
    | Isignext of int (* sign extension *)

  and arith_operation =
      Ishiftadd
    | Ishiftsub
end

module Power : sig
  (* Specific operations *)

  type specific_operation =
      Imultaddf                           (* multiply and add *)
    | Imultsubf                           (* multiply and subtract *)
    | Ialloc_far of                       (* allocation in large functions *)
        { bytes : int; dbginfo : Debuginfo.alloc_dbginfo }
    | Ipoll_far of { return_label : cmm_label option }
                                          (* poll point in large functions *)
    | Icheckbound_far                     (* bounds check in large functions *)
    | Icheckbound_imm_far of int          (* bounds check in large functions *)

  (* Addressing modes *)

  type addressing_mode =
      Ibased of string * int              (* symbol + displ *)
    | Iindexed of int                     (* reg + displ *)
    | Iindexed2                           (* reg + reg *)
end

module Riscv : sig
  (* Specific operations *)

  type specific_operation =
    | Imultaddf of bool        (* multiply, optionally negate, and add *)
    | Imultsubf of bool        (* multiply, optionally negate, and subtract *)

  (* Addressing modes *)

  type addressing_mode =
    | Iindexed of int                     (* reg + displ *)
end

module S390x : sig
  (* Specific operations *)

  type specific_operation =
      Imultaddf                           (* multiply and add *)
    | Imultsubf                           (* multiply and subtract *)

  (* Addressing modes *)

  type addressing_mode =
    | Iindexed of int                     (* reg + displ *)
    | Iindexed2 of int                    (* reg + reg + displ *)
end

type addressing_modes =
| Amd64 of Amd64.addressing_mode
| Arm64 of Arm64.addressing_mode
| Power of Power.addressing_mode
| Riscv of Riscv.addressing_mode
| S390x of S390x.addressing_mode

type specific_operations =
| Amd64 of Amd64.specific_operation
| Arm64 of Arm64.specific_operation
| Power of Power.specific_operation
| Riscv of Riscv.specific_operation
| S390x of S390x.specific_operation

module type S = sig
  (* XXX Temporary! *)
  val command_line_options : (string * Arg.spec * string) list

  type addressing_mode
  type specific_operation

  val box_addressing_mode : addressing_mode -> addressing_modes
  val unbox_addressing_mode : addressing_modes -> addressing_mode

  val box_specific_operation : specific_operation -> specific_operations
  val unbox_specific_operation : specific_operations -> specific_operation

  val big_endian : bool

  val allow_unaligned_access : bool

  val division_crashes_on_overflow : bool

  val size_addr : int
  val size_int : int
  val size_float : int

  val identity_addressing : addressing_mode
  val offset_addressing : addressing_mode -> int -> addressing_mode
end

(* Printing operations and addressing modes *)

val print_addressing :
  (Format.formatter -> 'a -> unit) -> addressing_modes ->
  Format.formatter -> 'a array -> unit

val print_specific_operation :
  (Format.formatter -> 'a -> unit) -> specific_operations ->
  Format.formatter -> 'a array -> unit

(* Specific operations that are pure *)

val operation_is_pure : specific_operations -> bool

(* Specific operations that can raise *)

val operation_can_raise : specific_operations -> bool
