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

(** Runtime and distribution magic numbers

  Values in this module are fixed for a given release of OCaml - i.e. nothing in
  this module is controlled by [configure.ac].

  {b Warning:} this module is unstable and part of
  {{!Compiler_libs}compiler-libs}.

*)

val exec_magic_number: string
(** Magic number for bytecode executable files *)

val cmi_magic_number: string
(** Magic number for compiled interface files *)

val cmo_magic_number: string
(** Magic number for object bytecode files *)

val cma_magic_number: string
(** Magic number for archive files *)

val cmx_magic_number_flambda: string
(** Magic number for compilation unit descriptions (flambda mode) *)

val cmxa_magic_number_flambda: string
(** Magic number for libraries of compilation unit descriptions (flambda
    mode) *)

val cmx_magic_number_clambda: string
(** Magic number for compilation unit descriptions (clambda mode) *)

val cmxa_magic_number_clambda: string
(** Magic number for libraries of compilation unit descriptions (clambda
    mode) *)

val ast_intf_magic_number: string
(** Magic number for file holding an interface syntax tree *)

val ast_impl_magic_number: string
(** Magic number for file holding an implementation syntax tree *)

val cmxs_magic_number: string
(** Magic number for dynamically-loadable plugins *)

val cmt_magic_number: string
(** Magic number for compiled interface files *)

val linear_magic_number: string
(** Magic number for Linear internal representation files *)

val max_tag: int
(** Biggest tag that can be stored in the header of a regular block. *)

val lazy_tag : int
(** Normally the same as Obj.lazy_tag.  Separate definition because
    of technical reasons for bootstrapping. *)

val max_young_wosize: int
(** Maximal size of arrays that are directly allocated in the
    minor heap *)

val stack_threshold: int
(** Size in words of safe area at bottom of VM stack,
    see runtime/caml/config.h *)

val stack_safety_margin: int
(** Size in words of the safety margin between the bottom of
    the stack and the stack pointer. This margin can be used by
    intermediate computations of some instructions, or the event
    handler. *)

(** Possible values and properties for {!Config_settings.system} *)
module System : sig
  type t =
  | S_unknown   (** Unidentified architecture and system *)
  | S_linux     (** GNU/Linux *)
  | S_gnu       (** GNU/Hurd *)
  | S_dragonfly (** DragonFly BSD *)
  | S_freebsd   (** FreeBSD *)
  | S_netbsd    (** NetBSD *)
  | S_openbsd   (** OpenBSD *)
  | S_macosx    (** Apple macOS *)
  | S_solaris   (** Oracle Solaris *)
  | S_beos      (** Haiku *)
  | S_cygwin    (** Cygwin (technically both 32 and 64-bit *)
  | S_mingw     (** Microsoft Windows; mingw-w64 32-bit GCC (i686) *)
  | S_mingw64   (** Microsoft Windows; mingw-w64 64-bit GCC (x86_64) *)
  | S_win32     (** Microsoft Windows; Visual Studio 32-bit (x86) *)
  | S_win64     (** Microsoft Windows; Visual Studio 64-bit (x64) *)

  val to_string: t -> string

  val uses_masm: t -> bool
  (** [uses_masm system] is [true] if [system] uses the Microsoft Macro
      Assembler (MASM). *)

  val is_windows: t -> bool
  (** [is_windows system] is [true] if [system] is native Windows {b or}
      Cygwin. *)

  val is_macOS: t -> bool
  (** [is_macOS system] is [true] if [system] is Apple macOS, Mac OS X,
      etc. *)

  val is_solaris: t -> bool
  (** [is_solaris system] is [true] if [system] is Oracle Solaris, or
      equivalent. *)

  val is_bsd_system: t -> bool
  (** [is_bsd_system] is [true] for FreeBSD, NetBSD and OpenBSD. *)
end

(**/**)

val merlin : bool

(**/**)
