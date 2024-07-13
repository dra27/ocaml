(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*                        David Allsopp, Tarides                          *)
(*                                                                        *)
(*   Copyright 2024 David Allsopp Ltd.                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

(** Installation configuration. Includes functions for parsing the harness's
    command line. *)

(** Compiler installation's configuration *)
type t = {
  has_ocamlnat: bool;
    (** {v [$(INSTALL_OCAMLNAT)] v} - {v Makefile.build_config v} *)
  has_ocamlopt: bool;
    (** {v [$(NATIVE_COMPILER)] v} - {v Makefile.config v} *)
  has_relative_libdir: string option;
    (** {v $(LIBDIR_REL) v} - {v Makefile.build_config v} *)
  has_runtime_search: bool option;
    (** Not implemented; always None. *)
  launcher_searches_for_ocamlrun: bool;
    (** Indicates whether bytecode executables in the compiler distribution use
        a launcher that is capable of searching PATH to find ocamlrun. At
        present, only native Windows has this behaviour. *)
  target_launcher_searches_for_ocamlrun: bool;
    (** Indicates whether the executable launcher used by ocamlc is capable of
        searching PATH to find ocamlrun. At present, only native Windows has
        this behaviour. *)
  bytecode_shebangs_by_default: bool;
    (** True if ocamlc uses a shebang-style header rather than an executable
        header for tendered bytecode executables. *)
  libraries: string list list
    (** Sorted list of basenames of libraries to test.
        Derived from {v [$(OTHERLIBRARIES)] v} - {v Makefile.config v} *)
}

val parse_cmdline:
  string array
    -> (config:t * pwd:string * prefix:string *
        bindir:string * bindir_suffix:string *
        libdir:string * libdir_suffix:string *
        pp_path:(test_root:string -> Format.formatter -> string -> unit) *
        summarise_only:bool * verbose:bool, int * string) Result.t

val ocamlc_fails_after_rename : t -> bool
