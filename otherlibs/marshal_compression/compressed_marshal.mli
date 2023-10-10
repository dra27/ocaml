(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*        Xavier Leroy, Collège de France and Inria project Cambium       *)
(*                                                                        *)
(*   Copyright 2023 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*   Copyright 2023 David Allsopp Ltd.                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

(** Marshaling values with compression. Functions behave as in {!Marshal}, but
    the result is compressed using zstd, if available. If zstd is not available,
    these functions behave exactly as their counterparts in the Marshal module.

    It is necessary to link programs with this library to be able to unmarshal
    compressed values, but the support is transparently enabled in the
    unmarshaler (see {!Marshal.compression_supported} *)

external to_channel: out_channel -> 'a -> Marshal.extern_flags list -> unit
  = "caml_compressed_output_value"
(** [Compression.Marshal.to_channel chan v flags] writes the representation
    of [v] on channel [chan].
    The [flags] argument is as described in {!Marshal.to_channel}.
    If compression is supported, the marshaled data
    representing value [v] is compressed before being written to
    channel [chan].
    If compression is not supported, this function behaves like
    {!Marshal.to_channel}. *)

external to_bytes: 'a -> Marshal.extern_flags list -> bytes
  = "caml_compressed_output_value_to_bytes"
(** [Marshal.to_bytes v flags] returns a byte sequence containing
   the representation of [v].
   The [flags] argument has the same meaning as for
   {!Marshal.to_channel}.
   @since 4.02 *)

external to_string: 'a -> Marshal.extern_flags list -> string
  = "caml_compressed_output_value_to_string"
(** Same as [to_bytes] but return the result as a string instead of
    a byte sequence. *)
