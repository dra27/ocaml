(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*                 David Allsopp, OCaml Labs, Cambridge.                  *)
(*                                                                        *)
(*   Copyright 2020 MetaStack Solutions Ltd.                              *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

val dump_directory_cmis : string -> unit
  (** Displays the MD5 of the interface of each .cmi file found in dir,
      in order. Used by the build system only (but needed before the
      compiler-libs are built.) *)
