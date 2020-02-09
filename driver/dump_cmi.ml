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

let dump_directory_cmis dir =
  let is_cmi_fn =
    Fun.flip Filename.check_suffix ".cmi" in
  let dump_md5 fn =
    let cmi_info = Cmi_format.read_cmi (Filename.concat dir fn) in
    let this_unit = String.capitalize_ascii (Filename.chop_extension fn) in
    let is_this_unit (modname, _) = (modname = this_unit)
  in
    let (modname, digest) =
      List.find is_this_unit cmi_info.Cmi_format.cmi_crcs
    in
      Printf.printf "%s: %s\n" modname (Digest.to_hex (Option.get digest))
  in
    Sys.readdir dir
      |> Array.to_list
      |> List.filter is_cmi_fn
      |> List.sort compare
      |> List.iter dump_md5
