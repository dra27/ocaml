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

(* Compiling C files and building C libraries *)


let is_space = function
| ' ' | '\n' | '\t' | '\r' | '\x0b' -> true
| _ -> false

(* characters that triggers special behaviour (cmd.exe, not unix shell) *)
let is_unsafe_char = function
| '(' | ')' | '%' | '!' | '^' | '<' | '>' | '&' -> true
| _ -> false


(* external commands are unfortunately called called with cmd.exe
 * (via Sys.command).
 * Cmd.exe has strange quoting rules. The most notorious quirk is, that
 * you can't use forward slashes as path separators at the first position,
 * unless you quote the expression explicitly.
 * cmd.exe will interpret the slash and everything thereafter as first
 * parameter. Eg. 'bin/foo -x' is treated like 'bin /foo -x'.
 * Because the most used build tools are unix-centric (ocamlbuild, gmake)
 * and are not aware of it, such errors are quite common, especially when
 * calling the preprocessor. ( ocamlc -pp 'subdir/exe' ... )
 *
 * Therefore, I replace every slash inside the first subexpression with a
 * backslash.
 * I think this replacement is safe. No OCaml developer will write 'bin/foo',
 * if he wants to call a executable 'bin' with parameter /foo.
 *)

let replace s =
  let module T = struct exception Use_original end in
  let open T in
  let len = String.length s in
  let b = Buffer.create ( (len/2) * 3 ) in
  let modified = ref false in
  let rec f i =
    if i = len then
      if !modified = false then
        raise Use_original
      else
        Buffer.contents b
    else
      let c = s.[i] in
      (* quoted expression are left untouched,
       * ' is not really a quote symbol, but presumably
       * intended as such *)
      if  c = '\'' || c = '"' then
        raise Use_original
      else if c = '/' then (
        Buffer.add_char b '\\' ;
        modified := true;
        f (succ i)
      )
      else if is_space c then
        if !modified then
          (Buffer.contents b) ^
          (String.sub s i (len - i ) )
        else
          raise Use_original
      (* probably a syntax error, don't modify it and let the shell
         complain *)
      else if is_unsafe_char c then
        raise Use_original
      else (
        Buffer.add_char b c ;
        f (succ i)
      )
  in
  (* ignore leading whitespace *)
  let rec ws i =
    if i = len then
      raise Use_original
    else
      let c = s.[i] in
      if is_space c then (
        Buffer.add_char b c ;
        ws (succ i)
      )
      else
        f i
  in
  try
    ws 0
  with
  | Use_original -> s


let replace s =
  if Sys.os_type <> "Win32" then
    s
  else
    let n = try Sys.getenv "OCAML_NO_CMD_HACK" with Not_found -> "" in
    if n = "" then
      replace s
    else
      match n.[0] with
      | 'n' | 'N' | '0' | 'f' | 'F' -> replace s
      | _ -> s


let command cmdline' =
  let cmdline = replace cmdline' in
  if !Clflags.verbose then begin
    prerr_string "+ ";
    prerr_string cmdline;
    prerr_newline()
  end;
  let res = Sys.command cmdline in
  if res = 127 then raise (Sys_error cmdline);
  res

let run_command cmdline = ignore(command cmdline)

(* Build @responsefile to work around OS limitations on
   command-line length.
   Under Windows, the max length is 8187 minus the length of the
   COMSPEC variable (or 7 if it's not set).  To be on the safe side,
   we'll use a response file if we need to pass 4096 or more bytes of
   arguments.
   For Unix-like systems, the threshold is 2^16 (64 KiB), which is
   within the lowest observed limits (2^17 per argument under Linux;
   between 70000 and 80000 for macOS).
*)

let build_diversion lst =
  let (responsefile, oc) = Filename.open_temp_file "camlresp" "" in
  List.iter (fun f -> Printf.fprintf oc "%s\n" f) lst;
  close_out oc;
  at_exit (fun () -> Misc.remove_file responsefile);
  "@" ^ responsefile

let quote_files lst =
  let lst = List.filter (fun f -> f <> "") lst in
  let quoted = List.map Filename.quote lst in
  let s = String.concat " " quoted in
  if String.length s >= 65536
  || (String.length s >= 4096 && Sys.os_type = "Win32")
  then build_diversion quoted
  else s

let quote_prefixed pr lst =
  let lst = List.filter (fun f -> f <> "") lst in
  let lst = List.map (fun f -> pr ^ f) lst in
  quote_files lst

let quote_optfile = function
  | None -> ""
  | Some f -> Filename.quote f

let display_msvc_output file name =
  let c = open_in file in
  try
    let first = input_line c in
    if first <> Filename.basename name then
      print_endline first;
    while true do
      print_endline (input_line c)
    done
  with _ ->
    close_in c;
    Sys.remove file

let compile_file ?output ?(opt="") ?stable_name name =
  let (pipe, file) =
    if Config.ccomp_type = "msvc" && not !Clflags.verbose then
      try
        let (t, c) = Filename.open_temp_file "msvc" "stdout" in
        close_out c;
        (Printf.sprintf " > %s" (Filename.quote t), t)
      with _ ->
        ("", "")
    else
      ("", "") in
  let debug_prefix_map =
    match stable_name with
    | Some stable when Config.c_has_debug_prefix_map ->
      Printf.sprintf " -fdebug-prefix-map=%s=%s" name stable
    | Some _ | None -> "" in
  let exit =
    command
      (Printf.sprintf
         "%s%s %s %s -c %s %s %s %s %s%s"
         (match !Clflags.c_compiler with
          | Some cc -> cc
          | None ->
              (* #7678: ocamlopt only calls the C compiler to process .c files
                 from the command line, and the behaviour between
                 ocamlc/ocamlopt should be identical. *)
              (String.concat " " [Config.c_compiler;
                                  Config.ocamlc_cflags;
                                  Config.ocamlc_cppflags]))
         debug_prefix_map
         (match output with
          | None -> ""
          | Some o -> Printf.sprintf "%s%s" Config.c_output_obj o)
         opt
         (if !Clflags.debug && Config.ccomp_type <> "msvc" then "-g" else "")
         (String.concat " " (List.rev !Clflags.all_ccopts))
         (quote_prefixed "-I"
            (List.map (Misc.expand_directory Config.standard_library)
               (List.rev !Clflags.include_dirs)))
         (Clflags.std_include_flag "-I")
         (Filename.quote name)
         (* cl tediously includes the name of the C file as the first thing it
            outputs (in fairness, the tedious thing is that there's no switch to
            disable this behaviour). In the absence of the Unix module, use
            a temporary file to filter the output (cannot pipe the output to a
            filter because this removes the exit status of cl, which is wanted.
          *)
         pipe) in
  if pipe <> ""
  then display_msvc_output file name;
  exit

let create_archive archive file_list =
  Misc.remove_file archive;
  let quoted_archive = Filename.quote archive in
  if file_list = [] then
    0 (* Don't call the archiver: #6550/#1094/#9011 *)
  else
    match Config.ccomp_type with
      "msvc" ->
        command(Printf.sprintf "link /lib /nologo /out:%s %s"
                               quoted_archive (quote_files file_list))
    | _ ->
        assert(String.length Config.ar > 0);
        let r1 =
          command(Printf.sprintf "%s rc %s %s"
                  Config.ar quoted_archive (quote_files file_list)) in
        if r1 <> 0 || String.length Config.ranlib = 0
        then r1
        else command(Config.ranlib ^ " " ^ quoted_archive)

let expand_libname name =
  if String.length name < 2 || String.sub name 0 2 <> "-l"
  then name
  else begin
    let libname =
      "lib" ^ String.sub name 2 (String.length name - 2) ^ Config.ext_lib in
    try
      Load_path.find libname
    with Not_found ->
      libname
  end

type link_mode =
  | Exe
  | Dll
  | MainDll
  | Partial

let remove_Wl cclibs =
  cclibs |> List.map (fun cclib ->
    (* -Wl,-foo,bar -> -foo bar *)
    if String.length cclib >= 4 && "-Wl," = String.sub cclib 0 4 then
      String.map (function ',' -> ' ' | c -> c)
                 (String.sub cclib 4 (String.length cclib - 4))
    else cclib)

let call_linker mode output_name files extra =
  Profile.record_call "c-linker" (fun () ->
    let cmd =
      if mode = Partial then
        let l_prefix =
          match Config.ccomp_type with
          | "msvc" -> "/libpath:"
          | _ -> "-L"
        in
        Printf.sprintf "%s%s %s %s %s"
          Config.native_pack_linker
          (Filename.quote output_name)
          (quote_prefixed l_prefix (Load_path.get_paths ()))
          (quote_files (remove_Wl files))
          extra
      else
        Printf.sprintf "%s -o %s %s %s %s %s %s"
          (match !Clflags.c_compiler, mode with
          | Some cc, _ -> cc
          | None, Exe -> Config.mkexe
          | None, Dll -> Config.mkdll
          | None, MainDll -> Config.mkmaindll
          | None, Partial -> assert false
          )
          (Filename.quote output_name)
          ""  (*(Clflags.std_include_flag "-I")*)
          (quote_prefixed "-L" (Load_path.get_paths ()))
          (String.concat " " (List.rev !Clflags.all_ccopts))
          (quote_files files)
          extra
    in
    command cmd
  )

let linker_is_flexlink =
  (* Config.mkexe, Config.mkdll and Config.mkmaindll are all flexlink
     invocations for the native Windows ports and for Cygwin, if shared library
     support is enabled. *)
  Sys.win32 || Config.supports_shared_libraries && Sys.cygwin
