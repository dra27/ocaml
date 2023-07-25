(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*            Gabriel Scherer, projet Parsifal, INRIA Saclay              *)
(*                                                                        *)
(*   Copyright 2016 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

(** Magic numbers.

    a typical magic number is "Caml1999I011"; it is formed of an
    alphanumeric prefix, here Caml1990I, followed by a version,
    here 011. The prefix identifies the kind of the versioned data:
    here the I indicates that it is the magic number for .cmi files.

    All magic numbers have the same byte length, [magic_length], and
    this is important for users as it gives them the number of bytes
    to read to obtain the byte sequence that should be a magic
    number. Typical user code will look like:
    {[
      let ic = open_in_bin path in
      let magic =
        try really_input_string ic Magic_number.magic_length
        with End_of_file -> ... in
      match Magic_number.parse magic with
      | Error parse_error -> ...
      | Ok info -> ...
    ]}

    A given compiler version expects one specific version for each
    kind of object file, and will fail if given an unsupported
    version. Because versions grow monotonically, you can compare
    the parsed version with the expected "current version" for
    a kind, to tell whether the wrong-magic object file comes from
    the past or from the future.

    An example of code block that expects the "currently supported version"
    of a given kind of magic numbers, here [Cmxa], is as follows:
    {[
      let ic = open_in_bin path in
      begin
        try Magic_number.(expect_current Cmxa (get_info ic)) with
        | Parse_error error -> ...
        | Unexpected error -> ...
      end;
      ...
    ]}

    Parse errors distinguish inputs that are [Not_a_magic_number str],
    which are likely to come from the file being completely
    different, and [Truncated str], raised by headers that are the
    (possibly empty) prefix of a valid magic number.

    Unexpected errors correspond to valid magic numbers that are not
    the one expected, either because it corresponds to a different
    kind, or to a newer or older version.

    The helper functions [explain_parse_error] and [explain_unexpected_error]
    will generate a textual explanation of each error,
    for use in error messages.

    @since 4.11
*)

type native_obj_config = {
  flambda : bool;
}
(** native object files have a format and magic number that depend
   on certain native-compiler configuration parameters. This
   configuration space is expressed by the [native_obj_config]
   type. *)

val native_obj_config : native_obj_config
(** the native object file configuration of the active/configured compiler. *)

type version = int

type kind =
  | Exec
  | Cmi | Cmo | Cma
  | Cmx of native_obj_config | Cmxa of native_obj_config
  | Cmxs
  | Cmt | Ast_impl | Ast_intf

type info = {
  kind: kind;
  version: version;
  (** Note: some versions of the compiler use the same [version] suffix
      for all kinds, but others use different versions counters for different
      kinds. We may only assume that versions are growing monotonically
      (not necessarily always by one) between compiler versions. *)
}

type raw = string
(** the type of raw magic numbers,
    such as "Caml1999A027" for the .cma files of OCaml 4.10 *)

(** {3 Parsing magic numbers} *)

type parse_error =
  | Truncated of string
  | Not_a_magic_number of string

val explain_parse_error : kind option -> parse_error -> string
(** Produces an explanation for a parse error. If no kind is provided,
    we use an unspecific formulation suggesting that any compiler-produced
    object file would have been satisfying. *)

val parse : raw -> (info, parse_error) result
(** Parses a raw magic number *)

val read_info : in_channel -> (info, parse_error) result
(** Read a raw magic number from an input channel.

    If the data read [str] is not a valid magic number, it can be
    recovered from the [Truncated str | Not_a_magic_number str]
    payload of the [Error parse_error] case.

    If parsing succeeds with an [Ok info] result, we know that
    exactly [magic_length] bytes have been consumed from the
    input_channel.

    If you also wish to enforce that the magic number
    is at the current version, see {!read_current_info} below.
 *)

val magic_length : int
(** all magic numbers take the same number of bytes *)


(** {3 Checking that magic numbers are current} *)

type 'a unexpected = { expected : 'a; actual : 'a }
type unexpected_error =
  | Kind of kind unexpected
  | Version of kind * version unexpected

val check_current : kind -> info -> (unit, unexpected_error) result
(** [check_current kind info] checks that the provided magic [info]
    is the current version of [kind]'s magic header. *)

val explain_unexpected_error : unexpected_error -> string
(** Provides an explanation of the [unexpected_error]. *)

type error =
  | Parse_error of parse_error
  | Unexpected_error of unexpected_error

val read_current_info :
  expected_kind:kind option -> in_channel -> (info, error) result
(** Read a magic number as [read_info],
    and check that it is the current version as its kind.
    If the [expected_kind] argument is [None], any kind is accepted. *)


(** {3 Information on magic numbers} *)

val string_of_kind : kind -> string
(** a user-printable string for a kind, eg. "exec" or "cmo", to use
    in error messages. *)

val human_name_of_kind : kind -> string
(** a user-meaningful name for a kind, eg. "executable file" or
    "bytecode object file", to use in error messages. *)

val current_raw : kind -> raw
(** the current magic number of each kind *)

val current_version : kind -> version
(** the current version of each kind *)


(** {3 Raw representations}

    Mainly for internal usage and testing. *)

type raw_kind = string
(** the type of raw magic numbers kinds,
    such as "Caml1999A" for .cma files *)

val parse_kind : raw_kind -> kind option
(** parse a raw kind into a kind *)

val raw_kind : kind -> raw_kind
(** the current raw representation of a kind.

    In some cases the raw representation of a kind has changed
    over compiler versions, so other files of the same kind
    may have different raw kinds.
    Note that all currently known cases are parsed correctly by [parse_kind].
*)

val raw : info -> raw
(** A valid raw representation of the magic number.

    Due to past and future changes in the string representation of
    magic numbers, we cannot guarantee that the raw strings returned
    for past and future versions actually match the expectations of
    those compilers. The representation is accurate for current
    versions, and it is correctly parsed back into the desired
    version by the parsing functions above.
 *)

val all_kinds : kind list
