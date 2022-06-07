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

(* Description of primitive functions *)

open Misc
open Parsetree

type boxed_integer = Pnativeint | Pint32 | Pint64

type native_repr =
  | Same_as_ocaml_repr
  | Unboxed_float
  | Unboxed_integer of boxed_integer
  | Untagged_int

type description =
  { prim_name: string;         (* Name of primitive  or C function *)
    prim_arity: int;           (* Number of arguments *)
    prim_alloc: bool;          (* Does it allocates or raise? *)
    prim_native_name: string;  (* Name of C function for the nat. code gen. *)
    prim_native_repr_args: native_repr list;
    prim_native_repr_res: native_repr }

type error =
  | Old_style_float_with_native_repr_attribute
  | Old_style_noalloc_with_noalloc_attribute
  | No_native_primitive_with_repr_attribute

exception Error of Location.t * error

let is_ocaml_repr = function
  | Same_as_ocaml_repr -> true
  | Unboxed_float
  | Unboxed_integer _
  | Untagged_int -> false

let is_unboxed = function
  | Same_as_ocaml_repr
  | Untagged_int -> false
  | Unboxed_float
  | Unboxed_integer _ -> true

let is_untagged = function
  | Untagged_int -> true
  | Same_as_ocaml_repr
  | Unboxed_float
  | Unboxed_integer _ -> false

let rec make_native_repr_args arity x =
  if arity = 0 then
    []
  else
    x :: make_native_repr_args (arity - 1) x

let simple ~name ~arity ~alloc =
  {prim_name = name;
   prim_arity = arity;
   prim_alloc = alloc;
   prim_native_name = "";
   prim_native_repr_args = make_native_repr_args arity Same_as_ocaml_repr;
   prim_native_repr_res = Same_as_ocaml_repr}

let make ~name ~alloc ~native_name ~native_repr_args ~native_repr_res =
  {prim_name = name;
   prim_arity = List.length native_repr_args;
   prim_alloc = alloc;
   prim_native_name = native_name;
   prim_native_repr_args = native_repr_args;
   prim_native_repr_res = native_repr_res}

let blocked_primitives = [
  "unix_accept";
  "unix_access";
  "unix_alarm";
  "unix_bind";
  "unix_chdir";
  "unix_chmod";
  "unix_chown";
  "unix_chroot";
  "unix_clear_close_on_exec";
  "unix_clear_nonblock";
  "unix_close";
  "unix_closedir";
  "unix_connect";
  "unix_dup";
  "unix_dup2";
  "unix_environment";
  "unix_environment_unsafe";
  "unix_error_message";
  "unix_execv";
  "unix_execve";
  "unix_execvp";
  "unix_execvpe";
  "unix_exit";
  "unix_fchmod";
  "unix_fchown";
  "unix_fork";
  "unix_fstat";
  "unix_fstat_64";
  "unix_fsync";
  "unix_ftruncate";
  "unix_ftruncate_64";
  "unix_getaddrinfo";
  "unix_getcwd";
  "unix_getegid";
  "unix_geteuid";
  "unix_getgid";
  "unix_getgrgid";
  "unix_getgrnam";
  "unix_getgroups";
  "unix_gethostbyaddr";
  "unix_gethostbyname";
  "unix_gethostname";
  "unix_getitimer";
  "unix_getlogin";
  "unix_getnameinfo";
  "unix_getpeername";
  "unix_getpid";
  "unix_getppid";
  "unix_getprotobyname";
  "unix_getprotobynumber";
  "unix_getpwnam";
  "unix_getpwuid";
  "unix_getservbyname";
  "unix_getservbyport";
  "unix_getsockname";
  "unix_getsockopt";
  "unix_gettimeofday";
  "unix_gettimeofday_unboxed";
  "unix_getuid";
  "unix_gmtime";
  "unix_has_symlink";
  "unix_inchannel_of_filedescr";
  "unix_inet_addr_of_string";
  "unix_initgroups";
  "unix_isatty";
  "unix_kill";
  "unix_link";
  "unix_listen";
  "unix_localtime";
  "unix_lockf";
  "unix_lseek";
  "unix_lseek_64";
  "unix_lstat";
  "unix_lstat_64";
  "unix_mkdir";
  "unix_mkfifo";
  "unix_mktime";
  "unix_nice";
  "unix_open";
  "unix_opendir";
  "unix_outchannel_of_filedescr";
  "unix_pipe";
  "unix_putenv";
  "unix_read";
  "unix_readdir";
  "unix_readlink";
  "unix_realpath";
  "unix_recv";
  "unix_recvfrom";
  "unix_rename";
  "unix_rewinddir";
  "unix_rmdir";
  "unix_select";
  "unix_send";
  "unix_sendto";
  "unix_sendto_native";
  "unix_set_close_on_exec";
  "unix_setgid";
  "unix_setgroups";
  "unix_setitimer";
  "unix_set_nonblock";
  "unix_setsid";
  "unix_setsockopt";
  "unix_setuid";
  "unix_shutdown";
  "unix_sigpending";
  "unix_sigprocmask";
  "unix_sigsuspend";
  "unix_single_write";
  "unix_sleep";
  "unix_socket";
  "unix_socketpair";
  "unix_spawn";
  "unix_stat";
  "unix_stat_64";
  "unix_string_of_inet_addr";
  "unix_symlink";
  "unix_tcdrain";
  "unix_tcflow";
  "unix_tcflush";
  "unix_tcgetattr";
  "unix_tcsendbreak";
  "unix_tcsetattr";
  "unix_time";
  "unix_times";
  "unix_time_unboxed";
  "unix_truncate";
  "unix_truncate_64";
  "unix_umask";
  "unix_unlink";
  "unix_utimes";
  "unix_wait";
  "unix_waitpid";
  "unix_write";
  "win_cleanup";
  "win_clear_close_on_exec";
  "win_create_process";
  "win_create_process_native";
  "win_filedescr_of_channel";
  "win_findclose";
  "win_findfirst";
  "win_findnext";
  "win_handle_fd";
  "win_inchannel_of_filedescr";
  "win_outchannel_of_filedescr";
  "win_set_close_on_exec";
  "win_startup";
  "win_system";
  "win_terminate_process";
  "win_waitpid";
]

let parse_declaration valdecl ~native_repr_args ~native_repr_res =
  let arity = List.length native_repr_args in
  let name, native_name, old_style_noalloc, old_style_float =
    match valdecl.pval_prim with
    | name :: "noalloc" :: name2 :: "float" :: _ -> (name, name2, true, true)
    | name :: "noalloc" :: name2 :: _ -> (name, name2, true, false)
    | name :: name2 :: "float" :: _ -> (name, name2, false, true)
    | name :: "noalloc" :: _ -> (name, "", true, false)
    | name :: name2 :: _ -> (name, name2, false, false)
    | name :: _ -> (name, "", false, false)
    | [] ->
        fatal_error "Primitive.parse_declaration"
  in
  if List.mem name blocked_primitives then
    Misc.fatal_errorf "Illegal byte primitive detected: %s\n" name;
  if List.mem native_name blocked_primitives then
    Misc.fatal_errorf "Illegal native primitive detected: %s\n" name;
  let noalloc_attribute =
    Attr_helper.has_no_payload_attribute ["noalloc"; "ocaml.noalloc"]
      valdecl.pval_attributes
  in
  if old_style_float &&
     not (List.for_all is_ocaml_repr native_repr_args &&
          is_ocaml_repr native_repr_res) then
    raise (Error (valdecl.pval_loc,
                  Old_style_float_with_native_repr_attribute));
  if old_style_noalloc && noalloc_attribute then
    raise (Error (valdecl.pval_loc,
                  Old_style_noalloc_with_noalloc_attribute));
  (* The compiler used to assume "noalloc" with "float", we just make this
     explicit now (GPR#167): *)
  let old_style_noalloc = old_style_noalloc || old_style_float in
  if old_style_float then
    Location.deprecated valdecl.pval_loc
      "[@@unboxed] + [@@noalloc] should be used\n\
       instead of \"float\""
  else if old_style_noalloc then
    Location.deprecated valdecl.pval_loc
      "[@@noalloc] should be used instead of \"noalloc\"";
  if native_name = "" &&
     not (List.for_all is_ocaml_repr native_repr_args &&
          is_ocaml_repr native_repr_res) then
    raise (Error (valdecl.pval_loc,
                  No_native_primitive_with_repr_attribute));
  let noalloc = old_style_noalloc || noalloc_attribute in
  let native_repr_args, native_repr_res =
    if old_style_float then
      (make_native_repr_args arity Unboxed_float, Unboxed_float)
    else
      (native_repr_args, native_repr_res)
  in
  {prim_name = name;
   prim_arity = arity;
   prim_alloc = not noalloc;
   prim_native_name = native_name;
   prim_native_repr_args = native_repr_args;
   prim_native_repr_res = native_repr_res}

open Outcometree

let rec add_native_repr_attributes ty attrs =
  match ty, attrs with
  | Otyp_arrow (label, a, b), attr_opt :: rest ->
    let b = add_native_repr_attributes b rest in
    let a =
      match attr_opt with
      | None -> a
      | Some attr -> Otyp_attribute (a, attr)
    in
    Otyp_arrow (label, a, b)
  | _, [Some attr] -> Otyp_attribute (ty, attr)
  | _ ->
    assert (List.for_all (fun x -> x = None) attrs);
    ty

let oattr_unboxed = { oattr_name = "unboxed" }
let oattr_untagged = { oattr_name = "untagged" }
let oattr_noalloc = { oattr_name = "noalloc" }

let print p osig_val_decl =
  let prims =
    if p.prim_native_name <> "" then
      [p.prim_name; p.prim_native_name]
    else
      [p.prim_name]
  in
  let for_all f =
    List.for_all f p.prim_native_repr_args && f p.prim_native_repr_res
  in
  let all_unboxed = for_all is_unboxed in
  let all_untagged = for_all is_untagged in
  let attrs = if p.prim_alloc then [] else [oattr_noalloc] in
  let attrs =
    if all_unboxed then
      oattr_unboxed :: attrs
    else if all_untagged then
      oattr_untagged :: attrs
    else
      attrs
  in
  let attr_of_native_repr = function
    | Same_as_ocaml_repr -> None
    | Unboxed_float
    | Unboxed_integer _ -> if all_unboxed then None else Some oattr_unboxed
    | Untagged_int -> if all_untagged then None else Some oattr_untagged
  in
  let type_attrs =
    List.map attr_of_native_repr p.prim_native_repr_args @
    [attr_of_native_repr p.prim_native_repr_res]
  in
  { osig_val_decl with
    oval_prims = prims;
    oval_type = add_native_repr_attributes osig_val_decl.oval_type type_attrs;
    oval_attributes = attrs }

let native_name p =
  if p.prim_native_name <> ""
  then p.prim_native_name
  else p.prim_name

let byte_name p =
  p.prim_name

let equal_boxed_integer bi1 bi2 =
  match bi1, bi2 with
  | Pnativeint, Pnativeint
  | Pint32, Pint32
  | Pint64, Pint64 ->
    true
  | (Pnativeint | Pint32 | Pint64), _ ->
    false

let equal_native_repr nr1 nr2 =
  match nr1, nr2 with
  | Same_as_ocaml_repr, Same_as_ocaml_repr -> true
  | Same_as_ocaml_repr,
    (Unboxed_float | Unboxed_integer _ | Untagged_int) -> false
  | Unboxed_float, Unboxed_float -> true
  | Unboxed_float,
    (Same_as_ocaml_repr | Unboxed_integer _ | Untagged_int) -> false
  | Unboxed_integer bi1, Unboxed_integer bi2 -> equal_boxed_integer bi1 bi2
  | Unboxed_integer _,
    (Same_as_ocaml_repr | Unboxed_float | Untagged_int) -> false
  | Untagged_int, Untagged_int -> true
  | Untagged_int,
    (Same_as_ocaml_repr | Unboxed_float | Unboxed_integer _) -> false

let native_name_is_external p =
  let nat_name = native_name p in
  nat_name <> "" && nat_name.[0] <> '%'

let report_error ppf err =
  match err with
  | Old_style_float_with_native_repr_attribute ->
    Format.fprintf ppf "Cannot use \"float\" in conjunction with \
                        [%@unboxed]/[%@untagged]."
  | Old_style_noalloc_with_noalloc_attribute ->
    Format.fprintf ppf "Cannot use \"noalloc\" in conjunction with \
                        [%@%@noalloc]."
  | No_native_primitive_with_repr_attribute ->
    Format.fprintf ppf
      "[@The native code version of the primitive is mandatory@ \
       when attributes [%@untagged] or [%@unboxed] are present.@]"

let () =
  Location.register_error_of_exn
    (function
      | Error (loc, err) ->
        Some (Location.error_of_printer ~loc report_error err)
      | _ ->
        None
    )
