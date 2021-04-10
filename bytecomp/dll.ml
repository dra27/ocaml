(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*             Xavier Leroy, projet Cristal, INRIA Rocquencourt           *)
(*                                                                        *)
(*   Copyright 2001 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

(* Handling of dynamically-linked libraries *)

type dll_handle
type dll_address
type dll_mode = For_checking | For_execution

external dll_open: dll_mode -> string -> dll_handle = "caml_dynlink_open_lib"
external dll_close: dll_handle -> unit = "caml_dynlink_close_lib"
external dll_sym: dll_handle -> string -> dll_address
                = "caml_dynlink_lookup_symbol"
         (* returned dll_address may be Val_unit *)
external add_primitive: dll_address -> int = "caml_dynlink_add_primitive"
external get_current_dlls: unit -> dll_handle array
                                           = "caml_dynlink_get_current_libs"

(* Current search path for DLLs *)
let search_path = ref ([] : string list)

type opened_dll =
  | Checking of Binutils.t
  | Execution of dll_handle

let dll_close = function
  | Checking _ -> ()
  | Execution dll -> dll_close dll

(* DLLs currently opened *)
let opened_dlls = ref ([] : opened_dll list)

(* File names for those DLLs *)
let names_of_opened_dlls = ref ([] : string list)

(* Add the given directories to the search path for DLLs. *)
let add_path dirs =
  search_path := dirs @ !search_path

let remove_path dirs =
  search_path := List.filter (fun d -> not (List.mem d dirs)) !search_path

(* Extract the name of a DLLs from its external name (xxx.so or -lxxx) *)

let extract_dll_name file =
  if Filename.check_suffix file Config.ext_dll then
    Filename.chop_suffix file Config.ext_dll
  else if String.length file >= 2 && String.sub file 0 2 = "-l" then
    "dll" ^ String.sub file 2 (String.length file - 2)
  else
    file (* will cause error later *)

(* Open a list of DLLs, adding them to opened_dlls.
   Raise [Failure msg] in case of error. *)

let open_dll mode name =
  let name = name ^ Config.ext_dll in
  let fullname =
    try
      let fullname = Misc.find_in_path !search_path name in
      if Filename.is_implicit fullname then
        Filename.concat Filename.current_dir_name fullname
      else fullname
    with Not_found -> name in
  if not (List.mem fullname !names_of_opened_dlls) then begin
    let dll =
      match mode with
      | For_checking ->
          begin match Binutils.read fullname with
          | Ok t -> Checking t
          | Error err ->
              failwith (fullname ^ ": " ^ Binutils.error_to_string err)
          end
      | For_execution ->
          begin match dll_open mode fullname with
          | dll ->
              Execution dll
          | exception Failure msg ->
              failwith (fullname ^ ": " ^ msg)
          end
    in
    names_of_opened_dlls := fullname :: !names_of_opened_dlls;
    opened_dlls := dll :: !opened_dlls
  end

let open_dlls mode names =
  List.iter (open_dll mode) names

(* Close all DLLs *)

let close_all_dlls () =
  List.iter dll_close !opened_dlls;
  opened_dlls := [];
  names_of_opened_dlls := []

(* Find a primitive in the currently opened DLLs. *)

type primitive_address =
  | Prim_loaded of dll_address
  | Prim_exists

let find_primitive prim_name =
  let rec find seen = function
    [] ->
      None
  | Execution dll as curr :: rem ->
      let addr = dll_sym dll prim_name in
      if addr == Obj.magic () then find (curr :: seen) rem else begin
        if seen <> [] then opened_dlls := curr :: List.rev_append seen rem;
        Some (Prim_loaded addr)
      end
  | Checking t as curr :: rem ->
      if Binutils.defines_symbol t prim_name then
        Some Prim_exists
      else
        find (curr :: seen) rem
  in
  find [] !opened_dlls

(* If linking in core (dynlink or toplevel), synchronize the VM
   table of primitive with the linker's table of primitive
   by storing the given primitive function at the given position
   in the VM table of primitives.  *)

let linking_in_core = ref false

let synchronize_primitive num symb =
  if !linking_in_core then begin
    let actual_num = add_primitive symb in
    assert (actual_num = num)
  end

(* Read the [ld.conf] file and return the corresponding list of directories *)

let rtrim_cr s =
  if s = "" then s
  else
    let len = String.length s in
    let i = ref len in
    while !i > 0 && s.[!i - 1] = '\r' do
      decr i
    done;
    if !i <> len then
      String.sub s 0 !i
    else
      s

module In_channel = struct
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
end

let ld_conf_contents dir =
  let is_separator =
    if Sys.win32 then
      function '/' | '\\' -> true | _ -> false
    else
      Char.equal '/'
  in
  let translate line =
    if line = "" then
      ""
    else
      let len = String.length line in
      if line.[0] = '.' then
        if len = 1 then
          dir
        else if is_separator line.[1] then
          dir ^ String.sub line 1 (len - 1)
        else if line.[1] = '.' && (len = 2 || is_separator line.[2]) then
          Filename.concat dir line
        else
          line
      else
        line
  in
  try
    In_channel.with_open_bin (Filename.concat dir "ld.conf") @@ fun ic ->
      let lines = String.split_on_char '\n' (In_channel.input_all ic) in
      match List.rev lines with
      | [] -> assert false (* String.split_on_char doesn't return [] *)
      | [""] -> []
      | last :: rev_rest ->
          let f s = translate (rtrim_cr s) in
          let last = translate last in
          List.rev_map f rev_rest @ if last = "" then [] else [last]
  with Sys_error _ -> []

let ld_conf_contents () =
  let dirs = [
    Sys.getenv_opt "OCAMLLIB";
    Sys.getenv_opt "CAMLLIB";
    Some Config.standard_library_default] in
  List.concat_map (Option.fold ~none:[] ~some:ld_conf_contents) dirs

(* Split the CAML_LD_LIBRARY_PATH environment variable and return
   the corresponding list of directories.  *)
let ld_library_path_contents () =
  match Sys.getenv "CAML_LD_LIBRARY_PATH" with
  | exception Not_found ->
      []
  | s ->
      Misc.split_path_contents s

let split_dll_path path =
  Misc.split_path_contents ~sep:'\000' path

(* Initialization for separate compilation *)

let init_compile nostdlib =
  search_path :=
    ld_library_path_contents() @
    (if nostdlib then [] else ld_conf_contents())

(* Initialization for linking in core (dynlink or toplevel) *)

let init_toplevel dllpath =
  search_path :=
    ld_library_path_contents() @
    split_dll_path dllpath @
    ld_conf_contents();
  opened_dlls :=
    List.map (fun dll -> Execution dll)
      (Array.to_list (get_current_dlls()));
  names_of_opened_dlls := [];
  linking_in_core := true

let reset () =
  search_path := [];
  opened_dlls :=[];
  names_of_opened_dlls := [];
  linking_in_core := false

let search_path () = !search_path
