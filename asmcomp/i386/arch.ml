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

(* Machine-specific command-line options *)

let fast_math = ref false

let command_line_options =
  [ "-ffast-math", Arg.Set fast_math,
      " Inline trigonometric and exponential functions" ]

open Format

include Specifics

let spacetime_node_hole_pointer_is_live_before _specific_op = false

(* Sizes, endianness *)

let big_endian = false

let size_addr = 4
let size_int = 4
let size_float = 8

let allow_unaligned_access = true

(* Behavior of division *)

let division_crashes_on_overflow = true

(* Operations on addressing modes *)

let identity_addressing = Iindexed 0

let offset_addressing addr delta =
  match addr with
    Ibased(s, n) -> Ibased(s, n + delta)
  | Iindexed n -> Iindexed(n + delta)
  | Iindexed2 n -> Iindexed2(n + delta)
  | Iscaled(scale, n) -> Iscaled(scale, n + delta)
  | Iindexed2scaled(scale, n) -> Iindexed2scaled(scale, n + delta)

let num_args_addressing = function
    Ibased _ -> 0
  | Iindexed _ -> 1
  | Iindexed2 _ -> 2
  | Iscaled _ -> 1
  | Iindexed2scaled _ -> 2

(* Printing operations and addressing modes *)

let print_addressing printreg addr ppf arg =
  match addr with
  | Ibased(s, 0) ->
      fprintf ppf "\"%s\"" s
  | Ibased(s, n) ->
      fprintf ppf "\"%s\" + %i" s n
  | Iindexed n ->
      let idx = if n <> 0 then Printf.sprintf " + %i" n else "" in
      fprintf ppf "%a%s" printreg arg.(0) idx
  | Iindexed2 n ->
      let idx = if n <> 0 then Printf.sprintf " + %i" n else "" in
      fprintf ppf "%a + %a%s" printreg arg.(0) printreg arg.(1) idx
  | Iscaled(scale, n) ->
      let idx = if n <> 0 then Printf.sprintf " + %i" n else "" in
      fprintf ppf "%a  * %i%s" printreg arg.(0) scale idx
  | Iindexed2scaled(scale, n) ->
      let idx = if n <> 0 then Printf.sprintf " + %i" n else "" in
      fprintf ppf "%a + %a * %i%s" printreg arg.(0) printreg arg.(1) scale idx

let print_specific_operation printreg op ppf arg =
  match op with
  | Ilea addr -> print_addressing printreg addr ppf arg
  | Istore_int(n, addr, is_assign) ->
      fprintf ppf "[%a] := %nd %s"
         (print_addressing printreg addr) arg n
         (if is_assign then "(assign)" else "(init)")
  | Istore_symbol(lbl, addr, is_assign) ->
      fprintf ppf "[%a] := \"%s\" %s"
         (print_addressing printreg addr) arg lbl
         (if is_assign then "(assign)" else "(init)")
  | Ioffset_loc(n, addr) ->
      fprintf ppf "[%a] +:= %i" (print_addressing printreg addr) arg n
  | Ipush ->
      fprintf ppf "push ";
      for i = 0 to Array.length arg - 1 do
        if i > 0 then fprintf ppf ", ";
        printreg ppf arg.(i)
      done
  | Ipush_int n ->
      fprintf ppf "push %s" (Nativeint.to_string n)
  | Ipush_symbol s ->
      fprintf ppf "push \"%s\"" s
  | Ipush_load addr ->
      fprintf ppf "push [%a]" (print_addressing printreg addr) arg
  | Ipush_load_float addr ->
      fprintf ppf "pushfloat [%a]" (print_addressing printreg addr) arg
  | Isubfrev ->
      fprintf ppf "%a -f(rev) %a" printreg arg.(0) printreg arg.(1)
  | Idivfrev ->
      fprintf ppf "%a /f(rev) %a" printreg arg.(0) printreg arg.(1)
  | Ifloatarithmem(double, op, addr) ->
      let op_name = function
      | Ifloatadd -> "+f"
      | Ifloatsub -> "-f"
      | Ifloatsubrev -> "-f(rev)"
      | Ifloatmul -> "*f"
      | Ifloatdiv -> "/f"
      | Ifloatdivrev -> "/f(rev)" in
      let long = if double then "float64" else "float32" in
      fprintf ppf "%a %s %s[%a]" printreg arg.(0) (op_name op) long
       (print_addressing printreg addr) (Array.sub arg 1 (Array.length arg - 1))
  | Ifloatspecial name ->
      fprintf ppf "%s " name;
      for i = 0 to Array.length arg - 1 do
        if i > 0 then fprintf ppf ", ";
        printreg ppf arg.(i)
      done

(* Stack alignment constraints *)

let stack_alignment =
  match Config.system with
  | "win32" -> 4     (* MSVC *)
  | _ -> 16
  (* PR#6038: GCC and Clang seem to require 16-byte alignment nowadays *)
