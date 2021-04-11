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

module Uchar = struct
  include Uchar

  type utf_decode = int

  let decode_bits = 24

  let[@inline] utf_decode_length d = (d lsr decode_bits) land 0b111
  let[@inline] utf_decode_uchar d = unsafe_of_int (d land 0xFFFFFF)
  let[@inline] utf_decode n u = ((8 lor n) lsl decode_bits) lor (to_int u)
  let[@inline] utf_decode_invalid n = (n lsl decode_bits) lor (to_int rep)

  let utf_16_byte_length u = match to_int u with
  | u when u < 0 -> assert false
  | u when u <= 0xFFFF -> 2
  | u when u <= 0x10FFFF -> 4
  | _ -> assert false
end

module Bytes = struct
  include Bytes

  external unsafe_get_uint8 : bytes -> int -> int = "%bytes_unsafe_get"

  external unsafe_set_uint16_ne : bytes -> int -> int -> unit
                                = "%caml_bytes_set16u"

  external swap16 : int -> int = "%bswap16"

  let unsafe_set_uint16_le b i x =
    if Sys.big_endian
    then unsafe_set_uint16_ne b i (swap16 x)
    else unsafe_set_uint16_ne b i x

  let dec_invalid = Uchar.utf_decode_invalid
  let[@inline] dec_ret n u = Uchar.utf_decode n (Uchar.unsafe_of_int u)

  let[@inline] not_in_x80_to_xBF b = b lsr 6 <> 0b10
  let[@inline] not_in_xA0_to_xBF b = b lsr 5 <> 0b101
  let[@inline] not_in_x80_to_x9F b = b lsr 5 <> 0b100
  let[@inline] not_in_x90_to_xBF b = b < 0x90 || 0xBF < b
  let[@inline] not_in_x80_to_x8F b = b lsr 4 <> 0x8

  let[@inline] utf_8_uchar_2 b0 b1 =
    ((b0 land 0x1F) lsl 6) lor
    ((b1 land 0x3F))

  let[@inline] utf_8_uchar_3 b0 b1 b2 =
    ((b0 land 0x0F) lsl 12) lor
    ((b1 land 0x3F) lsl 6) lor
    ((b2 land 0x3F))

  let[@inline] utf_8_uchar_4 b0 b1 b2 b3 =
    ((b0 land 0x07) lsl 18) lor
    ((b1 land 0x3F) lsl 12) lor
    ((b2 land 0x3F) lsl 6) lor
    ((b3 land 0x3F))

  let get_utf_8_uchar b i =
    let b0 = get_uint8 b i in (* raises if [i] is not a valid index. *)
    let get = unsafe_get_uint8 in
    let max = length b - 1 in
    match Char.unsafe_chr b0 with (* See The Unicode Standard, Table 3.7 *)
    | '\x00' .. '\x7F' -> dec_ret 1 b0
    | '\xC2' .. '\xDF' ->
        let i = i + 1 in if i > max then dec_invalid 1 else
        let b1 = get b i in if not_in_x80_to_xBF b1 then dec_invalid 1 else
        dec_ret 2 (utf_8_uchar_2 b0 b1)
    | '\xE0' ->
        let i = i + 1 in if i > max then dec_invalid 1 else
        let b1 = get b i in if not_in_xA0_to_xBF b1 then dec_invalid 1 else
        let i = i + 1 in if i > max then dec_invalid 2 else
        let b2 = get b i in if not_in_x80_to_xBF b2 then dec_invalid 2 else
        dec_ret 3 (utf_8_uchar_3 b0 b1 b2)
    | '\xE1' .. '\xEC' | '\xEE' .. '\xEF' ->
        let i = i + 1 in if i > max then dec_invalid 1 else
        let b1 = get b i in if not_in_x80_to_xBF b1 then dec_invalid 1 else
        let i = i + 1 in if i > max then dec_invalid 2 else
        let b2 = get b i in if not_in_x80_to_xBF b2 then dec_invalid 2 else
        dec_ret 3 (utf_8_uchar_3 b0 b1 b2)
    | '\xED' ->
        let i = i + 1 in if i > max then dec_invalid 1 else
        let b1 = get b i in if not_in_x80_to_x9F b1 then dec_invalid 1 else
        let i = i + 1 in if i > max then dec_invalid 2 else
        let b2 = get b i in if not_in_x80_to_xBF b2 then dec_invalid 2 else
        dec_ret 3 (utf_8_uchar_3 b0 b1 b2)
    | '\xF0' ->
        let i = i + 1 in if i > max then dec_invalid 1 else
        let b1 = get b i in if not_in_x90_to_xBF b1 then dec_invalid 1 else
        let i = i + 1 in if i > max then dec_invalid 2 else
        let b2 = get b i in if not_in_x80_to_xBF b2 then dec_invalid 2 else
        let i = i + 1 in if i > max then dec_invalid 3 else
        let b3 = get b i in if not_in_x80_to_xBF b3 then dec_invalid 3 else
        dec_ret 4 (utf_8_uchar_4 b0 b1 b2 b3)
    | '\xF1' .. '\xF3' ->
        let i = i + 1 in if i > max then dec_invalid 1 else
        let b1 = get b i in if not_in_x80_to_xBF b1 then dec_invalid 1 else
        let i = i + 1 in if i > max then dec_invalid 2 else
        let b2 = get b i in if not_in_x80_to_xBF b2 then dec_invalid 2 else
        let i = i + 1 in if i > max then dec_invalid 3 else
        let b3 = get b i in if not_in_x80_to_xBF b3 then dec_invalid 3 else
        dec_ret 4 (utf_8_uchar_4 b0 b1 b2 b3)
    | '\xF4' ->
        let i = i + 1 in if i > max then dec_invalid 1 else
        let b1 = get b i in if not_in_x80_to_x8F b1 then dec_invalid 1 else
        let i = i + 1 in if i > max then dec_invalid 2 else
        let b2 = get b i in if not_in_x80_to_xBF b2 then dec_invalid 2 else
        let i = i + 1 in if i > max then dec_invalid 3 else
        let b3 = get b i in if not_in_x80_to_xBF b3 then dec_invalid 3 else
        dec_ret 4 (utf_8_uchar_4 b0 b1 b2 b3)
    | _ -> dec_invalid 1

  let set_utf_16le_uchar b i u =
    let set = unsafe_set_uint16_le in
    let max = length b - 1 in
    if i < 0 || i > max then invalid_arg "index out of bounds" else
    match Uchar.to_int u with
    | u when u < 0 -> assert false
    | u when u <= 0xFFFF ->
        let last = i + 1 in
        if last > max then 0 else (set b i u; 2)
    | u when u <= 0x10FFFF ->
        let last = i + 3 in
        if last > max then 0 else
        let u' = u - 0x10000 in
        let hi = (0xD800 lor (u' lsr 10)) in
        let lo = (0xDC00 lor (u' land 0x3FF)) in
        set b i hi; set b (i + 2) lo; 4
    | _ -> assert false
end

module Char = struct
  include Char

  module Ascii = struct
    let is_letter = function 'A' .. 'Z' | 'a' .. 'z' -> true | _ -> false
  end
end

module In_channel = struct
  type t = Stdlib.in_channel

  external unsafe_input_bigarray :
    t -> _ Bigarray.Array1.t -> int -> int -> int
    = "caml_ml_input_bigarray"

  let with_open openfun s f =
    let ic = openfun s in
    Fun.protect ~finally:(fun () -> close_in_noerr ic)
      (fun () -> f ic)

  let with_open_bin s f =
    with_open open_in_bin s f

  (* Read up to [len] bytes into [buf], starting at [ofs]. Return total bytes
     read. *)
  let read_upto ic buf ofs len =
    let rec loop ofs len =
      if len = 0 then ofs
      else begin
        let r = input ic buf ofs len in
        if r = 0 then
          ofs
        else
          loop (ofs + r) (len - r)
      end
    in
    loop ofs len - ofs

  (* Best effort attempt to return a buffer with >= (ofs + n) bytes of storage,
     and such that it coincides with [buf] at indices < [ofs].

     The returned buffer is equal to [buf] itself if it already has sufficient
     free space.

     The returned buffer may have *fewer* than [ofs + n] bytes of storage if
     this number is > [Sys.max_string_length]. However the returned buffer will
     *always* have > [ofs] bytes of storage. In the limiting case when [ofs =
     len = Sys.max_string_length] (so that it is not possible to resize the
     buffer at all), an exception is raised. *)

  let ensure buf ofs n =
    let len = Bytes.length buf in
    if len >= ofs + n then buf
    else begin
      let new_len = ref len in
      while !new_len < ofs + n do
        new_len := 2 * !new_len + 1
      done;
      let new_len = !new_len in
      let new_len =
        if new_len <= Sys.max_string_length then
          new_len
        else if ofs < Sys.max_string_length then
          Sys.max_string_length
        else
          failwith "In_channel.input_all: channel content \
                    is larger than maximum string length"
      in
      let new_buf = Bytes.create new_len in
      Bytes.blit buf 0 new_buf 0 ofs;
      buf
    end

  let input_all ic =
    let chunk_size = 65536 in (* IO_BUFFER_SIZE *)
    let initial_size =
      try
        in_channel_length ic - pos_in ic
      with Sys_error _ ->
        -1
    in
    let initial_size = if initial_size < 0 then chunk_size else initial_size in
    let initial_size =
      if initial_size <= Sys.max_string_length then
        initial_size
      else
        Sys.max_string_length
    in
    let buf = Bytes.create initial_size in
    let nread = read_upto ic buf 0 initial_size in
    if nread < initial_size then (* EOF reached, buffer partially filled *)
      Bytes.sub_string buf 0 nread
    else begin (* nread = initial_size, maybe EOF reached *)
      match input_char ic with
      | exception End_of_file ->
          (* EOF reached, buffer is completely filled *)
          Bytes.unsafe_to_string buf
      | c ->
          (* EOF not reached *)
          let rec loop buf ofs =
            let buf = ensure buf ofs chunk_size in
            let rem = Bytes.length buf - ofs in
            (* [rem] can be < [chunk_size] if buffer size close to
               [Sys.max_string_length] *)
            let r = read_upto ic buf ofs rem in
            if r < rem then (* EOF reached *)
              Bytes.sub_string buf 0 (ofs + r)
            else (* r = rem *)
              loop buf (ofs + rem)
          in
          let buf = ensure buf nread (chunk_size + 1) in
          Bytes.set buf nread c;
          loop buf (nread + 1)
    end

  let rec unsafe_really_input_bigarray ic buf ofs len =
    if len <= 0 then Some () else begin
      let r = unsafe_input_bigarray ic buf ofs len in
      if r = 0
      then None
      else unsafe_really_input_bigarray ic buf (ofs + r) (len - r)
    end

  let really_input_bigarray ic buf ofs len =
    if ofs < 0 || len < 0 || ofs > Bigarray.Array1.dim buf - len
    then invalid_arg "really_input_bigarray"
    else unsafe_really_input_bigarray ic buf ofs len

  let [@tail_mod_cons] rec input_lines ic =
    match Stdlib.input_line ic with
    | line -> line :: input_lines ic
    | exception End_of_file -> []

  let rec fold_lines f accu ic =
    match Stdlib.input_line ic with
    | line -> fold_lines f (f accu line) ic
    | exception End_of_file -> accu

  let set_binary_mode = Stdlib.set_binary_mode_in
end

module Int = struct
  include Int

  let max x y : t = if x >= y then x else y
end

module List = struct
  include List

  let rec find_map f = function
    | [] -> None
    | x :: l ->
       begin match f x with
         | Some _ as result -> result
         | None -> find_map f l
       end

  let take_while p l =
    let[@tail_mod_cons] rec aux = function
      | x::l when p x -> x::aux l
      | _rest -> []
    in
    aux l

  let rec drop_while p = function
    | x::l when p x -> drop_while p l
    | rest -> rest

  let fold_left_map f accu l =
    let rec aux accu l_accu = function
      | [] -> accu, rev l_accu
      | x :: l ->
          let accu, x = f accu x in
          aux accu (x :: l_accu) l in
    aux accu [] l
end

module Out_channel = struct
  type t = Stdlib.out_channel

  let with_open openfun s f =
    let oc = openfun s in
    Fun.protect ~finally:(fun () -> Stdlib.close_out_noerr oc)
      (fun () -> f oc)

  let with_open_bin s f =
    with_open Stdlib.open_out_bin s f

  let with_open_text s f =
    with_open Stdlib.open_out s f
end

module Result = struct
  include Result

  let product r0 r1 = match r0, r1 with
  | (Error _ as r), _
  | _, (Error _ as r) -> r
  | Ok v0, Ok v1 -> Ok (v0, v1)

  module Syntax = struct
    let ( let+ ) r f = map f r
    let ( and+ ) = product
  end
end

module String_backports = struct
  include String

  let starts_with ~prefix s =
    let len_s = length s
    and len_pre = length prefix in
    let rec aux i =
      if i = len_pre then true
      else if unsafe_get s i <> unsafe_get prefix i then false
      else aux (i + 1)
    in len_s >= len_pre && aux 0

  let ends_with ~suffix s =
    let len_s = length s
    and len_suf = length suffix in
    let diff = len_s - len_suf in
    let rec aux i =
      if i = len_suf then true
      else if unsafe_get s (diff + i) <> unsafe_get suffix i then false
      else aux (i + 1)
    in diff >= 0 && aux 0
end

module Sys = struct
  include Sys

  let mkdir = Unix.mkdir
  let rmdir = Unix.rmdir

  let signal_to_string s =
    if s = sigabrt then "SIGABRT"
    else if s = sigalrm then "SIGALRM"
    else if s = sigfpe then "SIGFPE"
    else if s = sighup then "SIGHUP"
    else if s = sigill then "SIGILL"
    else if s = sigint then "SIGINT"
    else if s = sigkill then "SIGKILL"
    else if s = sigpipe then "SIGPIPE"
    else if s = sigquit then "SIGQUIT"
    else if s = sigsegv then "SIGSEGV"
    else if s = sigterm then "SIGTERM"
    else if s = sigusr1 then "SIGUSR1"
    else if s = sigusr2 then "SIGUSR2"
    else if s = sigchld then "SIGCHLD"
    else if s = sigcont then "SIGCONT"
    else if s = sigstop then "SIGSTOP"
    else if s = sigtstp then "SIGTSTP"
    else if s = sigttin then "SIGTTIN"
    else if s = sigttou then "SIGTTOU"
    else if s = sigvtalrm then "SIGVTALRM"
    else if s = sigprof then "SIGPROF"
    else if s = sigbus then "SIGBUS"
    else if s = sigpoll then "SIGPOLL"
    else if s = sigsys then "SIGSYS"
    else if s = sigtrap then "SIGTRAP"
    else if s = sigurg then "SIGURG"
    else if s = sigxcpu then "SIGXCPU"
    else if s = sigxfsz then "SIGXFSZ"
    else if s < sigxfsz then invalid_arg "Sys.signal_to_string"
    else "SIG(" ^ string_of_int s ^ ")"
end

module Unix = struct
  include Unix

  external realpath : string -> string = "caml_unix_realpath"

  let realpath =
    if Sys.win32 then
      fun p ->
        let cleanup p = (* Remove any \\?\ prefix. *)
          if String_backports.starts_with ~prefix:{|\\?\|} p
          then (String.sub p 4 (String.length p - 4))
          else p
        in
        try cleanup (realpath p) with
        | (Unix_error (EACCES, _, _)) as e ->
            (* On Windows this can happen on *files* on which you don't have
               access. POSIX realpath(3) works in this case, we emulate this. *)
            try
              let dir = cleanup (realpath (Filename.dirname p)) in
              Filename.concat dir (Filename.basename p)
            with _ -> raise e
    else
      realpath
end

module Import = struct
  type launch_mode = Header_exe | Header_shebang

  type executable =
  | Tendered of {header: launch_mode;
                 dlls: bool;
                 runtime: string;
                 id: Misc.RuntimeID.t option;
                 search: Bytesections.search_mode}
  | Custom
  | Vanilla

  type phase = Original | Renamed

  type mode = Bytecode | Native

  type config = {
    has_ocamlnat: bool;
    has_ocamlopt: bool;
    has_relative_libdir: string option;
    has_runtime_search: bool option;
    launcher_searches_for_ocamlrun: bool;
    target_launcher_searches_for_ocamlrun: bool;
    bytecode_shebangs_by_default: bool;
    shebangscripts: bool;
    libraries: string list list;
    zinc_bootstrapped: bool
  }

  module Bytes = Bytes
  module Char = Char
  module In_channel = In_channel
  module Int = Int
  module List = List
  module Out_channel = Out_channel
  module Result = Result
  module String = String_backports
  module Sys = Sys
  module Uchar = Uchar
  module Unix = Unix
end

open Import

let exe =
  if Sys.win32 then
    Fun.flip (^) ".exe"
  else
    Fun.id

external no_caml_executable_name : unit -> bool
  = "caml_in_prefix_test_no_caml_executable_name"
let no_caml_executable_name = no_caml_executable_name ()

(* Belt-and-braces file removal function - allow up to 30 seconds for
   Windows Defender and other nonsense *)
let rec erase_file retries path =
  try Sys.remove path
  with Sys_error _ when Sys.win32 ->
    (* Deal with read-only attribute on Windows. Ignore any error from chmod
       so that the message always come from Sys.remove *)
    let () = try Unix.chmod path 0o666 with Sys_error _ -> () in
    try Sys.remove path
    with Sys_error _ when retries > 0 ->
      Unix.sleep 1;
      erase_file (pred retries) path

let erase_file path = erase_file 30 path

let lib mode name =
  if mode = Native then
    name ^ ".cmxa"
  else
    name ^ ".cma"

let files_for ?(source_and_cmi = true) mode name files =
  let add_if cond item files = if cond then item :: files else files in
  files
  |> add_if (mode = Native) (name ^ Config.ext_obj)
  |> add_if (mode = Bytecode) (name ^ ".cmo")
  |> add_if (mode = Native) (name ^ ".cmx")
  |> add_if source_and_cmi (name ^ ".cmi")
  |> add_if source_and_cmi (name ^ ".ml")

let fail_because fmt =
  Format.ksprintf (fun s -> prerr_endline s; exit 1) fmt

(* ocamlc cannot be directly executed after renaming the prefix if native
   compilation is disabled (because ocamlc will be ocamlc.byte, since ocamlc.opt
   isn't built) and the bytecode launcher can't search for the runtime. *)
let ocamlc_fails_after_rename config =
  not config.has_ocamlopt && not config.launcher_searches_for_ocamlrun

module Filename = struct
  include Filename

  let is_dir_sep =
    if Sys.win32 then
      function '\\' | '/' -> true | _ -> false
    else
      (=) '/'
end

module String = struct
  include String

  let path_starts_with =
    if Sys.win32 then
      fun ~prefix s ->
        if String.length s < String.length prefix then
          false
        else
          let f = function '\\' -> '/' | c -> c in
          let prefix = String.map f prefix in
          let s = String.map f s in
          String.starts_with ~prefix s
    else
      String.starts_with

  let remove_prefix ~prefix s =
    if path_starts_with ~prefix s then
      let l = String.length prefix in
      Some (String.sub s l (String.length s - l))
    else
      None

  let find s p =
    let max = length s - 1 in
    if max = -1 then
      None
    else
      let rec loop i =
        if p s.[i] then
          Some i
        else if i < max then
          loop (succ i)
        else
          None
      in
      loop 0
end

let pp_path ~prefix ~bindir_suffix ~libdir_suffix ~test_root f path =
  match String.remove_prefix ~prefix path with
  | Some remainder ->
      if remainder = "" then
        Format.pp_print_string f "$prefix"
      else begin
        match String.find remainder Filename.is_dir_sep with
        | None ->
            Format.fprintf f "$prefix%s" remainder
        | Some idx ->
            let suffix, path =
              let idx = idx + 1 in
              let suffix = String.sub remainder 0 idx in
              let path =
                String.sub remainder idx (String.length remainder - idx)
              in
              suffix, path
            in
            match String.remove_prefix ~prefix:bindir_suffix path with
            | Some path when path = "" || Filename.is_dir_sep path.[0] ->
                Format.fprintf f "$prefix%s$bindir%s" suffix path
            | _ ->
                match String.remove_prefix ~prefix:libdir_suffix path with
                | Some path when path = "" || Filename.is_dir_sep path.[0] ->
                    Format.fprintf f "$prefix%s$libdir%s" suffix path
                | _ ->
                    Format.pp_print_string f ("$prefix" ^ remainder)
      end
  | None ->
      match String.remove_prefix ~prefix:test_root path with
      | Some path when path = "" || Filename.is_dir_sep path.[0] ->
          Format.pp_print_string f ("$PWD" ^ path)
      | _ ->
          if String.remove_prefix ~prefix:libdir_suffix path = Some "" then
            Format.pp_print_string f "$libdir"
          else if String.remove_prefix ~prefix:bindir_suffix path = Some "" then
            Format.pp_print_string f "$bindir"
          else
            Format.pp_print_string f path
