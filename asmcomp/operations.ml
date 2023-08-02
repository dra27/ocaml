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
end

module Riscv = struct
  type specific_operation =
    | Imultaddf of bool
    | Imultsubf of bool
  type addressing_mode =
    | Iindexed of int
end

module S390x = struct
  type specific_operation =
      Imultaddf
    | Imultsubf
  type addressing_mode =
    | Iindexed of int
    | Iindexed2 of int
end
