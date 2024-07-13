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

type t = {
  has_ocamlnat: bool;
  has_ocamlopt: bool;
  has_relative_libdir: string option;
  has_runtime_search: bool option;
  launcher_searches_for_ocamlrun: bool;
  target_launcher_searches_for_ocamlrun: bool;
  libraries: string list list
}

(* Split a directory into a list of directory portions, removing all the
   separators. The path can be constructed by folding [Filename.concat] over the
   list.

   e.g. [split_dir [] "/usr/local/bin" = ["/"; "/usr"; "local"; "bin"]] *)
let rec split_dir acc dir =
  let dirname = Filename.dirname dir in
  if dirname = dir || dirname = Filename.current_dir_name then
    (* Deal with the oddity that [Filename.dirname "C:/" = "C:/"] (i.e. that
       the terminating slash remains and so reconstituting the path will end
       up with one slash at the start and then backslashes). *)
    if Sys.win32 && dir.[String.length dir - 1] = '/' then
      (String.sub dir 0 (String.length dir - 1) ^ "\\")::acc
    else
      dir::acc
  else
    split_dir (Filename.basename dir :: acc) dirname

let split_to_common_prefix first second =
  let rec loop prefix = function
  | (dir1::dirs1), (dir2::dirs2) ->
      if dir1 <> dir2 then
        match List.rev prefix with
        | [] | [_] ->
            Result.error `Nothing_in_common
        | dir::dirs ->
            let prefix = List.fold_left Filename.concat dir dirs in
            let first_suffix = List.fold_left Filename.concat dir1 dirs1 in
            let second_suffix = List.fold_left Filename.concat dir2 dirs2 in
            Result.ok (~prefix, ~first, ~first_suffix, ~second, ~second_suffix)
      else
        loop (dir1::prefix) (dirs1, dirs2)
  | [], _ ->
      Result.error `Second_in_first
  | _, [] ->
      Result.error `First_in_second
  in
  loop [] (split_dir [] first, split_dir [] second)

let reconcat empty = function
| hd::tl -> Result.ok (List.fold_left Filename.concat hd tl)
| [] -> Result.error empty

let trim_dir first second =
  let rec loop suffix1 = function
  | rev_first_hd::rev_first_tl, second_hd::second_tl
    when second_hd = Filename.parent_dir_name ->
      loop (rev_first_hd::suffix1) (rev_first_tl, second_tl)
  | rev_first, suffix2 ->
      let open Result.Syntax in
      let+ prefix = reconcat `Nothing_in_common (List.rev rev_first)
      and+ first_suffix = reconcat `Second_in_first suffix1
      and+ second_suffix = reconcat `First_in_second suffix2 in
      let second = Filename.concat prefix second_suffix in
      (~prefix, ~first, ~first_suffix, ~second, ~second_suffix)
  in
  loop [] (List.rev (split_dir [] first), split_dir [] second)

(* display_path jumps through some mildly convoluted hoops to create something
   approaching diff'able output.
   [display_path path] applies the following transformations:
     - ["$bindir"] or ["$libdir"] if [path] is exactly [bindir_suffix] or
       [libdir_suffix] (this captures passing those two variabes to the test
       programs)
     - if [path] begins with [prefix] then the text is replaced with ["$prefix"]
       (which can create ["$prefix.new/"], etc.). Additionally, if the next part
       of [path] after the following directory separator is [bindir_suffix] or
       [libdir_suffix] then this is replaced with ["$bindir"] or ["$libdir"]
       (i.e. this can generate ["$prefix.new/$bindir"] but not
       ["$prefix.new/foo/$bindir"]
     - if [path] begins [test_root] (i.e. the current directory) then this
       is replaced with ["$PWD"] but unlike [prefix] either nothing must follow
       or the next character must be a directory separator. (i.e. it generates
       ["./"] but never [".new/"])
   Both simpler and more convoluted ways of doing this are available. On
   Windows, the comparisons treat forward and back slashes as being the same. *)

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

let display_path ~prefix ~bindir_suffix ~libdir_suffix ~test_root f path =
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

let parse_cmdline argv =
  let summary = ref false in
  let verbose = ref false in
  let pwd = ref "" in
  let bindir = ref "" in
  let libdir = ref "" in
  let tree =
    ref (~prefix:"", ~first:"", ~first_suffix:"", ~second:"", ~second_suffix:"")
  in
  let config =
    ref {has_ocamlnat = false; has_ocamlopt = false; has_relative_libdir = None;
         has_runtime_search = None; launcher_searches_for_ocamlrun = false;
         target_launcher_searches_for_ocamlrun = false; libraries = []}
  in
  let error fmt = Printf.ksprintf (fun s -> raise (Arg.Bad s)) fmt in
  let check_tree () =
    let bindir, libdir = !bindir, !libdir in
    if bindir <> "" && libdir <> "" then
      let has_relative_libdir, result =
        if Filename.is_relative libdir then
          Some libdir, trim_dir bindir libdir
        else
          None, split_to_common_prefix bindir libdir
      in
      match result with
      | Result.Error `Nothing_in_common ->
          (* The prefix is either the root directory (/, C:\, etc.) or, on
             Windows, the two directories are actually on different drives *)
          error "directories given for --bindir and --libdir do not have a \
                 common prefix"
      | Result.Error `First_in_second ->
          error "directory given for --bindir inside that given for --libdir"
      | Result.Error `Second_in_first ->
          error "directory given for --libdir inside that given for --bindir"
      | Result.Ok ((~prefix, ~first:_, ~first_suffix:_,
                    ~second:libdir, ~second_suffix:_) as result) ->
          if Sys.file_exists (prefix ^ ".new") then
            error "can't rename %s to %s.new as the latter already exists!"
                  prefix prefix
          else if Sys.file_exists (Filename.concat libdir "ld.conf.bak") then
            error "can't backup ld.conf to ld.conf.bak as the latter already \
                   exists!"
          else begin
            tree := result;
            config := {!config with has_relative_libdir}
          end
  in
  let check_exists ~absolute r dir =
    if Filename.is_relative dir then
      if absolute then
        raise (Arg.Bad (dir ^ ": is not an absolute path"))
      else if Filename.is_implicit dir then
        raise (Arg.Bad (dir ^ ": is not an explicit-relative path"))
      else
        check_tree (r := dir)
    else if Sys.file_exists dir then
      if Sys.is_directory dir then
        check_tree (r := dir)
      else
        raise (Arg.Bad (dir ^ ": not a directory"))
    else
      raise (Arg.Bad (dir ^ ": directory not found"))
  in
  let has_ocamlnat has_ocamlnat () = config := {!config with has_ocamlnat} in
  let has_ocamlopt has_ocamlopt () = config := {!config with has_ocamlopt} in
  let parse_search = function
  | "enable" -> true
  | "always" -> false
  | _ ->
      raise (Arg.Bad
        "--with-runtime-search: argument should be either enable or always")
  in
  let has_runtime_search arg =
    let has_runtime_search = Option.map parse_search arg in
    if has_runtime_search <> None then
      error "--with-runtime-search is not implemented!";
    config := {!config with has_runtime_search}
  in
  let args = Arg.align [
    "--pwd", Arg.Set_string pwd, "<pwd>\tCurrent working directory to use";
    "--bindir", Arg.String (check_exists ~absolute:true bindir), "\
<bindir>\tDirectory containing programs (must share a prefix with --libdir)";
    "--libdir", Arg.String (check_exists ~absolute:false libdir), "\
<libdir>\tDirectory containing stdlib.cma (must share a prefix with --bindir)";
    "--summary", Arg.Set summary, "";
    "--verbose", Arg.Set verbose, "";
    "--with-ocamlnat", Arg.Unit (has_ocamlnat true), "\
\tNative toplevel (ocamlnat) is installed in the directory given in --bindir";
    "--without-ocamlnat", Arg.Unit (has_ocamlnat false), "";
    "--with-ocamlopt", Arg.Unit (has_ocamlopt true), "\
\tNative compiler (ocamlopt) is installed in the directory given in --bindir";
    "--without-ocamlopt", Arg.Unit (has_ocamlopt false), "";
    "--with-runtime-search",
      Arg.String (fun s -> has_runtime_search (Some s)), "\
\tCompiler bytecode binaries can search for their runtimes";
    "--without-runtime-search",
      Arg.Unit (fun () -> has_runtime_search None), "";
  ] in
  let libraries lib =
    config := {!config with libraries = [lib]::config.contents.libraries}
  in
  let usage = "\n\
Usage: test_install --bindir <bindir> --libdir <libdir> <options> [libraries]\n\
options are:" in
  match Arg.parse_argv ~current:(ref 0) argv args libraries usage with
  | exception Arg.Bad msg ->
      Result.error (2, msg)
  | exception Arg.Help msg ->
      Result.error (0, msg)
  | () ->
      let config, pwd, summarise_only, verbose =
        !config, !pwd, !summary, !verbose in
      let ~prefix,
          ~first:bindir, ~first_suffix:bindir_suffix,
          ~second:libdir, ~second_suffix:libdir_suffix = !tree in
      let pp_path =
        if verbose then
          fun ~test_root:_ -> Format.pp_print_string
        else
          display_path ~prefix ~bindir_suffix ~libdir_suffix
      in
      Result.ok (~config, ~pwd, ~prefix, ~bindir, ~bindir_suffix, ~libdir,
                 ~libdir_suffix, ~pp_path, ~summarise_only, ~verbose)

(* ocamlc cannot be directly executed after renaming the prefix if native
   compilation is disabled (because ocamlc will be ocamlc.byte, since ocamlc.opt
   isn't built) and the bytecode launcher can't for the runtime. *)
let ocamlc_fails_after_rename config =
  not config.has_ocamlopt && not config.launcher_searches_for_ocamlrun
