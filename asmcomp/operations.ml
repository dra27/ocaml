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

module Amd64 = struct
  type addressing_mode =
      Ibased of string * int
    | Iindexed of int
    | Iindexed2 of int
    | Iscaled of int * int
    | Iindexed2scaled of int * int
  type specific_operation =
      Ilea of addressing_mode
    | Istore_int of nativeint * addressing_mode * bool
    | Ioffset_loc of int * addressing_mode
    | Ifloatarithmem of float_operation * addressing_mode
    | Ibswap of int
    | Isqrtf
    | Ifloatsqrtf of addressing_mode
    | Isextend32
    | Izextend32
  and float_operation =
      Ifloatadd | Ifloatsub | Ifloatmul | Ifloatdiv

  let print_addressing printreg addr ppf arg =
    match addr with
    | Ibased(s, 0) ->
        Format.fprintf ppf "\"%s\"" s
    | Ibased(s, n) ->
        Format.fprintf ppf "\"%s\" + %i" s n
    | Iindexed n ->
        let idx = if n <> 0 then Printf.sprintf " + %i" n else "" in
        Format.fprintf ppf "%a%s" printreg arg.(0) idx
    | Iindexed2 n ->
        let idx = if n <> 0 then Printf.sprintf " + %i" n else "" in
        Format.fprintf ppf "%a + %a%s" printreg arg.(0) printreg arg.(1) idx
    | Iscaled(scale, n) ->
        let idx = if n <> 0 then Printf.sprintf " + %i" n else "" in
        Format.fprintf ppf "%a  * %i%s" printreg arg.(0) scale idx
    | Iindexed2scaled(scale, n) ->
        let idx = if n <> 0 then Printf.sprintf " + %i" n else "" in
        Format.fprintf ppf "%a + %a * %i%s" printreg arg.(0)
                                            printreg arg.(1) scale idx

  let print_specific_operation printreg op ppf arg =
    match op with
    | Ilea addr -> print_addressing printreg addr ppf arg
    | Istore_int(n, addr, is_assign) ->
        Format.fprintf ppf "[%a] := %nd %s"
           (print_addressing printreg addr) arg n
           (if is_assign then "(assign)" else "(init)")
    | Ioffset_loc(n, addr) ->
        Format.fprintf ppf "[%a] +:= %i" (print_addressing printreg addr) arg n
    | Isqrtf ->
        Format.fprintf ppf "sqrtf %a" printreg arg.(0)
    | Ifloatsqrtf addr ->
       Format.fprintf ppf "sqrtf float64[%a]"
               (print_addressing printreg addr) [|arg.(0)|]
    | Ifloatarithmem(op, addr) ->
        let op_name = function
        | Ifloatadd -> "+f"
        | Ifloatsub -> "-f"
        | Ifloatmul -> "*f"
        | Ifloatdiv -> "/f" in
        Format.fprintf ppf "%a %s float64[%a]" printreg arg.(0) (op_name op)
                     (print_addressing printreg addr)
                     (Array.sub arg 1 (Array.length arg - 1))
    | Ibswap i ->
        Format.fprintf ppf "bswap_%i %a" i printreg arg.(0)
    | Isextend32 ->
        Format.fprintf ppf "sextend32 %a" printreg arg.(0)
    | Izextend32 ->
        Format.fprintf ppf "zextend32 %a" printreg arg.(0)
end

module Arm64 = struct
  type addressing_mode =
    | Iindexed of int
    | Ibased of string * int
  type specific_operation =
    | Ifar_poll of { return_label: cmm_label option }
    | Ifar_alloc of { bytes : int; dbginfo : Debuginfo.alloc_dbginfo }
    | Ifar_intop_checkbound
    | Ifar_intop_imm_checkbound of { bound : int; }
    | Ishiftarith of arith_operation * int
    | Ishiftcheckbound of { shift : int; }
    | Ifar_shiftcheckbound of { shift : int; }
    | Imuladd
    | Imulsub
    | Inegmulf
    | Imuladdf
    | Inegmuladdf
    | Imulsubf
    | Inegmulsubf
    | Isqrtf
    | Ibswap of int
    | Imove32
    | Isignext of int
  and arith_operation =
      Ishiftadd
    | Ishiftsub

  let print_addressing printreg addr ppf arg =
    match addr with
    | Iindexed n ->
        printreg ppf arg.(0);
        if n <> 0 then Format.fprintf ppf " + %i" n
    | Ibased(s, 0) ->
        Format.fprintf ppf "\"%s\"" s
    | Ibased(s, n) ->
        Format.fprintf ppf "\"%s\" + %i" s n

  let print_specific_operation printreg op ppf arg =
    match op with
    | Ifar_poll _ ->
      Format.fprintf ppf "(far) poll"
    | Ifar_alloc { bytes; } ->
      Format.fprintf ppf "(far) alloc %i" bytes
    | Ifar_intop_checkbound ->
      Format.fprintf ppf "%a (far) check > %a" printreg arg.(0) printreg arg.(1)
    | Ifar_intop_imm_checkbound { bound; } ->
      Format.fprintf ppf "%a (far) check > %i" printreg arg.(0) bound
    | Ishiftarith(op, shift) ->
        let op_name = function
        | Ishiftadd -> "+"
        | Ishiftsub -> "-" in
        let shift_mark =
         if shift >= 0
         then Printf.sprintf "<< %i" shift
         else Printf.sprintf ">> %i" (-shift) in
        Format.fprintf ppf "%a %s %a %s"
         printreg arg.(0) (op_name op) printreg arg.(1) shift_mark
    | Ishiftcheckbound { shift; } ->
        Format.fprintf ppf "check %a >> %i > %a" printreg arg.(0) shift
          printreg arg.(1)
    | Ifar_shiftcheckbound { shift; } ->
        Format.fprintf ppf
          "(far) check %a >> %i > %a" printreg arg.(0) shift printreg arg.(1)
    | Imuladd ->
        Format.fprintf ppf "(%a * %a) + %a"
          printreg arg.(0)
          printreg arg.(1)
          printreg arg.(2)
    | Imulsub ->
        Format.fprintf ppf "-(%a * %a) + %a"
          printreg arg.(0)
          printreg arg.(1)
          printreg arg.(2)
    | Inegmulf ->
        Format.fprintf ppf "-f (%a *f %a)"
          printreg arg.(0)
          printreg arg.(1)
    | Imuladdf ->
        Format.fprintf ppf "%a +f (%a *f %a)"
          printreg arg.(0)
          printreg arg.(1)
          printreg arg.(2)
    | Inegmuladdf ->
        Format.fprintf ppf "(-f %a) -f (%a *f %a)"
          printreg arg.(0)
          printreg arg.(1)
          printreg arg.(2)
    | Imulsubf ->
        Format.fprintf ppf "%a -f (%a *f %a)"
          printreg arg.(0)
          printreg arg.(1)
          printreg arg.(2)
    | Inegmulsubf ->
        Format.fprintf ppf "(-f %a) +f (%a *f %a)"
          printreg arg.(0)
          printreg arg.(1)
          printreg arg.(2)
    | Isqrtf ->
        Format.fprintf ppf "sqrtf %a"
          printreg arg.(0)
    | Ibswap n ->
        Format.fprintf ppf "bswap%i %a" n
          printreg arg.(0)
    | Imove32 ->
        Format.fprintf ppf "move32 %a"
          printreg arg.(0)
    | Isignext n ->
        Format.fprintf ppf "signext%d %a"
          n printreg arg.(0)
end

module Power = struct
type specific_operation =
      Imultaddf
    | Imultsubf
    | Ialloc_far of { bytes : int; dbginfo : Debuginfo.alloc_dbginfo }
    | Ipoll_far of { return_label : cmm_label option }
    | Icheckbound_far
    | Icheckbound_imm_far of int
  type addressing_mode =
      Ibased of string * int
    | Iindexed of int
    | Iindexed2

  let print_addressing printreg addr ppf arg =
    match addr with
    | Ibased(s, n) ->
        let idx = if n <> 0 then Printf.sprintf " + %i" n else "" in
        Format.fprintf ppf "\"%s\"%s" s idx
    | Iindexed n ->
        let idx = if n <> 0 then Printf.sprintf " + %i" n else "" in
        Format.fprintf ppf "%a%s" printreg arg.(0) idx
    | Iindexed2 ->
        Format.fprintf ppf "%a + %a" printreg arg.(0) printreg arg.(1)

  let print_specific_operation printreg op ppf arg =
    match op with
    | Imultaddf ->
        Format.fprintf ppf "%a *f %a +f %a"
          printreg arg.(0) printreg arg.(1) printreg arg.(2)
    | Imultsubf ->
        Format.fprintf ppf "%a *f %a -f %a"
          printreg arg.(0) printreg arg.(1) printreg arg.(2)
    | Ialloc_far { bytes; _ } ->
        Format.fprintf ppf "alloc_far %d" bytes
    | Ipoll_far _ ->
        Format.fprintf ppf "poll_far"
    | Icheckbound_far ->
        Format.fprintf ppf "check_far > %a %a" printreg arg.(0) printreg arg.(1)
    | Icheckbound_imm_far n ->
        Format.fprintf ppf "check_far > %a %d" printreg arg.(0) n
end

module Riscv = struct
  type specific_operation =
    | Imultaddf of bool
    | Imultsubf of bool
  type addressing_mode =
    | Iindexed of int

  let print_addressing printreg addr ppf arg =
    match addr with
    | Iindexed n ->
        let idx = if n <> 0 then Printf.sprintf " + %i" n else "" in
        Format.fprintf ppf "%a%s" printreg arg.(0) idx

  let print_specific_operation printreg op ppf arg =
    match op with
    | Imultaddf false ->
        Format.fprintf ppf "%a *f %a +f %a"
          printreg arg.(0) printreg arg.(1) printreg arg.(2)
    | Imultaddf true ->
        Format.fprintf ppf "-f (%a *f %a +f %a)"
          printreg arg.(0) printreg arg.(1) printreg arg.(2)
    | Imultsubf false ->
        Format.fprintf ppf "%a *f %a -f %a"
          printreg arg.(0) printreg arg.(1) printreg arg.(2)
    | Imultsubf true ->
        Format.fprintf ppf "-f (%a *f %a -f %a)"
          printreg arg.(0) printreg arg.(1) printreg arg.(2)
end

module S390x = struct
  type specific_operation =
      Imultaddf
    | Imultsubf
  type addressing_mode =
    | Iindexed of int
    | Iindexed2 of int

  let print_addressing printreg addr ppf arg =
    match addr with
    | Iindexed n ->
        let idx = if n <> 0 then Printf.sprintf " + %i" n else "" in
        Format.fprintf ppf "%a%s" printreg arg.(0) idx
    | Iindexed2 n ->
        let idx = if n <> 0 then Printf.sprintf " + %i" n else "" in
        Format.fprintf ppf "%a + %a%s" printreg arg.(0) printreg arg.(1) idx

  let print_specific_operation printreg op ppf arg =
    match op with
    | Imultaddf ->
        Format.fprintf ppf "%a *f %a +f %a"
          printreg arg.(0) printreg arg.(1) printreg arg.(2)
    | Imultsubf ->
        Format.fprintf ppf "%a *f %a -f %a"
          printreg arg.(0) printreg arg.(1) printreg arg.(2)
end

type addressing_modes =
| Amd64 of Amd64.addressing_mode
| Arm64 of Arm64.addressing_mode
| Power of Power.addressing_mode
| Riscv of Riscv.addressing_mode
| S390x of S390x.addressing_mode

let print_addressing printreg = function
| Amd64 addr -> Amd64.print_addressing printreg addr
| Arm64 addr -> Arm64.print_addressing printreg addr
| Power addr -> Power.print_addressing printreg addr
| Riscv addr -> Riscv.print_addressing printreg addr
| S390x addr -> S390x.print_addressing printreg addr

type specific_operations =
| Amd64 of Amd64.specific_operation
| Arm64 of Arm64.specific_operation
| Power of Power.specific_operation
| Riscv of Riscv.specific_operation
| S390x of S390x.specific_operation

let print_specific_operation printreg = function
| Amd64 op -> Amd64.print_specific_operation printreg op
| Arm64 op -> Arm64.print_specific_operation printreg op
| Power op -> Power.print_specific_operation printreg op
| Riscv op -> Riscv.print_specific_operation printreg op
| S390x op -> S390x.print_specific_operation printreg op

let operation_is_pure = function
| Amd64 (Ilea _ | Ibswap _ | Isqrtf | Isextend32 | Izextend32
         | Ifloatarithmem _ | Ifloatsqrtf _) -> true
| Amd64 _ -> false
| Arm64 (Ifar_alloc _ | Ifar_intop_checkbound | Ifar_intop_imm_checkbound _
         | Ishiftcheckbound _ | Ifar_shiftcheckbound _) -> false
| Arm64 _ -> true
| Power (Ialloc_far _ | Ipoll_far _) -> false
| Power _ -> true
| Riscv _ -> true
| S390x _ -> true

let operation_can_raise = function
| Amd64 _ -> false
| Arm64 (Ifar_alloc _ | Ifar_intop_checkbound | Ifar_intop_imm_checkbound _
         | Ishiftcheckbound _ | Ifar_shiftcheckbound _) -> true
| Arm64 _ -> false
| Power (Ialloc_far _ | Ipoll_far _) -> true
| Power _ -> false
| Riscv _ -> false
| S390x _ -> false

module type S = sig
  type addressing_mode
  type specific_operation

  val box_addressing_mode : addressing_mode -> addressing_modes
  val unbox_addressing_mode : addressing_modes -> addressing_mode

  val box_specific_operation : specific_operation -> specific_operations
  val unbox_specific_operation : specific_operations -> specific_operation

  val size_addr : int
  val size_int : int
  val size_float : int

  val identity_addressing : addressing_mode
  val offset_addressing : addressing_mode -> int -> addressing_mode
end
