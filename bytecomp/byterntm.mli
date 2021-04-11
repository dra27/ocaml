(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*            David Allsopp, University of Cambridge & Tarides            *)
(*                                                                        *)
(*   Copyright 2025 David Allsopp Ltd.                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

(** Parser for RNTM in bytecode executables. Parses both the RNTM section and
    the shebang launcher produced by {!Bytelink}. *)

val read_runtime :
  Bytesections.section_table -> in_channel
  -> (string * (string * Misc.RuntimeID.t option) option *
      (Misc.RuntimeID.t list * Misc.RuntimeID.t list) option) option
(** Returns the runtime used by this tendered/standalone image. If the runtime
    used cannot be parsed, or the image was linked using -without-runtime, then
    [None] is returned.

    The triple [runtime, bindir, alternates] encodes all three search
    modes. In [Absolute] mode, [alternates = None] and in [Search] mode [bindir]
    is None. [bindir] consists of the directory to try and an optional
    Runtime ID to mangle [runtime] with (if mangling is not in use, or the
    executable was linked with -use-runtime, this will be [None]). The two lists
    in [alternates] specify the valid and invalid runtime IDs to try (these
    lists will both be empty if mangling is not in use). *)
