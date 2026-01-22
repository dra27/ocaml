(* XXX load_path. This should be able to go even further and replace the
       Sys.readdir itself with a computed value *)

module StringSet = Set.Make(String)
let artefacts =
  StringSet.of_list
    [(*Config.ext_obj; Config.ext_lib;*)
     ".cmi"; ".cmti"; ".cmt"; ".cmo"; ".cma"; ".cmxa"; ".cmxs"; ".cmx"]

module Filename = struct
  include Filename

  (* The Windows invocations use forward slashes for all filenames, so massage
     the results here to do the same thing just to get identical artefacts. *)
  let pedantically_canonical = true

  let concat =
    if pedantically_canonical then
      Printf.sprintf "%s/%s"
    else
      Filename.concat

  let canonical =
    if pedantically_canonical then
      String.map (function '\\' -> '/' | c -> c)
    else
      Fun.id
end

let augment dir files =
  let archive ?(cmxs = false) name files =
    let files =
      (name ^ Config.ext_lib) :: (name ^ ".cma") :: (name ^ ".cmxa") :: files
    in
    if cmxs then
      (name ^ ".cmxs") :: files
    else
      files
  in
  match Filename.basename dir with
  | "asmcomp" ->
      "arch.mli"
      :: "arch.ml"
      :: "CSE.ml"
      :: "emit.ml"
      :: "proc.ml"
      :: "selection.ml"
      :: "reload.ml"
      :: "scheduling.ml"
      :: "stackframe.ml"
      :: files
  | "bytecomp" ->
      "opcodes.mli" :: "opcodes.ml" :: files
  | "lambda" ->
      "runtimedef.ml" :: files
  | "debugger" ->
      "ocamldebug.cmi" :: "ocamldebug.cmo" :: "ocamldebug.cmt" :: files
  | "ocamldoc" ->
      archive "odoc_info" files
  | "parsing" ->
      "camlinternalMenhirLib.ml" :: "camlinternalMenhirLib.mli" :: files
  | ("byte" | "native") ->
      begin match Filename.basename (Filename.dirname dir) with
      | "dynlink" -> "dynlink.mli" :: files
      | "toplevel" -> "topeval.mli" :: "topmain.mli" :: "trace.mli" :: files
      | _ -> files
      end
  | "dynlink" ->
      "dynlink.cmx" :: archive "dynlink" files
  | "systhreads" ->
      archive "threads" files
  | "stdlib" ->
      (*("libcamlrun" ^ Config.ext_lib) :: ("libasmrun" ^ Config.ext_lib) ::*) archive "stdlib" files
  | "lib" ->
      archive "testing" files
  | ("str" | "unix" | "runtime_events") as lib ->
      archive ~cmxs:true lib files
  | "tools" ->
      "opnames.ml" :: files
  | "utils" ->
      "config.ml"
      :: "config_boot.mli"
      :: "config_boot.ml"
      :: "config_main.mli"
      :: "config_main.ml"
      :: "domainstate.mli"
      :: "domainstate.ml"
      :: files
  | _ ->
      files

let never_built =
  ["ocamltest/ocamltest_unix_dummy.ml";
   "ocamltest/ocamltest_unix_real.ml";
   "otherlibs/unix/unix_unix.ml";
   "otherlibs/unix/unix_win32.ml";
   "tools/gen_sizeclasses.ml";
   "utils/config.common.ml";
   "utils/config.generated.ml";
   "utils/config.fixed.ml"]
  |> StringSet.of_list

let cwd = ref "."
let cache = Hashtbl.create 42

let tree_predictor dir =
  try Hashtbl.find cache (!cwd, dir)
  with Not_found ->
    let results =
  if not (Filename.is_relative dir) then
    raise (Sys_error ("Skipping " ^ dir))
  else if Filename.basename dir = "boot" then
    Array.to_list (Sys.readdir dir)
  else
    let files =
      let not_artefact file =
        not (StringSet.mem (Filename.extension file) artefacts)
      in
      Sys.readdir dir
      |> Array.to_list
      |> List.filter not_artefact
      |> augment (if dir = Filename.current_dir_name then Sys.getcwd () else dir)
      |> StringSet.of_list
    in
    let rec expand file files =
      let ext = Filename.extension file in
      let base =
        let base = Filename.remove_extension file in
        let dir_base =
          if dir = Filename.current_dir_name then
            Filename.basename (Sys.getcwd ())
          else
            Filename.basename dir
        in
        if dir_base <> "stdlib" || base = "stdlib" || base = "std_exit" || String.starts_with ~prefix:"camlinternal" base then
          base
        else
          "stdlib__" ^ String.capitalize_ascii base
      in
      let add_ext acc ext = StringSet.add (base ^ ext) acc in
      if StringSet.mem (Filename.concat dir file) never_built then
        files
      else
        match ext with
        | ".mll" ->
            let file = base ^ ".ml" in
            expand file (StringSet.add file files)
        | ".mly" ->
            let file = base ^ ".ml" in
            let files = StringSet.add file (StringSet.add (file ^ "i") files) in
            expand (file ^ "i") (expand file files)
        | ".mli" ->
            List.fold_left add_ext files [".cmi"; ".cmti"]
        | ".ml" ->
            List.fold_left add_ext files [".cmo"; Config.ext_obj; ".cmt"; ".cmx"; ".cmi"; ".cmti"]
        | _ ->
            files
    in
    StringSet.elements (StringSet.fold expand files files)
    in
    Hashtbl.add cache (!cwd, dir) results;
    results

(*
let compile_interface ~source_file ~output_prefix =
  let unit_info = Unit_info.make ~source_file Intf output_prefix in
  Compile_common.with_info ~native:false ~tool_name:"ocamlc" ~dump_ext:"cmi" unit_info @@ fun info ->
  Compile_common.interface info

let compile_implementation ~source_file ~output_prefix =
  let backend info typed =
    let bytecode = Compile.to_bytecode info typed in
    Compile.emit_bytecode info bytecode
  in
  let unit_info = Unit_info.make ~source_file Impl output_prefix in
  Compile_common.with_info ~native:false ~tool_name:"ocamlc" ~dump_ext:"cmo" unit_info @@ fun info ->
    Compile_common.implementation info ~backend

let compile_file source_file =
  let output_prefix = Compenv.output_prefix source_file in
  if Filename.extension source_file = ".mli" then
    compile_interface ~source_file ~output_prefix
  else
    compile_implementation ~source_file ~output_prefix
*)

module Status = struct
  let current_file = ref None

  let esc () =
    if !current_file <> None then
      "\r\027[2K"
    else
      ""

  let compiling file =
    Printf.eprintf "%sCompiling: %s%!" (esc ()) file;
    current_file := Some file

  let note fmt =
    let f s =
      prerr_string (esc ());
      prerr_endline s;
      Option.iter compiling !current_file
    in
    Printf.ksprintf f fmt

  let complete fmt =
    let f s =
      prerr_string (esc ());
      prerr_endline s
    in
    Printf.ksprintf f fmt
end

let compile_file source_file () =
  let source_file = Filename.canonical source_file in
  Status.compiling source_file;
  Compenv.readenv Format.std_formatter (Before_compile source_file);
  let output_prefix = Compenv.output_prefix source_file in
  if Filename.extension source_file = ".mli" then
    Compile.interface ~source_file ~output_prefix
  else
    let start_from = Clflags.Compiler_pass.Parsing in
    Compile.implementation ~start_from ~source_file ~output_prefix

(*
   All files for ocamlcommon.cma, ocamlbytecomp.cma and ocamlc are compiled with:
   Boot flags: -nostdlib -I ./boot -use-prims runtime/primitives
   Includes: -I utils -I parsing -I typing -I bytecomp -I file_formats -I lambda -I middle_end -I middle_end/closure -I middle_end/flambda -I middle_end/flambda/base_types -I asmcomp -I driver -I toplevel -I tools -I runtime -I otherlibs/dynlink -I otherlibs/str -I otherlibs/systhreads -I otherlibs/unix -I otherlibs/runtime_events
   Compilation flags: -g -strict-sequence -principal -absname -w +a-4-9-40-41-42-44-45-48 -warn-error +a -bin-annot -strict-formats -c directory/file.ml

   compilerlibs/ocamlcommon.cma: -linkall -a
   compilerlibs/ocamlbytecomp.cma: -a
   ocamlc: -g -compat-32
*)

let boot_flags = [`Nostdlib; `Use_prims "runtime/primitives"]
let include_dirs = [
  "./boot"; "utils"; "parsing"; "typing"; "bytecomp"; "file_formats"; "lambda";
  "middle_end"; "middle_end/closure"; "middle_end/flambda";
  "middle_end/flambda/base_types"; "asmcomp"; "driver"; "toplevel"; "tools";
  "runtime"; "otherlibs/dynlink"; "otherlibs/str"; "otherlibs/systhreads";
  "otherlibs/unix"; "otherlibs/runtime_events"
]
let compile_flags = [
  `G; `Strict_sequence; `Principal; `Absname;
  `W "+a-4-9-40-41-42-44-45-48"; `Warn_error "+a"; `Bin_annot; `Strict_formats
]
let stdlib_compile_flags = [
  `G; `Strict_sequence; `Principal; `Absname;
  `W "+a-4-9-41-42-44-45-48"; `Warn_error "+A"; `Bin_annot; `Strict_formats
    (* XXX Why +A here and +a above?? *)
]

let set_flag = function
| `Linkall -> Clflags.link_everything := true
| `Compat32 -> Clflags.bytecode_compatible_32 := true
| `Nostdlib -> Clflags.no_std_include := true
| `Use_prims prims -> Clflags.use_prims := prims
| `G -> Clflags.debug := true
| `Strict_sequence -> Clflags.strict_sequence := true
| `Principal -> Clflags.principal := true
| `No_principal -> Clflags.principal := false;
| `Absname -> Clflags.absname := true
| `W warnings ->
    if Warnings.parse_options false warnings <> None then
      failwith "Bad warnings setting"
| `Warn_error warnings ->
    if Warnings.parse_options true warnings <> None then
      failwith "Bad warnings setting"
| `Bin_annot -> Clflags.binary_annotations := true
| `Strict_formats -> Clflags.strict_formats := true
| `Nolabels -> Clflags.classic := true
| `Labels -> Clflags.classic := false
| `Nopervasives -> Clflags.nopervasives := true
| `No_alias_deps -> Clflags.no_alias_deps := true
| `Alias_deps -> Clflags.no_alias_deps := false
| `PP arg -> Clflags.preprocessor := Some arg;
| _ -> failwith "unsupported library/link flag"

let reset_flag = function
| `Linkall -> Clflags.link_everything := false
| `Compat32 -> Clflags.bytecode_compatible_32 := false
| `Nolabels -> Clflags.classic := false
| `Labels -> Clflags.classic := true
| `No_principal -> Clflags.principal := true; (* XXX !!!! *)
| `Nopervasives -> Clflags.nopervasives := false
| `No_alias_deps -> Clflags.no_alias_deps := false
| `Alias_deps -> Clflags.no_alias_deps := true
| `PP _ -> Clflags.preprocessor := None
| `W _ -> () (* XXX !!! *)
| _ -> failwith "unsupported reset library/link flag"

let stdlib_compflags name =
  let basename = Filename.chop_extension name in
  let basename =
    if String.starts_with ~prefix:"stdlib__" basename then
      String.uncapitalize_ascii (String.sub basename 8 (String.length basename - 8))
    else
      basename
  in
  let kind = Filename.extension name in
  match basename, kind with
  | "camlinternalFormatBasics", _ ->
      [`Nopervasives]
  | "stdlib", _ ->
      [`Nopervasives; `No_alias_deps; `W "-49"; `PP "gawk -f ./expand_module_aliases.awk"]
  | "camlinternalLazy", ".cmx" ->
      [`Afl_inst_ratio 0]
  | "float", ".cmi" -> (* XXX This is a hack to deal with the fact it's triggered by float.cmo *)
      [`Labels; `Alias_deps]
  | "float", (".cmo"|".cmx") ->
      [`Nolabels; `No_alias_deps]
  | "buffer", ".cmx" ->
      [`Inline 3]
  | "buffer", (".cmi"|".cmo") ->
      [`W "+A"];
  | "camlinternalFormat", (".cmi"|".cmo") ->
      [ `W "+A"; `W "-fragile-match"]
  | "printf", (".cmi"|".cmo") ->
      [`W "+A"; `W "-fragile-match"]
  | "format", (".cmi"|".cmo") ->
      [`W "+A"; `W "-fragile-match"]
  | "scanf", ".cmx" ->
      [`Inline 9];
  | "scanf", (".cmi"|".cmo") ->
      [`W "+A"; `W "-fragile-match"]
  | "camlinternalOO", ".cmx" ->
      [`Inline 0; `Afl_inst_ratio 0];
  | "oo", ".cmi" ->
      [`No_principal];
  | name, _ when String.ends_with ~suffix:"Labels" name ->
      if kind = ".cmi" then
        [`PP "gawk -f ./expand_module_aliases.awk"]
      else
        [`Nolabels; `No_alias_deps]
  | _ ->
      [`W "+a-4-9-41-42-44-45-48"] (* XXX This a dreadful hack to "reset" the warnings between each call *)

let stdlib = [
  "camlinternalFormatBasics.mli";
  "camlinternalFormatBasics.ml";
  "stdlib.mli";
  "stdlib.ml";
  "either.mli";
  "either.ml";
  "sys.mli";
  "sys.ml";
  "int32.mli";
  "obj.mli";
  "obj.ml";
  "type.mli";
  "type.ml";
  "atomic.mli";
  "atomic.ml";
  "camlinternalLazy.mli";
  "camlinternalLazy.ml";
  "lazy.mli";
  "lazy.ml";
  "seq.mli";
  "seq.ml";
  "option.mli";
  "option.ml";
  "pair.mli";
  "pair.ml";
  "result.mli";
  "result.ml";
  "bool.mli";
  "bool.ml";
  "char.mli";
  "char.ml";
  "uchar.mli";
  "uchar.ml";
  "list.mli";
  "list.ml";
  "int.mli";
  "int.ml";
  "array.mli";
  "array.ml";
  "iarray.mli";
  "iarray.ml";
  "bytes.mli";
  "bytes.ml";
  "string.mli";
  "string.ml";
  "unit.mli";
  "unit.ml";
  "marshal.mli";
  "marshal.ml";
  "float.mli";
  "float.ml";
  "int32.ml";
  "int64.mli";
  "int64.ml";
  "nativeint.mli";
  "nativeint.ml";
  "lexing.mli";
  "lexing.ml";
  "parsing.mli";
  "parsing.ml";
  "repr.mli";
  "repr.ml";
  "set.mli";
  "set.ml";
  "map.mli";
  "map.ml";
  "stack.mli";
  "stack.ml";
  "queue.mli";
  "queue.ml";
  "buffer.mli";
  "buffer.ml";
  "mutex.mli";
  "mutex.ml";
  "condition.mli";
  "condition.ml";
  "semaphore.mli";
  "semaphore.ml";
  "domain.mli";
  "domain.ml";
  "camlinternalFormat.mli";
  "camlinternalFormat.ml";
  "printf.mli";
  "printf.ml";
  "arg.mli";
  "arg.ml";
  "printexc.mli";
  "printexc.ml";
  "fun.mli";
  "fun.ml";
  "gc.mli";
  "gc.ml";
  "complex.mli";
  "bigarray.mli";
  "in_channel.mli";
  "in_channel.ml";
  "out_channel.mli";
  "out_channel.ml";
  "digest.mli";
  "digest.ml";
  "bigarray.ml";
  "random.mli";
  "random.ml";
  "hashtbl.mli";
  "hashtbl.ml";
  "weak.mli";
  "weak.ml";
  "format.mli";
  "format.ml";
  "scanf.mli";
  "scanf.ml";
  "callback.mli";
  "callback.ml";
  "camlinternalOO.mli";
  "camlinternalOO.ml";
  "oo.mli";
  "oo.ml";
  "camlinternalMod.mli";
  "camlinternalMod.ml";
  "dynarray.mli";
  "dynarray.ml";
  "pqueue.mli";
  "pqueue.ml";
  "ephemeron.mli";
  "ephemeron.ml";
  "filename.mli";
  "filename.ml";
  "complex.ml";
  "arrayLabels.mli";
  "arrayLabels.ml";
  "listLabels.mli";
  "listLabels.ml";
  "bytesLabels.mli";
  "bytesLabels.ml";
  "stringLabels.mli";
  "stringLabels.ml";
  "moreLabels.mli";
  "moreLabels.ml";
  "stdLabels.mli";
  "stdLabels.ml";
  "effect.mli";
  "effect.ml";
]

let libraries = [
  "compilerlibs/ocamlcommon", "compiler-libs/ocamlcommon", [`Linkall], [
    "utils/config.mli";
    "utils/build_path_prefix_map.mli";
    "utils/format_doc.mli";
    "utils/misc.mli";
    "utils/identifiable.mli";
    "utils/numbers.mli";
    "utils/arg_helper.mli";
    "utils/local_store.mli";
    "utils/load_path.mli";
    "utils/profile.mli";
    "utils/clflags.mli";
    "utils/terminfo.mli";
    "utils/ccomp.mli";
    "utils/warnings.mli";
    "utils/consistbl.mli";
    "utils/linkdeps.mli";
    "utils/strongly_connected_components.mli";
    "utils/targetint.mli";
    "utils/int_replace_polymorphic_compare.mli";
    "utils/domainstate.mli";
    "utils/binutils.mli";
    "utils/lazy_backtrack.mli";
    "utils/diffing.mli";
    "utils/diffing_with_keys.mli";
    "utils/compression.mli";
    "parsing/location.mli";
    "parsing/unit_info.mli";
    "parsing/asttypes.mli";
    "parsing/longident.mli";
    "parsing/parsetree.mli";
    "parsing/docstrings.mli";
    "parsing/syntaxerr.mli";
    "parsing/ast_helper.mli";
    "parsing/ast_iterator.mli";
    "parsing/builtin_attributes.mli";
    "parsing/camlinternalMenhirLib.mli";
    "parsing/parser.mli";
    "parsing/pprintast.mli";
    "parsing/parse.mli";
    "parsing/printast.mli";
    "parsing/ast_mapper.mli";
    "parsing/attr_helper.mli";
    "parsing/ast_invariants.mli";
    "parsing/depend.mli";
    "typing/annot.mli";
    "typing/value_rec_types.mli";
    "typing/ident.mli";
    "typing/path.mli";
    "typing/type_immediacy.mli";
    "typing/outcometree.mli";
    "typing/primitive.mli";
    "typing/shape.mli";
    "typing/types.mli";
    "typing/data_types.mli";
    "typing/rawprinttyp.mli";
    "typing/gprinttyp.mli";
    "typing/btype.mli";
    "typing/oprint.mli";
    "typing/subst.mli";
    "typing/predef.mli";
    "typing/datarepr.mli";
    "file_formats/cmi_format.mli";
    "typing/persistent_env.mli";
    "typing/env.mli";
    "typing/errortrace.mli";
    "typing/typedtree.mli";
    "typing/signature_group.mli";
    "typing/printtyped.mli";
    "typing/ctype.mli";
    "typing/out_type.mli";
    "typing/printtyp.mli";
    "typing/errortrace_report.mli";
    "typing/includeclass.mli";
    "typing/mtype.mli";
    "typing/envaux.mli";
    "typing/includecore.mli";
    "typing/tast_iterator.mli";
    "typing/tast_mapper.mli";
    "typing/stypes.mli";
    "typing/shape_reduce.mli";
    "file_formats/cmt_format.mli";
    "typing/cmt2annot.mli";
    "typing/untypeast.mli";
    "typing/includemod.mli";
    "typing/includemod_errorprinter.mli";
    "typing/typetexp.mli";
    "typing/printpat.mli";
    "typing/patterns.mli";
    "typing/parmatch.mli";
    "typing/typedecl_properties.mli";
    "typing/typedecl_variance.mli";
    "typing/typedecl_unboxed.mli";
    "typing/typedecl_immediacy.mli";
    "typing/typedecl_separability.mli";
    "lambda/debuginfo.mli";
    "lambda/lambda.mli";
    "typing/typeopt.mli";
    "typing/typedecl.mli";
    "typing/value_rec_check.mli";
    "typing/typecore.mli";
    "typing/typeclass.mli";
    "typing/typemod.mli";
    "lambda/printlambda.mli";
    "lambda/switch.mli";
    "lambda/matching.mli";
    "lambda/value_rec_compiler.mli";
    "lambda/translobj.mli";
    "lambda/translattribute.mli";
    "lambda/translprim.mli";
    "lambda/translcore.mli";
    "lambda/translclass.mli";
    "lambda/translmod.mli";
    "lambda/tmc.mli";
    "lambda/simplif.mli";
    "lambda/runtimedef.mli";
    "file_formats/cmo_format.mli";
    "middle_end/internal_variable_names.mli";
    "middle_end/linkage_name.mli";
    "middle_end/compilation_unit.mli";
    "middle_end/variable.mli";
    "middle_end/flambda/base_types/closure_element.mli";
    "middle_end/flambda/base_types/var_within_closure.mli";
    "middle_end/flambda/base_types/tag.mli";
    "middle_end/symbol.mli";
    "middle_end/flambda/base_types/set_of_closures_id.mli";
    "middle_end/flambda/base_types/set_of_closures_origin.mli";
    "middle_end/flambda/parameter.mli";
    "middle_end/flambda/base_types/static_exception.mli";
    "middle_end/flambda/base_types/mutable_variable.mli";
    "middle_end/flambda/base_types/closure_id.mli";
    "middle_end/flambda/projection.mli";
    "middle_end/flambda/base_types/closure_origin.mli";
    "middle_end/clambda_primitives.mli";
    "middle_end/flambda/allocated_const.mli";
    "middle_end/flambda/flambda.mli";
    "middle_end/flambda/freshening.mli";
    "middle_end/flambda/base_types/export_id.mli";
    "middle_end/flambda/simple_value_approx.mli";
    "middle_end/flambda/export_info.mli";
    "middle_end/backend_var.mli";
    "middle_end/clambda.mli";
    "file_formats/cmx_format.mli";
    "file_formats/cmxs_format.mli";
    "bytecomp/instruct.mli";
    "bytecomp/meta.mli";
    "bytecomp/opcodes.mli";
    "bytecomp/bytesections.mli";
    "bytecomp/dll.mli";
    "bytecomp/symtable.mli";
    "driver/pparse.mli";
    "driver/compenv.mli";
    "driver/main_args.mli";
    "driver/compmisc.mli";
    "driver/makedepend.mli";
    "driver/compile_common.mli";
    "utils/config.ml";
    "utils/build_path_prefix_map.ml";
    "utils/format_doc.ml";
    "utils/misc.ml";
    "utils/identifiable.ml";
    "utils/numbers.ml";
    "utils/arg_helper.ml";
    "utils/local_store.ml";
    "utils/load_path.ml";
    "utils/clflags.ml";
    "utils/profile.ml";
    "utils/terminfo.ml";
    "utils/ccomp.ml";
    "utils/warnings.ml";
    "utils/consistbl.ml";
    "utils/linkdeps.ml";
    "utils/strongly_connected_components.ml";
    "utils/targetint.ml";
    "utils/int_replace_polymorphic_compare.ml";
    "utils/domainstate.ml";
    "utils/binutils.ml";
    "utils/lazy_backtrack.ml";
    "utils/diffing.ml";
    "utils/diffing_with_keys.ml";
    "utils/compression.ml";
    "parsing/location.ml";
    "parsing/unit_info.ml";
    "parsing/asttypes.ml";
    "parsing/longident.ml";
    "parsing/docstrings.ml";
    "parsing/syntaxerr.ml";
    "parsing/ast_helper.ml";
    "parsing/ast_iterator.ml";
    "parsing/builtin_attributes.ml";
    "parsing/camlinternalMenhirLib.ml";
    "parsing/parser.ml";
    "parsing/lexer.mli";
    "parsing/lexer.ml";
    "parsing/pprintast.ml";
    "parsing/parse.ml";
    "parsing/printast.ml";
    "parsing/ast_mapper.ml";
    "parsing/attr_helper.ml";
    "parsing/ast_invariants.ml";
    "parsing/depend.ml";
    "typing/ident.ml";
    "typing/path.ml";
    "typing/primitive.ml";
    "typing/type_immediacy.ml";
    "typing/shape.ml";
    "typing/types.ml";
    "typing/data_types.ml";
    "typing/rawprinttyp.ml";
    "typing/gprinttyp.ml";
    "typing/btype.ml";
    "typing/oprint.ml";
    "typing/subst.ml";
    "typing/predef.ml";
    "typing/datarepr.ml";
    "file_formats/cmi_format.ml";
    "typing/persistent_env.ml";
    "typing/env.ml";
    "typing/errortrace.ml";
    "typing/typedtree.ml";
    "typing/signature_group.ml";
    "typing/printtyped.ml";
    "typing/ctype.ml";
    "typing/out_type.ml";
    "typing/printtyp.ml";
    "typing/errortrace_report.ml";
    "typing/includeclass.ml";
    "typing/mtype.ml";
    "typing/envaux.ml";
    "typing/includecore.ml";
    "typing/tast_iterator.ml";
    "typing/tast_mapper.ml";
    "typing/stypes.ml";
    "typing/shape_reduce.ml";
    "file_formats/cmt_format.ml";
    "typing/cmt2annot.ml";
    "typing/untypeast.ml";
    "typing/includemod.ml";
    "typing/includemod_errorprinter.ml";
    "typing/typetexp.ml";
    "typing/printpat.ml";
    "typing/patterns.ml";
    "typing/parmatch.ml";
    "typing/typedecl_properties.ml";
    "typing/typedecl_variance.ml";
    "typing/typedecl_unboxed.ml";
    "typing/typedecl_immediacy.ml";
    "typing/typedecl_separability.ml";
    "typing/typeopt.ml";
    "typing/typedecl.ml";
    "typing/value_rec_check.ml";
    "typing/typecore.ml";
    "typing/typeclass.ml";
    "typing/typemod.ml";
    "lambda/debuginfo.ml";
    "lambda/lambda.ml";
    "lambda/printlambda.ml";
    "lambda/switch.ml";
    "lambda/matching.ml";
    "lambda/value_rec_compiler.ml";
    "lambda/translobj.ml";
    "lambda/translattribute.ml";
    "lambda/translprim.ml";
    "lambda/translcore.ml";
    "lambda/translclass.ml";
    "lambda/translmod.ml";
    "lambda/tmc.ml";
    "lambda/simplif.ml";
    "lambda/runtimedef.ml";
    "bytecomp/meta.ml";
    "bytecomp/opcodes.ml";
    "bytecomp/bytesections.ml";
    "bytecomp/dll.ml";
    "bytecomp/symtable.ml";
    "driver/pparse.ml";
    "driver/compenv.ml";
    "driver/main_args.ml";
    "driver/compmisc.ml";
    "driver/makedepend.ml";
    "driver/compile_common.ml"
  ];
  "compilerlibs/ocamlbytecomp", "compiler-libs/ocamlbytecomp", [], [
    "bytecomp/bytegen.mli";
    "bytecomp/printinstr.mli";
    "bytecomp/emitcode.mli";
    "bytecomp/bytelink.mli";
    "bytecomp/bytelibrarian.mli";
    "bytecomp/bytepackager.mli";
    "driver/errors.mli";
    "driver/compile.mli";
    "driver/maindriver.mli";
    "bytecomp/instruct.ml";
    "bytecomp/bytegen.ml";
    "bytecomp/printinstr.ml";
    "bytecomp/emitcode.ml";
    "bytecomp/bytelink.ml";
    "bytecomp/bytelibrarian.ml";
    "bytecomp/bytepackager.ml";
    "driver/errors.ml";
    "driver/compile.ml";
    "driver/maindriver.ml"
  ];
  "compilerlibs/ocamlmiddleend", "compiler-libs/ocamlmiddleend", [], [
    "middle_end/printclambda_primitives.mli";
    "middle_end/printclambda.mli";
    "middle_end/semantics_of_primitives.mli";
    "middle_end/convert_primitives.mli";
    "middle_end/flambda/base_types/id_types.mli";
    "middle_end/flambda/pass_wrapper.mli";
    "middle_end/flambda/flambda_iterators.mli";
    "middle_end/flambda/flambda_utils.mli";
    "middle_end/flambda/effect_analysis.mli";
    "middle_end/flambda/inlining_cost.mli";
    "middle_end/flambda/export_info_for_pack.mli";
    "middle_end/compilenv.mli";
    "middle_end/backend_intf.mli";
    "middle_end/closure/closure.mli";
    "middle_end/closure/closure_middle_end.mli";
    "middle_end/flambda/import_approx.mli";
    "middle_end/flambda/lift_code.mli";
    "middle_end/flambda/closure_conversion_aux.mli";
    "middle_end/flambda/closure_conversion.mli";
    "middle_end/flambda/initialize_symbol_to_let_symbol.mli";
    "middle_end/flambda/lift_let_to_initialize_symbol.mli";
    "middle_end/flambda/find_recursive_functions.mli";
    "middle_end/flambda/invariant_params.mli";
    "middle_end/flambda/inconstant_idents.mli";
    "middle_end/flambda/alias_analysis.mli";
    "middle_end/flambda/lift_constants.mli";
    "middle_end/flambda/share_constants.mli";
    "middle_end/flambda/simplify_common.mli";
    "middle_end/flambda/remove_unused_arguments.mli";
    "middle_end/flambda/remove_unused_closure_vars.mli";
    "middle_end/flambda/remove_unused_program_constructs.mli";
    "middle_end/flambda/simplify_boxed_integer_ops_intf.mli";
    "middle_end/flambda/simplify_boxed_integer_ops.mli";
    "middle_end/flambda/simplify_primitives.mli";
    "middle_end/flambda/inlining_stats_types.mli";
    "middle_end/flambda/inlining_stats.mli";
    "middle_end/flambda/inline_and_simplify_aux.mli";
    "middle_end/flambda/inlining_decision_intf.mli";
    "middle_end/flambda/remove_free_vars_equal_to_args.mli";
    "middle_end/flambda/extract_projections.mli";
    "middle_end/flambda/augment_specialised_args.mli";
    "middle_end/flambda/unbox_free_vars_of_closures.mli";
    "middle_end/flambda/unbox_specialised_args.mli";
    "middle_end/flambda/unbox_closures.mli";
    "middle_end/flambda/inlining_transforms.mli";
    "middle_end/flambda/inlining_decision.mli";
    "middle_end/flambda/inline_and_simplify.mli";
    "middle_end/flambda/ref_to_variables.mli";
    "middle_end/flambda/flambda_invariants.mli";
    "middle_end/flambda/traverse_for_exported_symbols.mli";
    "middle_end/flambda/build_export_info.mli";
    "middle_end/flambda/closure_offsets.mli";
    "middle_end/flambda/un_anf.mli";
    "middle_end/flambda/flambda_to_clambda.mli";
    "middle_end/flambda/flambda_middle_end.mli";
    "middle_end/internal_variable_names.ml";
    "middle_end/linkage_name.ml";
    "middle_end/compilation_unit.ml";
    "middle_end/variable.ml";
    "middle_end/flambda/base_types/closure_element.ml";
    "middle_end/flambda/base_types/closure_id.ml";
    "middle_end/symbol.ml";
    "middle_end/backend_var.ml";
    "middle_end/clambda_primitives.ml";
    "middle_end/printclambda_primitives.ml";
    "middle_end/clambda.ml";
    "middle_end/printclambda.ml";
    "middle_end/semantics_of_primitives.ml";
    "middle_end/convert_primitives.ml";
    "middle_end/flambda/base_types/id_types.ml";
    "middle_end/flambda/base_types/export_id.ml";
    "middle_end/flambda/base_types/tag.ml";
    "middle_end/flambda/base_types/mutable_variable.ml";
    "middle_end/flambda/base_types/set_of_closures_id.ml";
    "middle_end/flambda/base_types/set_of_closures_origin.ml";
    "middle_end/flambda/base_types/closure_origin.ml";
    "middle_end/flambda/base_types/var_within_closure.ml";
    "middle_end/flambda/base_types/static_exception.ml";
    "middle_end/flambda/pass_wrapper.ml";
    "middle_end/flambda/allocated_const.ml";
    "middle_end/flambda/parameter.ml";
    "middle_end/flambda/projection.ml";
    "middle_end/flambda/flambda.ml";
    "middle_end/flambda/flambda_iterators.ml";
    "middle_end/flambda/flambda_utils.ml";
    "middle_end/flambda/freshening.ml";
    "middle_end/flambda/effect_analysis.ml";
    "middle_end/flambda/inlining_cost.ml";
    "middle_end/flambda/simple_value_approx.ml";
    "middle_end/flambda/export_info.ml";
    "middle_end/flambda/export_info_for_pack.ml";
    "middle_end/compilenv.ml";
    "middle_end/closure/closure.ml";
    "middle_end/closure/closure_middle_end.ml";
    "middle_end/flambda/import_approx.ml";
    "middle_end/flambda/lift_code.ml";
    "middle_end/flambda/closure_conversion_aux.ml";
    "middle_end/flambda/closure_conversion.ml";
    "middle_end/flambda/initialize_symbol_to_let_symbol.ml";
    "middle_end/flambda/lift_let_to_initialize_symbol.ml";
    "middle_end/flambda/find_recursive_functions.ml";
    "middle_end/flambda/invariant_params.ml";
    "middle_end/flambda/inconstant_idents.ml";
    "middle_end/flambda/alias_analysis.ml";
    "middle_end/flambda/lift_constants.ml";
    "middle_end/flambda/share_constants.ml";
    "middle_end/flambda/simplify_common.ml";
    "middle_end/flambda/remove_unused_arguments.ml";
    "middle_end/flambda/remove_unused_closure_vars.ml";
    "middle_end/flambda/remove_unused_program_constructs.ml";
    "middle_end/flambda/simplify_boxed_integer_ops.ml";
    "middle_end/flambda/simplify_primitives.ml";
    "middle_end/flambda/inlining_stats_types.ml";
    "middle_end/flambda/inlining_stats.ml";
    "middle_end/flambda/inline_and_simplify_aux.ml";
    "middle_end/flambda/remove_free_vars_equal_to_args.ml";
    "middle_end/flambda/extract_projections.ml";
    "middle_end/flambda/augment_specialised_args.ml";
    "middle_end/flambda/unbox_free_vars_of_closures.ml";
    "middle_end/flambda/unbox_specialised_args.ml";
    "middle_end/flambda/unbox_closures.ml";
    "middle_end/flambda/inlining_transforms.ml";
    "middle_end/flambda/inlining_decision.ml";
    "middle_end/flambda/inline_and_simplify.ml";
    "middle_end/flambda/ref_to_variables.ml";
    "middle_end/flambda/flambda_invariants.ml";
    "middle_end/flambda/traverse_for_exported_symbols.ml";
    "middle_end/flambda/build_export_info.ml";
    "middle_end/flambda/closure_offsets.ml";
    "middle_end/flambda/un_anf.ml";
    "middle_end/flambda/flambda_to_clambda.ml";
    "middle_end/flambda/flambda_middle_end.ml";
  ];
]

let programs = [
  "ocamlc", "ocamlc.byte", ["compilerlibs/ocamlcommon.cma"; "compilerlibs/ocamlbytecomp.cma"], [`Compat32], ["driver/main.mli"; "driver/main.ml"];
  "lex/ocamllex", "ocamllex.byte", [], [`Compat32], [
    "cset.mli"; "cset.ml";
    "syntax.mli"; "syntax.ml";
    "parser.mli"; "parser.ml";
    "lexer.mli"; "lexer.ml";
    "table.mli"; "table.ml";
    "lexgen.mli"; "lexgen.ml";
    "compact.mli"; "compact.ml";
    "common.mli"; "common.ml";
    "output.mli"; "output.ml";
    "outputbis.mli"; "outputbis.ml";
    "main.mli"; "main.ml";];
]


let profiling_driver_files = [
  "config.cmo"; "build_path_prefix_map.cmo"; "format_doc.cmo"; "misc.cmo"; "profile.cmo"; "warnings.cmo"; "identifiable.cmo"; "numbers.cmo"; "arg_helper.cmo"; "local_store.cmo"; "load_path.cmo"; "clflags.cmo"; "terminfo.cmo"; "location.cmo"; "ccomp.cmo"; "compenv.cmo"; "main_args.cmo"
]

(* tools/profiling module *)
let tools = [
  (* These three don't need to be built in a release build *)
  "dumpobj", "", false, `Bytecode_only, ["compilerlibs/ocamlcommon.cma"; "compilerlibs/ocamlbytecomp.cma"], [], ["opnames.mli"; "opnames.ml"];
  "primreq", "", false, `Bytecode_only, ["compilerlibs/ocamlcommon.cma"; "compilerlibs/ocamlbytecomp.cma"], [], [];
  "cmpbyt", "", false, `Bytecode_only, ["compilerlibs/ocamlcommon.cma"; "compilerlibs/ocamlbytecomp.cma"], [], [];
  (* cvt_emit ignored for now *)
  (* make_opcodes ignored for now *)
  (* expunge ignored for now *)
  (* Currently needed as part of install *)
  "stripdebug", "", false, `Bytecode_only, ["compilerlibs/ocamlcommon.cma"; "compilerlibs/ocamlbytecomp.cma"], [], [];
  (* Tools themselves *)
  "ocamldep", "ocamldep.byte", true, `Both, ["compilerlibs/ocamlcommon.cma"; "compilerlibs/ocamlbytecomp.cma"], [`Compat32], [];
  "ocamlobjinfo", "ocamlobjinfo.byte", true, `Both, ["compilerlibs/ocamlcommon.cma"; "compilerlibs/ocamlbytecomp.cma"; "compilerlibs/ocamlmiddleend.cma"], [], [];
  "ocamlcmt", "ocamlcmt", true, `Bytecode_only, ["compilerlibs/ocamlcommon.cma"; "compilerlibs/ocamlbytecomp.cma"], [], [];
  "ocamlprof", "ocamlprof", true, `Bytecode_only, ["config.cmo"; "build_path_prefix_map.cmo"; "format_doc.cmo"; "misc.cmo"; "identifiable.cmo"; "numbers.cmo"; "arg_helper.cmo"; "local_store.cmo"; "load_path.cmo"; "clflags.cmo"; "terminfo.cmo"; "warnings.cmo"; "location.cmo"; "longident.cmo"; "docstrings.cmo"; "syntaxerr.cmo"; "ast_helper.cmo"; "ast_iterator.cmo"; "builtin_attributes.cmo"; "camlinternalMenhirLib.cmo"; "parser.cmo"; "lexer.cmo"; "pprintast.cmo"; "parse.cmo"], [], [];
  "ocamlcp", "ocamlcp", true, `Bytecode_only, profiling_driver_files, [], ["ocamlcp_common.mli"; "ocamlcp_common.ml"];
  "ocamlmklib", "ocamlmklib", true, `Bytecode_only, ["config.cmo"; "build_path_prefix_map.cmo"; "format_doc.cmo"; "misc.cmo"], [], [];
  "ocamlmktop", "ocamlmktop", true, `Bytecode_only, ["config.cmo"; "build_path_prefix_map.cmo"; "format_doc.cmo"; "misc.cmo"; "identifiable.cmo"; "numbers.cmo"; "arg_helper.cmo"; "local_store.cmo"; "load_path.cmo"; "clflags.cmo"; "profile.cmo"; "ccomp.cmo"], [], [];
  "ocamloptp", (*"ocamloptp"*)"", true, `Bytecode_only, profiling_driver_files @ ["ocamlcp_common.cmo"], [], [];
  (* sync_dynlink and lintapidiff ignored for now *)
  (* ocamltex ignored for now *)
  (* testsuite/tools/codegen and testscode/tools/expect ignored for now *)
]

let build_tool (name, install_name, _installed, _mode, precompiled, flags, files) =
  let files = files @ [name ^ ".mli"; name ^ ".ml"] in
  let name = Filename.concat "tools" name in
  name, install_name, precompiled, flags, files

let programs = programs @ List.map build_tool tools

let get_objects files =
  List.filter_map (fun file -> if Filename.extension file = ".ml" then Some (Compenv.output_prefix file ^ ".cmo") else None) files

let cmis = Hashtbl.create 512
let rec execute task =
  try task ()
  with effect (Load_path.Missing path), k ->
    if Filename.extension path <> ".cmi" then begin
      Printf.eprintf "Not a .cmi?!\n";
      exit 1
    end;
    let file = Filename.chop_extension path ^ ".mli" in
    execute (compile_file file);
    execute (Effect.Deep.continue k)
  | effect (Persistent_env.CMI path), k ->
      let cmi =
        try Hashtbl.find cmis path
        with Not_found ->
          if Filename.basename (Filename.dirname path) <> "boot" then begin
            let file = Filename.chop_extension path ^ ".mli" in
            Status.note "  -> Compiling %s on-demand" file;
            execute (compile_file file)
          end;
          let cmi = Cmi_format.read_cmi path in
          Hashtbl.add cmis path cmi;
          cmi
      in
      let task () = Effect.Deep.continue k (cmi : Cmi_format.cmi_infos) in
      execute task

let compile_files files =
  Clflags.compile_only := true;
  List.iter execute (List.map (fun file () -> Status.note "Compiling %s" file; compile_file file ()) files);
  Clflags.compile_only := false

let compare this that =
  let that = Filename.concat "install" that in
  let this_md5 = In_channel.with_open_bin this (fun ic -> Digest.channel ic (-1)) in
  let that_md5 = In_channel.with_open_bin that (fun ic -> Digest.channel ic (-1)) in
  Status.note "Comparing %s and %s" this that;
  if this_md5 <> that_md5 then begin
    Status.complete "%s and %s differ!" this that;
    exit 1
  end

let compile_library (name, install_name, flags, files) =
  let files = List.filter (fun file -> Filename.extension file <> ".mli") files in
  Bytelibrarian.reset ();
  compile_files files;
  List.iter set_flag flags;
  Compmisc.init_path ();
  Bytelibrarian.create_archive (get_objects files) (name ^ ".cma");
  List.iter reset_flag flags;
  compare (name ^ ".cma") (Filename.concat "lib" (Filename.concat "ocaml" (install_name ^ ".cma")))

let compile_stdlib_module (name, flags) () =
  List.iter set_flag flags;
  let restore = !Clflags.include_dirs in
  Clflags.include_dirs := [];
  if String.starts_with ~prefix:"camlinternal" name || name = "stdlib.ml" || name = "stdlib.mli" || name = "std_exit.ml" || name = "std_exit.mli" then
    Clflags.output_name := None
  else
    Clflags.output_name := Some ("stdlib__" ^ String.capitalize_ascii (Filename.chop_extension name) ^ (if Filename.extension name = ".mli" then ".cmi" else ".cmo"));
  compile_file name ();
  Clflags.include_dirs := restore;
  List.iter reset_flag flags

let rec stdlib_execute task =
  try task ()
  with effect (Load_path.Missing path), k ->
    if Filename.extension path <> ".cmi" then begin
      Printf.eprintf "Not a .cmi?!\n";
      exit 1
    end;
    let file = Filename.chop_extension path ^ ".mli" in
    let file =
      if String.starts_with ~prefix:"stdlib__" file then
        String.uncapitalize_ascii (String.sub file 8 (String.length file - 8))
      else
        file
    in
    stdlib_execute (compile_stdlib_module (file, stdlib_compflags path));
    stdlib_execute (Effect.Deep.continue k)
  | effect (Persistent_env.CMI path), k ->
      let cmi =
        try Hashtbl.find cmis path
        with Not_found ->
          let file = Filename.chop_extension path ^ ".mli" in
          let file =
            if String.starts_with ~prefix:"stdlib__" file then
              String.uncapitalize_ascii (String.sub file 8 (String.length file - 8))
            else
              file
          in
          Status.note "  -> Compiling %s on-demand" file;
          stdlib_execute (compile_stdlib_module (file, stdlib_compflags path));
          let cmi = Cmi_format.read_cmi path in
          Hashtbl.add cmis path cmi;
          cmi
      in
      let task () = Effect.Deep.continue k cmi in
      stdlib_execute task

let compile_stdlib modules =
  Sys.chdir "stdlib";
  cwd := "stdlib";
  List.iter set_flag stdlib_compile_flags;
  Clflags.compile_only := true;
  let modules = List.filter (fun name -> Filename.extension name <> ".mli") modules in
  let modules =
    let f name =
      let artefact =
        if Filename.extension name = ".mli" then
          Filename.chop_extension name ^ ".cmi"
        else
          Filename.chop_extension name ^ ".cmo"
      in
      (name, stdlib_compflags artefact)
    in
    List.map f modules @ [(*("std_exit.mli", []);*) ("std_exit.ml", [])]
  in
  List.iter stdlib_execute (List.map (fun ((file, _) as module_) () -> Status.note "Compiling %s" file; compile_stdlib_module module_ ()) modules); (* XXX Bad sign that std_exit.ml needed to be last - presumably a flag being reset for the compilation. This should be at the start of the list *)
  Clflags.compile_only := false;
  (* XXX Dreadful duplication... *)
  Bytelibrarian.reset ();
  Bytelibrarian.create_archive (List.filter_map (fun (name, _) -> if Filename.extension name = ".mli" || name = "std_exit.ml" then None else let name = Filename.chop_extension name in Some (if String.starts_with ~prefix:"camlinternal" name || name = "stdlib" then name ^ ".cmo" else "stdlib__" ^ String.capitalize_ascii name ^ ".cmo")) modules) "stdlib.cma";
  Sys.chdir "..";
  cwd := ".";
  compare "stdlib/stdlib.cma" (Filename.concat "lib" (Filename.concat "ocaml" "stdlib.cma"))

let add_include dir = Clflags.include_dirs := dir :: !Clflags.include_dirs

let compile_program (name, install_name, precompiled, flags, files) =
  let name = if Sys.win32 then name ^ ".exe" else name in
  let files = List.filter (fun file -> Filename.extension file <> ".mli") files in
  Dll.reset ();
  Symtable.reset ();
  Bytelink.reset ();
  let dir = Filename.dirname name in
  let restore = !Clflags.include_dirs in
  let files =
    if dir <> Filename.current_dir_name then begin
      Clflags.include_dirs := restore @ [dir];
      List.map (Filename.concat dir) files
    end else
      files
  in
  compile_files files;
  List.iter set_flag flags;
  Compmisc.init_path ();
  (* XXX Temporarily: allows comparing without installing first *)
  Clflags.debug := false;
  begin try
  Bytelink.link (precompiled @ get_objects files) name;
  with Bytelink.Error err -> Bytelink.report_error Format.std_formatter err
  end;
  (* XXX Temporarily: revert above *)
  Clflags.debug := true;
  List.iter reset_flag flags;
  Clflags.include_dirs := restore;
  if install_name <> "" then
    compare name (Filename.concat "bin" install_name ^ (if Sys.win32 then ".exe" else ""))

(* XXX main *)

let _ =
  try
    (* XXX This is actually done to freeze the local store, and is therefore
           something of a hack... *)
    let _ = Local_store.fresh () in
    Load_path.hooked := true;
    List.iter add_include (List.rev include_dirs);
    if Sys.backend_type = Native then
      ()
    else begin
      (* XXX Certain the stdlib .cmt and .cmti don't yet match (at *least* the
             argv capturing will be problematic. Search path may also be incorrect
             for the stdlib *)
      List.iter set_flag boot_flags;
      List.iter set_flag compile_flags;
      List.iter compile_library libraries;
      List.iter compile_program programs;
      compile_stdlib stdlib;
      (* We have coreall! *)
      (* XXX Next follows ocaml *)
      (* XXX NATIVE: opt-core *)
      (* XXX NATIVE: ocamlc.opt - affects these next ones *)
      (* XXX Next follows otherlibraries ocamldebug ocamldoc [and ocamltest] *)
      (* XXX Next follows othertools - i.e. ocamltex, etc. *)
      (* Now we have all *)
      Status.complete "Build complete!"
    end
  with e -> Location.report_exception Format.err_formatter e
  | effect Load_path.Dir dir, k ->
      Effect.Deep.continue k (tree_predictor dir)
