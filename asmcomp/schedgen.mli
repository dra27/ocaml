(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*             Xavier Leroy, projet Cristal, INRIA Rocquencourt           *)
(*                                                                        *)
(*   Copyright 1997 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

(* Instruction scheduling *)

module Make (Arch : Operations.S) (_ : module type of Processor) : sig
  type operation =
    (Arch.addressing_mode, Arch.specific_operation) Mach.gen_operation
  class virtual scheduler_generic : Arch.addressing_mode -> object
    (* Can be overridden by processor description *)
    method virtual oper_issue_cycles : operation -> int
        (* Number of cycles needed to issue the given operation *)
    method virtual oper_latency : operation -> int
        (* Number of cycles needed to complete the given operation *)
    method reload_retaddr_issue_cycles : int
        (* Number of cycles needed to issue a Lreloadretaddr operation *)
    method reload_retaddr_latency : int
        (* Number of cycles needed to complete a Lreloadretaddr operation *)
    method oper_in_basic_block : operation -> bool
        (* Says whether the given operation terminates a basic block *)
    method is_store : operation -> bool
        (* Says whether the given operation is a memory store
           or an atomic load. *)
    method is_load : operation -> bool
        (* Says whether the given operation is a non-atomic memory load *)
    method is_checkbound : operation -> bool
        (* Says whether the given operation is a checkbound *)
    (* Entry point *)
    method schedule_fundecl : Linear.fundecl -> Linear.fundecl
  end
end
