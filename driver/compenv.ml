(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*       Fabrice Le Fessant, EPI Gallium, INRIA Paris-Rocquencourt        *)
(*                                                                        *)
(*   Copyright 2013 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

exception Exit_with_status of int

let output_prefix name =
  let oname =
    match !Clflags.output_name with
    | None -> name
    | Some n ->
        if !Clflags.compile_only then begin
          Clflags.output_name := None; n
        end else name in
  Filename.remove_extension oname

let print_version_and_library compiler =
  let standard_library =
    Misc.get_stdlib Config_settings.standard_library_default in
  Printf.printf "The OCaml %s, version " compiler;
  print_string Sys.ocaml_version; print_newline();
  print_string "Standard library directory: ";
  print_string standard_library; print_newline();
  raise (Exit_with_status 0)

let print_version_string () =
  print_string Sys.ocaml_version; print_newline();
  raise (Exit_with_status 0)

let print_standard_library () =
  let standard_library =
    Misc.get_stdlib Config_settings.standard_library_default in
  print_string standard_library; print_newline();
  raise (Exit_with_status 0)

let default_executable_name =
  match Sys.os_type with
    "Unix" -> "a.out"
  | "Win32" | "Cygwin" -> "camlprog.exe"
  | _ -> "camlprog"

type configuration_value =
  | String of string
  | Int of int
  | Bool of bool
  | System of Config_constants.System.t

let configuration_variables () =
  let open Config_constants in
  let open Config_settings in
  let p x v = (x, String v) in
  let p_int x v = (x, Int v) in
  let p_bool x v = (x, Bool v) in
  let p_system x v = (x, System v) in
  (* bytecomp_c_compiler and native_c_compiler have been supported for a
     long time and are retained for backwards compatibility.
     For programs that don't need compatibility with older OCaml releases
     the recommended approach is to use the constituent variables
     c_compiler, ocamlc_cflags, ocamlc_cppflagsetc., directly.
  *)
  let legacy_c_compiler =
    c_compiler ^ " " ^ ocamlc_cflags ^ " " ^ ocamlc_cppflags in
  let cmx_magic_number =
    Magic_number.(current_raw (Cmx (native_obj_config ()))) in
  let cmxa_magic_number =
    Magic_number.(current_raw (Cmxa (native_obj_config ()))) in
[
  p "version" Sys.ocaml_version;
  p "standard_library_default" standard_library_default;
  p "standard_library" (Misc.get_stdlib standard_library_default);
  p "ccomp_type" ccomp_type;
  p "c_compiler" c_compiler;
  p "ocamlc_cflags" ocamlc_cflags;
  p "ocamlc_cppflags" ocamlc_cppflags;
  p "ocamlopt_cflags" ocamlc_cflags;
  p "ocamlopt_cppflags" ocamlc_cppflags;
  p "bytecomp_c_compiler" legacy_c_compiler;
  p "native_c_compiler" legacy_c_compiler;
  p "bytecomp_c_libraries" bytecomp_c_libraries;
  p "native_c_libraries" native_c_libraries;
  p "native_ldflags" native_ldflags;
  p "native_pack_linker" native_pack_linker;
  p_bool "native_compiler" native_compiler;
  p "architecture" architecture;
  p "model" model;
  p_int "int_size" Sys.int_size;
  p_int "word_size" Sys.word_size;
  p_system "system" system;
  p "abi" abi;
  p "asm" asm;
  p_bool "asm_cfi_supported" asm_cfi_supported;
  p_bool "with_frame_pointers" with_frame_pointers;
  p "ext_exe" ext_exe;
  p "ext_obj" ext_obj;
  p "ext_asm" ext_asm;
  p "ext_lib" ext_lib;
  p "ext_dll" ext_dll;
  p "os_type" Sys.os_type;
  p "default_executable_name" default_executable_name;
  p_bool "systhread_supported" systhread_supported;
  p "host" host;
  p "target" target;
  p_bool "flambda" flambda;
  p_bool "safe_string" true;
  p_bool "default_safe_string" true;
  p_bool "flat_float_array" flat_float_array;
  p_bool "function_sections" function_sections;
  p_bool "afl_instrument" afl_instrument;
  p_bool "tsan" tsan;
  p_bool "windows_unicode" windows_unicode;
  p_bool "supports_shared_libraries" supports_shared_libraries;
  p_bool "native_dynlink" native_dynlink;
  p_bool "naked_pointers" false;
  p_bool "compression_supported" (Marshal.compression_supported());

  p "exec_magic_number" exec_magic_number;
  p "cmi_magic_number" cmi_magic_number;
  p "cmo_magic_number" cmo_magic_number;
  p "cma_magic_number" cma_magic_number;
  p "cmx_magic_number" cmx_magic_number;
  p "cmxa_magic_number" cmxa_magic_number;
  p "ast_impl_magic_number" ast_impl_magic_number;
  p "ast_intf_magic_number" ast_intf_magic_number;
  p "cmxs_magic_number" cmxs_magic_number;
  p "cmt_magic_number" cmt_magic_number;
  p "linear_magic_number" linear_magic_number;
]

let print_config_value oc = function
  | String s ->
      Printf.fprintf oc "%s" s
  | Int n ->
      Printf.fprintf oc "%d" n
  | Bool p ->
      Printf.fprintf oc "%B" p
  | System system ->
      Printf.fprintf oc "%s" (Config_constants.System.to_string system)

let print_config oc =
  let print (x, v) =
    Printf.fprintf oc "%s: %a\n" x print_config_value v in
  List.iter print (configuration_variables ());
  flush oc

let config_var x =
  match List.assoc_opt x (configuration_variables()) with
  | None -> None
  | Some v ->
      let s = match v with
        | String s -> s
        | Int n -> Int.to_string n
        | Bool b -> string_of_bool b
        | System system -> Config_constants.System.to_string system
      in
      Some s

(* showing configuration and configuration variables *)
let show_config_and_exit () =
  print_config stdout;
  exit 0

let show_config_variable_and_exit x =
  match config_var x with
  | Some v ->
      (* we intentionally don't print a newline to avoid Windows \r
         issues: bash only strips the trailing \n when using a command
         substitution $(ocamlc -config-var foo), so a trailing \r would
         remain if printing a newline under Windows and scripts would
         have to use $(ocamlc -config-var foo | tr -d '\r')
         for portability. Ugh. *)
      print_string v;
      exit 0
  | None ->
      exit 2

let fatal err =
  prerr_endline err;
  raise (Exit_with_status 2)

let extract_output = function
  | Some s -> s
  | None ->
      fatal "Please specify the name of the output file, using option -o"

let default_output = function
  | Some s -> s
  | None -> default_executable_name

let first_include_dirs = ref []
let last_include_dirs = ref []
let first_ccopts = ref []
let last_ccopts = ref []
let first_ppx = ref []
let last_ppx = ref []
let first_objfiles = ref []
let last_objfiles = ref []
let stop_early = ref false

(* Check validity of module name *)
let is_unit_name name =
  try
    if name = "" then raise Exit;
    begin match name.[0] with
    | 'A'..'Z' -> ()
    | _ ->
       raise Exit;
    end;
    for i = 1 to String.length name - 1 do
      match name.[i] with
      | 'A'..'Z' | 'a'..'z' | '0'..'9' | '_' | '\'' -> ()
      | _ ->
         raise Exit;
    done;
    true
  with Exit -> false

let check_unit_name filename name =
  if not (is_unit_name name) then
    Location.prerr_warning (Location.in_file filename)
      (Warnings.Bad_module_name name)

(* Compute name of module from output file name *)
let module_of_filename inputfile outputprefix =
  let basename = Filename.basename outputprefix in
  let name =
    try
      let pos = String.index basename '.' in
      String.sub basename 0 pos
    with Not_found -> basename
  in
  let name = String.capitalize_ascii name in
  check_unit_name inputfile name;
  name

type filename = string

type readenv_position =
  Before_args | Before_compile of filename | Before_link

(* Syntax of OCAMLPARAM: SEP?(name=VALUE SEP)* _ (SEP name=VALUE)*
   where VALUE should not contain SEP, and SEP is ',' if unspecified,
   or ':', '|', ';', ' ' or ',' *)
exception SyntaxError of string

let print_error ppf msg =
  Location.print_warning Location.none ppf
    (Warnings.Bad_env_variable ("OCAMLPARAM", msg))

let parse_args s =
  let args =
    let len = String.length s in
    if len = 0 then []
    else
      (* allow first char to specify an alternative separator in ":|; ," *)
      match s.[0] with
      | ( ':' | '|' | ';' | ' ' | ',' ) as c ->
         List.tl (String.split_on_char c s)
      | _ -> String.split_on_char ',' s
  in
  let rec iter is_after args before after =
    match args with
      [] ->
      if not is_after then
        raise (SyntaxError "no '_' separator found")
      else
        (List.rev before, List.rev after)
    | "" :: tail -> iter is_after tail before after
    | "_" :: _ when is_after -> raise (SyntaxError "too many '_' separators")
    | "_" :: tail -> iter true tail before after
    | arg :: tail ->
      let binding = try
        Misc.cut_at arg '='
      with Not_found ->
        raise (SyntaxError ("missing '=' in " ^ arg))
      in
      if is_after then
        iter is_after tail before (binding :: after)
      else
        iter is_after tail (binding :: before) after
  in
  iter false args [] []

let setter ppf f name options s =
  try
    let bool = match s with
      | "0" -> false
      | "1" -> true
      | _ -> raise Not_found
    in
    List.iter (fun b -> b := f bool) options
  with Not_found ->
    Printf.ksprintf (print_error ppf)
      "bad value %s for %s" s name

let int_setter ppf name option s =
  try
    option := int_of_string s
  with _ ->
    Printf.ksprintf (print_error ppf)
      "non-integer parameter %s for %S" s name

let int_option_setter ppf name option s =
  try
    option := Some (int_of_string s)
  with _ ->
    Printf.ksprintf (print_error ppf)
      "non-integer parameter %s for %S" s name

(*
let float_setter ppf name option s =
  try
    option := float_of_string s
  with _ ->
    Location.print_warning Location.none ppf
      (Warnings.Bad_env_variable
         ("OCAMLPARAM", Printf.sprintf "non-float parameter for \"%s\"" name))
*)

let check_bool ppf name s =
  match s with
  | "0" -> false
  | "1" -> true
  | _ ->
    Printf.ksprintf (print_error ppf)
      "bad value %s for %s" s name;
    false

let decode_compiler_pass ppf v ~name ~filter =
  let module P = Clflags.Compiler_pass in
  let passes = P.available_pass_names ~filter ~native:!Clflags.native_code in
  begin match List.find_opt (String.equal v) passes with
  | None ->
    Printf.ksprintf (print_error ppf)
      "bad value %s for option \"%s\" (expected one of: %s)"
      v name (String.concat ", " passes);
    None
  | Some v -> P.of_string v
  end

let set_compiler_pass ppf ~name v flag ~filter =
  match decode_compiler_pass ppf v ~name ~filter with
  | None -> ()
  | Some pass ->
    match !flag with
    | None -> flag := Some pass
    | Some p ->
      if not (p = pass) then begin
        Printf.ksprintf (print_error ppf)
          "Please specify at most one %s <pass>." name
      end

(* 'can-discard=' specifies which arguments can be discarded without warning
   because they are not understood by some versions of OCaml. *)
let can_discard = ref []

let parse_warnings error v =
  Option.iter Location.(prerr_alert none) @@ Warnings.parse_options error v

let prepend_to_list l x = l := x :: !l

let read_one_param ppf position name v =
  let set name options s = setter ppf (fun b -> b) name options s in
  let set_opt name options s = setter ppf Option.some name options s in
  let clear name options s = setter ppf (fun b -> not b) name options s in
  let compat name s =
    let error_if_unset = function
      | true -> true
      | false ->
        Printf.ksprintf (print_error ppf)
          "Unsetting %s is not supported anymore" name;
        true
    in
    setter ppf error_if_unset name [ ref true ] s
  in
  match name with
  | "g" -> set "g" [ Clflags.debug ] v
  | "bin-annot" -> set "bin-annot" [ Clflags.binary_annotations ] v
  | "afl-instrument" -> set_opt "afl-instrument" [ Clflags.afl_instrument ] v
  | "afl-inst-ratio" ->
      int_setter ppf "afl-inst-ratio" Clflags.afl_inst_ratio v
  | "annot" -> set "annot" [ Clflags.annotations ] v
  | "absname" -> set "absname" [ Clflags.absname ] v
  | "compat-32" -> set "compat-32" [ Clflags.bytecode_compatible_32 ] v
  | "noassert" -> set "noassert" [ Clflags.noassert ] v
  | "noautolink" -> set "noautolink" [ Clflags.no_auto_link ] v
  | "nostdlib" -> set "nostdlib" [ Clflags.no_std_include ] v
  | "nocwd" -> set "nocwd" [ Clflags.no_cwd ] v
  | "linkall" -> set "linkall" [ Clflags.link_everything ] v
  | "nolabels" -> set "nolabels" [ Clflags.classic ] v
  | "principal" -> set "principal"  [ Clflags.principal ] v
  | "rectypes" -> set "rectypes" [ Clflags.recursive_types ] v
  | "safe-string" -> compat "safe-string" v (* kept for compatibility *)
  | "strict-sequence" -> set "strict-sequence" [ Clflags.strict_sequence ] v
  | "strict-formats" -> set "strict-formats" [ Clflags.strict_formats ] v
  | "thread" -> set "thread" [ Clflags.use_threads ] v
  | "unboxed-types" -> set "unboxed-types" [ Clflags.unboxed_types ] v
  | "unsafe" -> set "unsafe" [ Clflags.unsafe ] v
  | "verbose" -> set "verbose" [ Clflags.verbose ] v
  | "nopervasives" -> set "nopervasives" [ Clflags.nopervasives ] v
  | "slash" -> set "slash" [ Clflags.force_slash ] v (* for ocamldep *)
  | "no-slash" -> clear "no-slash" [ Clflags.force_slash ] v (* for ocamldep *)
  | "keep-docs" -> set "keep-docs" [ Clflags.keep_docs ] v
  | "keep-locs" -> set "keep-locs" [ Clflags.keep_locs ] v

  | "compact" -> clear "compact" [ Clflags.optimize_for_speed ] v
  | "no-app-funct" -> clear "no-app-funct" [ Clflags.applicative_functors ] v
  | "nodynlink" -> clear "nodynlink" [ Clflags.dlcode ] v
  | "short-paths" -> clear "short-paths" [ Clflags.real_paths ] v
  | "trans-mod" -> set "trans-mod" [ Clflags.transparent_modules ] v
  | "opaque" -> set "opaque" [ Clflags.opaque ] v

  | "pp" -> Clflags.preprocessor := Some v
  | "runtime-variant" -> Clflags.runtime_variant := v
  | "with-runtime" -> set "with-runtime" [ Clflags.with_runtime ] v
  | "open" ->
      Clflags.open_modules :=
        List.rev_append (String.split_on_char ',' v) !Clflags.open_modules
  | "cc" -> Clflags.c_compiler := Some v

  | "clambda-checks" -> set "clambda-checks" [ Clflags.clambda_checks ] v

  | "function-sections" ->
    set "function-sections" [ Clflags.function_sections ] v
  (* assembly sources *)
  |  "s" ->
    set "s" [ Clflags.keep_asm_file ; Clflags.keep_startup_file ] v
  |  "S" -> set "S" [ Clflags.keep_asm_file ] v
  |  "dstartup" -> set "dstartup" [ Clflags.keep_startup_file ] v

  (* warn-errors *)
  | "we" | "warn-error" -> parse_warnings true v
  (* warnings *)
  |  "w"  ->               parse_warnings false v
  (* warn-errors *)
  | "wwe" ->               parse_warnings false v
  (* alerts *)
  | "alert" ->             Warnings.parse_alert_option v

  (* inlining *)
  | "inline" ->
      let module F = Clflags.Float_arg_helper in
      begin match F.parse_no_error v Clflags.inline_threshold with
      | F.Ok -> ()
      | F.Parse_failed exn ->
          Printf.ksprintf (print_error ppf)
            "bad syntax %s for \"inline\": %s" v (Printexc.to_string exn)
      end

  | "inline-toplevel" ->
    Clflags.Int_arg_helper.parse v
      "Bad syntax in OCAMLPARAM for 'inline-toplevel'"
      Clflags.inline_toplevel_threshold

  | "rounds" -> int_option_setter ppf "rounds" Clflags.simplify_rounds v
  | "inline-max-unroll" ->
    Clflags.Int_arg_helper.parse v
      "Bad syntax in OCAMLPARAM for 'inline-max-unroll'"
      Clflags.inline_max_unroll
  | "inline-call-cost" ->
    Clflags.Int_arg_helper.parse v
      "Bad syntax in OCAMLPARAM for 'inline-call-cost'"
      Clflags.inline_call_cost
  | "inline-alloc-cost" ->
    Clflags.Int_arg_helper.parse v
      "Bad syntax in OCAMLPARAM for 'inline-alloc-cost'"
      Clflags.inline_alloc_cost
  | "inline-prim-cost" ->
    Clflags.Int_arg_helper.parse v
      "Bad syntax in OCAMLPARAM for 'inline-prim-cost'"
      Clflags.inline_prim_cost
  | "inline-branch-cost" ->
    Clflags.Int_arg_helper.parse v
      "Bad syntax in OCAMLPARAM for 'inline-branch-cost'"
      Clflags.inline_branch_cost
  | "inline-indirect-cost" ->
    Clflags.Int_arg_helper.parse v
      "Bad syntax in OCAMLPARAM for 'inline-indirect-cost'"
      Clflags.inline_indirect_cost
  | "inline-lifting-benefit" ->
    Clflags.Int_arg_helper.parse v
      "Bad syntax in OCAMLPARAM for 'inline-lifting-benefit'"
      Clflags.inline_lifting_benefit
  | "inline-branch-factor" ->
    Clflags.Float_arg_helper.parse v
      "Bad syntax in OCAMLPARAM for 'inline-branch-factor'"
      Clflags.inline_branch_factor
  | "inline-max-depth" ->
    Clflags.Int_arg_helper.parse v
      "Bad syntax in OCAMLPARAM for 'inline-max-depth'"
      Clflags.inline_max_depth

  | "Oclassic" ->
      set "Oclassic" [ Clflags.classic_inlining ] v
  | "O2" ->
    if check_bool ppf "O2" v then begin
      Clflags.default_simplify_rounds := 2;
      Clflags.use_inlining_arguments_set Clflags.o2_arguments;
      Clflags.use_inlining_arguments_set ~round:0 Clflags.o1_arguments
    end

  | "O3" ->
    if check_bool ppf "O3" v then begin
      Clflags.default_simplify_rounds := 3;
      Clflags.use_inlining_arguments_set Clflags.o3_arguments;
      Clflags.use_inlining_arguments_set ~round:1 Clflags.o2_arguments;
      Clflags.use_inlining_arguments_set ~round:0 Clflags.o1_arguments
    end
  | "unbox-closures" ->
      set "unbox-closures" [ Clflags.unbox_closures ] v
  | "unbox-closures-factor" ->
      int_setter ppf "unbox-closures-factor" Clflags.unbox_closures_factor v
  | "remove-unused-arguments" ->
      set "remove-unused-arguments" [ Clflags.remove_unused_arguments ] v

  | "inlining-report" ->
      if !Clflags.native_code then
        set "inlining-report" [ Clflags.inlining_report ] v

  | "flambda-verbose" ->
      set "flambda-verbose" [ Clflags.dump_flambda_verbose ] v
  | "flambda-invariants" ->
      set_opt "flambda-invariants" [ Clflags.flambda_invariant_checks ] v
  | "cmm-invariants" ->
      set_opt "cmm-invariants" [ Clflags.cmm_invariants ] v
  | "linscan" ->
      set "linscan" [ Clflags.use_linscan ] v
  | "insn-sched" -> set "insn-sched" [ Clflags.insn_sched ] v
  | "no-insn-sched" -> clear "insn-sched" [ Clflags.insn_sched ] v

  (* color output *)
  | "color" ->
      begin match Clflags.color_reader.parse v with
      | None ->
        Printf.ksprintf (print_error ppf)
          "bad value %s for \"color\", (%s)" v Clflags.color_reader.usage
      | Some setting -> Clflags.color := Some setting
      end

  | "error-style" ->
      begin match Clflags.error_style_reader.parse v with
      | None ->
          Printf.ksprintf (print_error ppf)
            "bad value %s for \"error-style\", (%s)"
              v Clflags.error_style_reader.usage
      | Some setting -> Clflags.error_style := Some setting
      end

  | "intf-suffix" -> Clflags.interface_suffix := v

  | "I" -> begin
      match position with
      | Before_args -> prepend_to_list first_include_dirs v
      | Before_link | Before_compile _ ->
        prepend_to_list last_include_dirs v
    end

  | "cclib" ->
    begin
      match position with
      | Before_compile _ -> ()
      | Before_link | Before_args ->
        Clflags.ccobjs := Misc.rev_split_words v @ !Clflags.ccobjs
    end

  | "ccopt"
  | "ccopts"
    ->
    begin
      match position with
      | Before_link | Before_compile _ ->
        prepend_to_list last_ccopts v
      | Before_args ->
        prepend_to_list first_ccopts v
    end

  | "ppx" ->
    begin
      match position with
      | Before_link | Before_compile _ ->
        prepend_to_list last_ppx v
      | Before_args ->
        prepend_to_list first_ppx v
    end


  | "cmo" | "cma" ->
    if not !Clflags.native_code then
    begin
      match position with
      | Before_link | Before_compile _ ->
        prepend_to_list last_objfiles v
      | Before_args ->
        prepend_to_list first_objfiles v
    end

  | "cmx" | "cmxa" ->
    if !Clflags.native_code then
    begin
      match position with
      | Before_link | Before_compile _ ->
        prepend_to_list last_objfiles v
      | Before_args ->
        prepend_to_list first_objfiles v
    end

  | "pic" ->
    if !Clflags.native_code then
      set_opt "pic" [ Clflags.pic_code ] v

  | "can-discard" ->
    prepend_to_list can_discard v

  | "timings" | "profile" ->
     let if_on = if name = "timings" then [ `Time ] else Profile.all_columns in
     Clflags.profile_columns := if check_bool ppf name v then if_on else []

  | "stop-after" ->
    set_compiler_pass ppf v ~name Clflags.stop_after ~filter:(fun _ -> true)

  | "save-ir-after" ->
    if !Clflags.native_code then begin
      let filter = Clflags.Compiler_pass.can_save_ir_after in
      match decode_compiler_pass ppf v ~name ~filter with
      | None -> ()
      | Some pass -> Clflags.set_save_ir_after pass true
    end
  | "dump-into-file" -> Clflags.dump_into_file := true
  | "dump-dir" -> Clflags.dump_dir := Some v

  | _ ->
    if not (List.mem name !can_discard) then begin
      prepend_to_list can_discard name;
      Printf.ksprintf (print_error ppf)
        "Warning: discarding value of variable %S in OCAMLPARAM\n%!"
        name
    end


let read_OCAMLPARAM ppf position =
  try
    let s = Sys.getenv "OCAMLPARAM" in
    if s <> "" then
      let (before, after) =
        try
          parse_args s
        with SyntaxError s ->
          print_error ppf s;
          [],[]
      in
      List.iter (fun (name, v) -> read_one_param ppf position name v)
        (match position with
           Before_args -> before
         | Before_compile _ | Before_link -> after)
  with Not_found -> ()

(* OCAMLPARAM passed as file *)

type pattern =
  | Filename of string
  | Any

type file_option = {
  pattern : pattern;
  name : string;
  value : string;
}

let scan_line ic =
  Scanf.bscanf ic "%[0-9a-zA-Z_.*] : %[a-zA-Z_-] = %s "
    (fun pattern name value ->
       let pattern =
         match pattern with
         | "*" -> Any
         | _ -> Filename pattern
       in
       { pattern; name; value })

let load_config ppf filename =
  match open_in_bin filename with
  | exception e ->
      Location.errorf ~loc:(Location.in_file filename)
        "Cannot open file %s" (Printexc.to_string e)
      |> Location.print_report ppf;
      raise Exit
  | ic ->
      let sic = Scanf.Scanning.from_channel ic in
      let rec read line_number line_start acc =
        match scan_line sic with
        | exception End_of_file ->
            close_in ic;
            acc
        | exception Scanf.Scan_failure error ->
            let position = Lexing.{
                pos_fname = filename;
                pos_lnum = line_number;
                pos_bol = line_start;
                pos_cnum = pos_in ic;
              }
            in
            let loc = Location.{
                loc_start = position;
                loc_end = position;
                loc_ghost = false;
              }
            in
            Location.errorf ~loc "Configuration file error %s" error
            |> Location.print_report ppf;
            close_in ic;
            raise Exit
        | line ->
            read (line_number + 1) (pos_in ic) (line :: acc)
      in
      let lines = read 0 0 [] in
      lines

let matching_filename filename { pattern } =
  match pattern with
  | Any -> true
  | Filename pattern ->
    let filename = String.lowercase_ascii filename in
    let pattern = String.lowercase_ascii pattern in
    filename = pattern

let apply_config_file ppf position =
  let standard_library =
    Misc.get_stdlib Config_settings.standard_library_default in
  let config_file =
    Filename.concat standard_library "ocaml_compiler_internal_params"
  in
  let config =
    if Sys.file_exists config_file then
      load_config ppf config_file
    else
      []
  in
  let config =
    match position with
    | Before_compile filename ->
      List.filter (matching_filename filename) config
    | Before_args | Before_link ->
      List.filter (fun { pattern } -> pattern = Any) config
  in
  List.iter (fun { name; value } -> read_one_param ppf position name value)
    config

let readenv ppf position =
  last_include_dirs := [];
  last_ccopts := [];
  last_ppx := [];
  last_objfiles := [];
  apply_config_file ppf position;
  read_OCAMLPARAM ppf position;
  Clflags.all_ccopts := !last_ccopts @ !first_ccopts;
  Clflags.all_ppx := !last_ppx @ !first_ppx

let get_objfiles ~with_ocamlparam =
  if with_ocamlparam then
    List.rev (!last_objfiles @ !Clflags.objfiles @ !first_objfiles)
  else
    List.rev !Clflags.objfiles

let has_linker_inputs = ref false





type deferred_action =
  | ProcessImplementation of string
  | ProcessInterface of string
  | ProcessCFile of string
  | ProcessOtherFile of string
  | ProcessObjects of string list
  | ProcessDLLs of string list

let c_object_of_filename name =
  Filename.chop_suffix (Filename.basename name) ".c" ^ Config_settings.ext_obj

let process_action
    (ppf, implementation, interface, ocaml_mod_ext, ocaml_lib_ext) action =
  let impl ~start_from name =
    readenv ppf (Before_compile name);
    let opref = output_prefix name in
    implementation ~start_from ~source_file:name ~output_prefix:opref;
    prepend_to_list Clflags.objfiles (opref ^ ocaml_mod_ext)
  in
  match action with
  | ProcessImplementation name ->
      impl ~start_from:Clflags.Compiler_pass.Parsing name
  | ProcessInterface name ->
      readenv ppf (Before_compile name);
      let opref = output_prefix name in
      interface ~source_file:name ~output_prefix:opref;
      if !Clflags.make_package then
        prepend_to_list Clflags.objfiles (opref ^ ".cmi")
  | ProcessCFile name ->
      readenv ppf (Before_compile name);
      Location.input_name := name;
      let obj_name = match !Clflags.output_name with
        | None -> c_object_of_filename name
        | Some n -> n
      in
      if Ccomp.compile_file ?output:!Clflags.output_name name <> 0
      then raise (Exit_with_status 2);
      prepend_to_list Clflags.ccobjs obj_name
  | ProcessObjects names ->
      Clflags.ccobjs := names @ !Clflags.ccobjs
  | ProcessDLLs names ->
      Clflags.dllibs := names @ !Clflags.dllibs
  | ProcessOtherFile name ->
      if Filename.check_suffix name ocaml_mod_ext
      || Filename.check_suffix name ocaml_lib_ext then
        prepend_to_list Clflags.objfiles name
      else if Filename.check_suffix name ".cmi" && !Clflags.make_package then
        prepend_to_list Clflags.objfiles name
      else if Filename.check_suffix name Config_settings.ext_obj
           || Filename.check_suffix name Config_settings.ext_lib then begin
        has_linker_inputs := true;
        prepend_to_list Clflags.ccobjs name
      end
      else if not !Clflags.native_code
           && Filename.check_suffix name Config_settings.ext_dll then
        prepend_to_list Clflags.dllibs name
      else
        match Clflags.Compiler_pass.of_input_filename name with
        | Some start_from ->
          Location.input_name := name;
          impl ~start_from name
        | None -> raise(Arg.Bad("don't know what to do with " ^ name))


let action_of_file name =
  if Filename.check_suffix name ".ml"
  || Filename.check_suffix name ".mlt" then
    ProcessImplementation name
  else if Filename.check_suffix name !Clflags.interface_suffix then
    ProcessInterface name
  else if Filename.check_suffix name ".c" then
    ProcessCFile name
  else
    ProcessOtherFile name

let deferred_actions = ref []
let defer action =
  prepend_to_list deferred_actions action

let anonymous filename = defer (action_of_file filename)
let impl filename = defer (ProcessImplementation filename)
let intf filename = defer (ProcessInterface filename)

let process_deferred_actions env =
  let final_output_name = !Clflags.output_name in
  (* Make sure the intermediate products don't clash with the final one
     when we're invoked like: ocamlopt -o foo bar.c baz.ml. *)
  if not !Clflags.compile_only then Clflags.output_name := None;
  begin
    match final_output_name with
    | None -> ()
    | Some _output_name ->
        if !Clflags.compile_only then begin
          if List.length (List.filter (function
              | ProcessCFile _
              | ProcessImplementation _
              | ProcessInterface _ -> true
              | _ -> false) !deferred_actions) > 1 then
            fatal "Options -c -o are incompatible with compiling multiple files"
        end;
  end;
  if !Clflags.make_archive && List.exists (function
      | ProcessOtherFile name -> Filename.check_suffix name ".cmxa"
      | _ -> false) !deferred_actions then
    fatal "Option -a cannot be used with .cmxa input files.";
  List.iter (process_action env) (List.rev !deferred_actions);
  Clflags.output_name := final_output_name;
  stop_early :=
    !Clflags.compile_only ||
    !Clflags.print_types ||
    match !Clflags.stop_after with
    | None -> false
    | Some p -> Clflags.Compiler_pass.is_compilation_pass p

(* This function is almost the same as [Arg.parse_expand], except
   that [Arg.parse_expand] could not be used because it does not take a
   reference for [arg_spec].
   We use a marker \000 for Arg.parse_and_expand_argv_dynamic
   so we can split out error message from usage options, because
   it always concatenates
   error message with usage options *)
let parse_arguments ?(current=ref 0) argv f program =
    try
      Arg.parse_and_expand_argv_dynamic current argv Clflags.arg_spec f "\000"
    with
    | Arg.Bad err_msg ->
      let usage_msg = Clflags.create_usage_msg program in
      let err_msg = err_msg
      |> String.split_on_char '\000'
      |> List.hd
      |> String.trim in
      Printf.eprintf "%s\n%s\n" err_msg usage_msg;
      raise (Exit_with_status 2)
    | Arg.Help msg ->
      let err_msg =
        msg
        |> String.split_on_char '\000'
        |> String.concat "" in
      let help_msg =
        Printf.sprintf "Usage: %s <options> <files>\nOptions are:" program in
      Printf.printf "%s\n%s" help_msg err_msg;
      raise (Exit_with_status 0)
