(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*                        Louis Gesbert, OCamlPro                         *)
(*                                                                        *)
(*   Copyright 2017 OCamlPro SAS                                          *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

let expected_ocaml_version,
    package_config_file,
    compiler_package_version,
    preinstalled,
    option_names =
  match Array.to_list Sys.argv with
  | _ ::
    expected_ocaml_version ::
    package_config_file ::
    compiler_package_version ::
    preinstalled ::
    options ->
      expected_ocaml_version,
      package_config_file ^ ".config",
      compiler_package_version,
      preinstalled,
      String.concat "" (List.filter ((<>) "") options)
  | _ ->
      prerr_endline "Invalid arguments";
      exit 1

let () =
  (* XXX It would be good to make this work with _all_ the compiler packages,
         which can be done easily with Scanf *)
  let ocaml_version =
    let v = Sys.ocaml_version in
    let l = String.length v in
    let plus = try String.index v '+' with Not_found -> l in
    (* Introduced in 4.11.0; used from 4.12.0 *)
    let tilde = try String.index v '~' with Not_found -> l in
    String.sub v 0 (min (min plus tilde) l)
  in
  if ocaml_version <> expected_ocaml_version then
    (Printf.eprintf
       "OCaml version mismatch: %s, expected %s"
       ocaml_version expected_ocaml_version;
     exit 1)
  else
  let oc = open_out package_config_file in
  let exe = ".exe" in
  let (ocaml, suffix) =
    let s = Sys.executable_name in
    if Filename.check_suffix s exe then
      (Filename.chop_suffix s exe, exe)
    else
      (s, "")
  in
  let ocamlc = ocaml^"c"^suffix in
  let libdir =
    if Sys.command (ocamlc^" -where > where") = 0 then
      (* Must be opened in text mode for Windows *)
      let ic = open_in "where" in
      let r = input_line ic in
      close_in ic; r
    else
      failwith "Bad return from 'ocamlc -where'"
  in
  let stubsdir =
    let ic = open_in (Filename.concat libdir "ld.conf") in
    let rec r acc = try r (input_line ic::acc) with End_of_file -> acc in
    let lines = List.rev (r []) in
    close_in ic;
    let sep = if Sys.os_type = "Win32" then ";" else ":" in
    String.concat sep lines
  in
  let has_native_dynlink =
    let check_dir libdir =
      Sys.file_exists (Filename.concat libdir "dynlink.cmxa")
    in
    List.exists check_dir [Filename.concat libdir "dynlink"; libdir]
  in
  let p fmt = Printf.fprintf oc (fmt ^^ "\n") in
  p "opam-version: \"2.0\"";
  p "variables {";
  p "  native: %b" (Sys.file_exists (ocaml^"opt"^suffix));
  p "  native-tools: %b"
    (* The variable [ocamlc] already has a suffix on Windows
       (ex. '...\bin\ocamlc.exe') so we use [ocaml] to check *)
    (Sys.file_exists (ocaml^"c.opt"^suffix));
  p "  native-dynlink: %b" has_native_dynlink;
  p "  stubsdir: %S" stubsdir;
  p "  preinstalled: %s" preinstalled;
  p "  compiler: \"%s%s\"" compiler_package_version option_names;
  p "}";
  close_out oc
