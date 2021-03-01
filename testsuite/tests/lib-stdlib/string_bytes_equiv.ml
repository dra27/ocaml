(* TEST
   ocaml_script_as_argument = "true"
   * toplevel
*)

(* This test trips if Bytes and String don't have equivalent interfaces. The
   response to this test's failure is either to make the modules equivalent
   again or code an exception below which ignores it, typically by adding a
   val declaration to STRING or BYTES. If an item must differ (e.g. an external
   declaration), then it may be overidden in the EXTERNALS signature. *)

[@@@ocaml.alert "-deprecated"]

(* Load the signatures of String and Bytes as STRING and BYTES where *)
type bytes = string;;

#sig_use "string.mli"
#sig_use "bytes.mli"

(* Convert external declarations to val *)
module type EXTERNALS = sig
  val length : string -> int
  val get : string -> int -> char
  val set : string -> int -> char
  val create : int -> string
  val unsafe_get : string -> int -> char
  val unsafe_set : string -> int -> char
  val unsafe_fill : string -> int -> int -> char -> unit
end

module type STRING = sig
  include STRING

  include EXTERNALS

  (* Strring obviously doesn't need {of,to}_string *)
  val of_string : string -> bytes
  val to_string : bytes -> string

  val unsafe_to_string : bytes -> string
  val unsafe_of_string : string -> bytes

  (* Functions which make no sense in String *)
  val blit_string : string -> int -> bytes -> int -> int -> unit
  val extend : bytes -> int -> int -> bytes
  val sub_string : bytes -> int -> int -> string

  external unsafe_blit : bytes -> int -> bytes -> int -> int -> unit
    = "caml_blit_bytes" [@@noalloc]
  external unsafe_blit_string : string -> int -> bytes -> int -> int -> unit
    = "caml_blit_string" [@@noalloc]

  val set_uint8 : bytes -> int -> int -> unit
  val set_int8 : bytes -> int -> int -> unit
  val set_uint16_ne : bytes -> int -> int -> unit
  val set_uint16_be : bytes -> int -> int -> unit
  val set_uint16_le : bytes -> int -> int -> unit
  val set_int16_ne : bytes -> int -> int -> unit
  val set_int16_be : bytes -> int -> int -> unit
  val set_int16_le : bytes -> int -> int -> unit
  val set_int32_ne : bytes -> int -> int32 -> unit
  val set_int32_be : bytes -> int -> int32 -> unit
  val set_int32_le : bytes -> int -> int32 -> unit
  val set_int64_ne : bytes -> int -> int64 -> unit
  val set_int64_be : bytes -> int -> int64 -> unit
  val set_int64_le : bytes -> int -> int64 -> unit
end

module type BYTES = sig
  include BYTES

  include EXTERNALS

  (* Bytes obviously doesn't need {of,to}_bytes *)
  val of_bytes : bytes -> string
  val to_bytes : string -> bytes
end

(* Check that the two signatures are equivalent *)
module String_includes(_ : BYTES) = struct end
module M(Bytes: STRING) = String_includes(Bytes)
module Bytes_includes(_: STRING) = struct end
module M(String: BYTES) = Bytes_includes(String)
