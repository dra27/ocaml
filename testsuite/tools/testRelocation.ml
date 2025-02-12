(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*                        David Allsopp, Tarides                          *)
(*                                                                        *)
(*   Copyright 2025 David Allsopp Ltd.                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

open Environment.Import

let utf_16le_of_utf_8 s =
  let s = Misc.Stdlib.String.to_utf_8_seq s in
  let utf_16le_length =
    Seq.fold_left (fun acc u -> acc + Uchar.utf_16_byte_length u) 0 s in
  let b = Bytes.create utf_16le_length in
  ignore (Seq.fold_left (fun i u -> i + Bytes.set_utf_16le_uchar b i u) 0 s);
  Bytes.unsafe_to_string b

let rec matches_at file search i j =
  let c1 = Bigarray.Array1.unsafe_get file i in
  let c2 = String.unsafe_get search j in
  (c1 = c2 || Sys.win32 && c1 = '\\' && c2 = '/')
    && (j = 0 || matches_at file search (i - 1) (j - 1))

let matches_at file file_len i s =
  let s_len = String.length s in
  if i + s_len > file_len then
    false
  else
    matches_at file s (i + s_len - 1) (s_len - 1)

type location = Build | Prefix | Relative
type finding =
| Build_dir of cwd * encoding
| Prefix_dir of encoding
| Relative_libdir of encoding
and encoding = UTF_8 | UTF_16
and cwd = Physical | Logical

module LocationSet = Set.Make(struct
  type t = location
  let compare = Stdlib.compare
end)

let rec contains file file_len tests i seen =
  if i = file_len then
    seen
  else
    let c = Bigarray.Array1.unsafe_get file i in
    let seen, i =
      if c = '/' || Sys.win32 && c = '\\' then
        let check_for acc (t, s) =
          if matches_at file file_len i s then
            (t, s)::acc
          else
            acc in
        let seen_here = List.fold_left check_for [] tests in
        let seen_here =
          let compare (_, l) (_, r) =
            -Int.compare (String.length l) (String.length r) in
          List.sort compare seen_here in
        match seen_here with
        | (t, s)::_ ->
            t :: seen, i + String.length s
        | [] ->
            seen, i
      else
        seen, i in
    contains file file_len tests (i + 1) seen

let read_content file ic =
  let len = in_channel_length ic in
  let content = Bigarray.Array1.create Bigarray.Char Bigarray.c_layout len in
  if In_channel.really_input_bigarray ic content 0 len = None then
    Environment.fail_because "Error reading %s" file;
  content, len

let output_compunit ic oc (compunit : Cmo_format.compilation_unit) =
  seek_in ic compunit.cu_pos;
  Misc.copy_file_chunk ic oc compunit.cu_codesize;
  if compunit.cu_debug > 0 then begin
    seek_in ic compunit.cu_debug;
    output_value oc (Compression.input_value ic);
    output_value oc (Compression.input_value ic);
  end;
  output_value oc compunit

let with_decompressed_ocaml_artefact ic file f =
  let magic = Cmt_format.read_magic_number ic in
  let temp_file, oc =
    Filename.open_temp_file ~mode:[Open_binary] "ocaml-artefact-" ".tmp" in
  let () =
    if magic = Config.cmi_magic_number || magic = Config.cmt_magic_number then
      output_value oc (Cmt_format.read file)
    else if magic = Config.cmo_magic_number then begin
      seek_in ic (input_binary_int ic);
      let compunit = (input_value ic : Cmo_format.compilation_unit) in
      output_compunit ic oc compunit
    end else if magic = Config.cma_magic_number then begin
      seek_in ic (input_binary_int ic);
      let toc = (input_value ic : Cmo_format.library) in
      List.iter (output_compunit ic oc) toc.lib_units;
      output_value oc toc
    end else
      Environment.fail_because "Unexpected magic number %S in %s" magic file in
  close_out oc;
  let result = In_channel.with_open_bin temp_file (f temp_file) in
  Sys.remove temp_file;
  result

let read_file env file =
  In_channel.with_open_bin file @@ fun ic ->
    match Filename.extension file with
    | ".cma" | ".cmi" | ".cmo" | ".cmti" | ".cmt" ->
        with_decompressed_ocaml_artefact ic file read_content
    | ext when (ext = Config.ext_lib || ext = Config.ext_obj)
               && Sys.os_type = "Unix" && Config.system <> "macosx" ->
        let exit, lines =
          Environment.run_process Return ~quiet:true env "readelf" ["-tS"; file]
        in
        let contains_compressed l =
          if l = "" || l.[0] <> ' ' then
            false
          else
            let test = String.starts_with ~prefix:"COMPRESSED" in
            let l = String.split_on_char ' ' l in
            List.exists test l in
        if exit <> 0 then
          Environment.fail_because "readelf failed"
        else if List.exists contains_compressed lines then
          let temp_file = Filename.temp_file "ocaml-artefact-" ".tmp" in
          let exit, _ =
            let args = ["--decompress-debug-sections"; file; temp_file] in
            Environment.run_process Return ~quiet:true env "objcopy" args
          in
          if exit = 0 then
            let result =
              In_channel.with_open_bin temp_file (read_content temp_file) in
            Sys.remove temp_file;
            result
          else begin
            Sys.remove temp_file;
            Environment.fail_because "objcopy failed"
          end
        else
          read_content file ic
    | _ ->
        read_content file ic

module StringMap = Map.Make(String)

let run ~reproducible (config : Installation.t) env =
  let prefix = Environment.prefix env in
  let grandparent dir = Filename.dirname (Filename.dirname dir) in
  let build_root =
    grandparent (Environment.test_root env) in
  let build_root_logical =
    Option.map grandparent (Environment.test_root_logical env) in
  let relative_libdir, build_root, build_root_logical, prefix =
    let relative = Option.map ((^) "/") config.has_relative_libdir in
    if Sys.win32 then
      let normalise s =
        let s =
          if String.length s > 2
             && Char.Ascii.is_letter s.[0] && s.[1] = ':' then
            String.sub s 2 (String.length s - 2)
          else
            s in
        String.map (function '\\' -> '/' | c -> c) s in
      let build_root_logical =
        let f dir = normalise (Filename.dirname (Filename.dirname dir)) in
        Option.map f (Environment.test_root_logical env)
      in
      Option.map normalise relative, normalise build_root,
      Option.map normalise build_root_logical, normalise prefix
    else
      relative, build_root, build_root_logical, prefix in
  Printf.printf "\nChecking installed files for\n\
                  \  Installation Prefix: %s\n" prefix;
  Option.iter (Printf.printf "  Relative Suffix: %s\n") relative_libdir;
  begin match build_root_logical with
  | Some build_root_logical ->
      Printf.printf "  Build Root (physical): %s\n\
                    \  Build Root (logical): %s\n%!"
                    build_root build_root_logical
  | None ->
      Printf.printf "  Build Root: %s\n%!" build_root
  end;
  let tests =
    Option.value ~default:[]
      (Option.map (fun relative_libdir ->
         [Relative_libdir UTF_8, relative_libdir;
          Relative_libdir UTF_16, utf_16le_of_utf_8 relative_libdir])
        relative_libdir)
  in
  let tests =
    Option.value ~default:tests
      (Option.map (fun build_root_logical ->
        (Build_dir(Logical, UTF_8), build_root_logical) ::
        (Build_dir(Logical, UTF_16), utf_16le_of_utf_8 build_root_logical) ::
        tests) build_root_logical)
  in
  let tests =
    (Prefix_dir UTF_8, prefix) ::
    (Prefix_dir UTF_16, utf_16le_of_utf_8 prefix) ::
    (Build_dir(Physical, UTF_8), build_root) ::
    (Build_dir(Physical, UTF_16), utf_16le_of_utf_8 build_root) :: tests
  in
  let reproducible_rules file =
    if Filename.basename file = "Makefile.config" then
      LocationSet.of_list [Relative; Prefix]
    else
      LocationSet.empty
  in
  let in_unexpected_state file file_rel rules =
    let content, content_len = read_file env file in
    let seen = contains content content_len tests 0 [] in
    let string_of_encoding () =
      function UTF_8 -> "UTF-8" | UTF_16 -> "UTF-16" in
    let string_of_cwd () =
      function Physical -> "Physical" | Logical -> "Logical" in
    let string_of_build_dir =
      if Environment.test_root_logical env = None then
        fun () (_, encoding) ->
          Printf.sprintf "in %a" string_of_encoding encoding
      else
        fun () (cwd, encoding) ->
          Printf.sprintf
            "%a; in %a" string_of_cwd cwd string_of_encoding encoding
    in
    let some_string fmt = Printf.ksprintf Option.some fmt in
    let gather seen = function
    | Build_dir(kind, enc) ->
        if LocationSet.mem Build seen then
          seen, None
        else
          LocationSet.add Build seen,
          some_string "Build directory (%a)" string_of_build_dir (kind, enc)
    | Prefix_dir enc ->
        if LocationSet.mem Prefix seen then
          seen, None
        else
          LocationSet.add Prefix seen,
          some_string "Installation prefix (%a)" string_of_encoding enc
    | Relative_libdir enc ->
        if LocationSet.mem Relative seen then
          seen, None
        else
          LocationSet.add Relative seen,
          some_string "Relative suffix (%a)" string_of_encoding enc
    in
    let seen, hits = List.fold_left_map gather LocationSet.empty seen in
    let expected = rules file in
    let reproducible = reproducible_rules file in
    let consistent = LocationSet.equal expected reproducible in
    let reproducible = LocationSet.equal seen reproducible in
    if LocationSet.equal seen expected then
      ~incorrect:false, ~seen, ~reproducible, ~consistent
    else
      let string_of_location = function
      | Build -> "Build directory"
      | Prefix -> "Installation prefix"
      | Relative -> "Relative prefix" in
          let hits = List.filter_map Fun.id hits in
          let msg =
            if hits = [] then
              "is relocatable"
            else
              "contains the " ^ String.concat " & " hits in
          let expected =
            let expected = LocationSet.elements expected in
            if expected = [] then
              "be relocatable"
            else
              let expected = List.map string_of_location expected in
              "contain the " ^ String.concat " & " expected in
          Printf.eprintf "%s: expected to %s, but it %s\n"
                         file_rel expected msg;
          ~incorrect:true, ~seen, ~reproducible, ~consistent
  in
  let rec scan dir rel h rules
               ((~failed, ~results, ~reproducible:reproducible_so_far,
                 ~consistent:consistent_so_far) as acc) =
    match Unix.readdir h with
    | entry ->
        let acc =
          if entry <> Filename.current_dir_name
             && entry <> Filename.parent_dir_name then
            let entry_rel = Filename.concat rel entry in
            let entry = Filename.concat dir entry in
            match Unix.lstat entry with
            | {Unix.st_kind = S_DIR; _} ->
                scan entry entry_rel (Unix.opendir entry) rules acc
            | {Unix.st_kind = S_REG; _} ->
                let ~incorrect, ~seen, ~reproducible, ~consistent =
                  in_unexpected_state entry entry_rel rules in
                  ~failed:(failed || incorrect),
                  ~results:((entry_rel, seen)::results),
                  ~reproducible:(reproducible_so_far && reproducible),
                  ~consistent:(consistent_so_far && consistent)
            | _ ->
                acc
          else
            acc in
        scan dir rel h rules acc
    | exception End_of_file ->
        Unix.closedir h;
        acc in
  let c_compiler_debug_paths_are_absolute =
    Toolchain.c_compiler_debug_paths_can_be_absolute
    && (not Config.c_has_debug_prefix_map || config.has_relative_libdir = None)
  in
  let assembler_embeds_build_path =
    Toolchain.assembler_embeds_build_path
    && (not Config.as_has_debug_prefix_map
        || Config.architecture = "riscv"
        || Config.as_is_cc
        || config.has_relative_libdir = None)
  in
  let bindir_rules file =
    let basename = Filename.basename file in
    if Filename.extension basename = ".manifest" then
      (* Executable manifests installed as part of flexlink for the MSVC port *)
      LocationSet.empty
    else
      (* Analysis on filenames doesn't need to care about .exe *)
      let basename =
        Filename.chop_suffix_opt ~suffix:".exe" basename
        |> Option.value ~default:basename in
      let classification = Environment.classify_executable file in
      (* Determine if the installation prefix should be found in this file *)
      let prefix =
        let code_embeds_stdlib_location =
          (* The runtime binaries all contain OCAML_STDLIB_DIR and everything
             except flexlink and ocamllex link with the Config module, either
             directly or via ocamlcommon *)
          config.has_relative_libdir = None
          && not (List.mem basename ["flexlink.byte"; "flexlink.opt";
                                     "ocamllex.byte"; "ocamllex.opt";
                                     "ocamlyacc"])
        in
        let linker_embeds_stdlib_location =
          (* If the launcher doesn't search for ocamlrun, then either the #!
             stub will include the absolute path or the RNTM section will *)
          match classification with
          | Tendered _ when not config.launcher_searches_for_ocamlrun -> true
          | _ -> false
        in
        if code_embeds_stdlib_location || linker_embeds_stdlib_location then
          LocationSet.singleton Prefix
        else
          LocationSet.empty
      in
      (* Determining if the build path will be found consists of two strictly
         separated portions: the properties we expect from the file itself and
         then how they are applied by the platform itself.
         First, determine if the program was compiled by ocamlopt, ocamlc or is
         a pure C program and, additionally, whether it was linked with -g.
         These are properties of the programs themselves, so there should be no
         platform-specific references in these definitions. *)
      let program_kind, linked_with_debug =
        (* As it happens, all ocamlopt-produced executables end with .opt or are
           ocamlnat. Other mechanisms (in particular looking for the
           caml_start_program symbol) are available, but are a bit more complex
           to make portable, and we don't need them at the moment, since
           -output-obj, -output-complete-obj or -output-complete-exe are not
           used by the compiler distribution. *)
        if String.ends_with ~suffix:".opt" basename
           || basename = "ocamlnat" then
          (* All native executable are linked with -g apart from flexlink.opt *)
          `Native_ocaml, (basename <> "flexlink.opt")
        else if classification <> Vanilla then
          (* Only ocamlc.byte, ocamlopt.byte and ocaml are linked with -g, but
             the debugging information in ocamlc.byte and ocamlopt.byte is
             stripped. *)
          `Bytecode_ocaml, (basename = "ocaml")
        else
          (* Bytecode runtimes and ocamlyacc of which only ocamlrund is linked
             with -g *)
          `Other, (basename = "ocamlrund")
      in
      (* Combine this with the properties of the platform to determine whether
         the executable will contain the build path. *)
      let contains_build_path =
        match program_kind with
        | `Native_ocaml ->
            (* If the linker propagates debugging information, it doesn't matter
               whether -g was passed to ocamlopt, because the build path will be
               embedded via libasmrun *)
            Toolchain.linker_embeds_build_path
            || (Toolchain.linker_propagates_debug_information
                && (c_compiler_debug_paths_are_absolute
                    || assembler_embeds_build_path))
        | `Bytecode_ocaml ->
            (* Only ocamlc.byte, ocamlopt.byte and ocaml are linked with -g, but
               the debugging information in ocamlc.byte and ocamlopt.byte is
               stripped. However, since the C objects in libcamlrun are compiled
               with -g, this will still result in debug information for -custom
               runtime executables. *)
            linked_with_debug && config.has_relative_libdir = None
            || (classification = Custom
                && Toolchain.linker_propagates_debug_information
                && c_compiler_debug_paths_are_absolute)
        | `Other ->
            (* Only ocamlrund is linked with -g. However, since the C objects
               which make up the executables are all compiled with -g, this
               will still result in debug information in all non-OCaml
               executables. *)
            Toolchain.linker_embeds_build_path
            || (c_compiler_debug_paths_are_absolute
                && (Toolchain.linker_propagates_debug_information
                    || linked_with_debug))
      in
      if contains_build_path then
        LocationSet.add Build prefix
      else
        prefix
  in
  let libdir_rules file =
    let basename = Filename.basename file in
    let ext = Filename.extension basename in
    if basename = "expunge" || basename = "expunge.exe" then
      bindir_rules file
    else
      let (~stdlib:embeds_stdlib_location,
           ~ocaml_debug:has_ocaml_debug_info,
           ~c_debug:contains_c_debug_info,
           ~s:contains_assembled_objects) =
        if basename = "Makefile.config" then
          (~stdlib:true, ~ocaml_debug:false, ~c_debug:false, ~s:false)
        else if basename = "config.cmx" then
          let stdlib =
            config.has_relative_libdir = None && not Config.flambda in
          (~stdlib, ~ocaml_debug:false, ~c_debug:false, ~s:false)
        else if List.mem ext [".cma"; ".cmo"; ".cmt"; ".cmti"] then
          let stdlib =
            config.has_relative_libdir = None
            && List.mem basename ["config.cmt"; "config_main.cmt";
                                  "ocamlcommon.cma"] in
          let ocaml_debug =
            config.has_relative_libdir = None in
          (~stdlib, ~ocaml_debug, ~c_debug:false, ~s:false)
        else if basename = "runtime-launch-info" then
          let stdlib = config.has_relative_libdir = None in
          (~stdlib, ~ocaml_debug:false, ~c_debug:false, ~s:false)
        else if ext = ".cmxs" then
          (~stdlib:false, ~ocaml_debug:false, ~c_debug:true, ~s:true)
        else if ext = Config.ext_obj then
          let is_ocaml =
            Sys.file_exists (Filename.remove_extension file ^ ".cmx") in
          let c_debug =
            not (is_ocaml || String.starts_with ~prefix:"flexdll_" basename) in
          (~stdlib:false, ~ocaml_debug:false, ~c_debug, ~s:is_ocaml)
        else if ext = Config.ext_lib || ext = Config.ext_dll then
          if ext = Config.ext_lib then
            let is_ocaml =
              Sys.file_exists (Filename.remove_extension file ^ ".cmxa") in
            let stdlib =
              config.has_relative_libdir = None
              && Filename.remove_extension basename = "ocamlcommon" in
            let c_debug = not is_ocaml in
            (~stdlib, ~ocaml_debug:false, ~c_debug, ~s:is_ocaml)
          else
            (~stdlib:false, ~ocaml_debug:false, ~c_debug:true, ~s:false)
        else
          (~stdlib:false, ~ocaml_debug:false, ~c_debug:false, ~s:false)
      in
      let contains_build_path =
        if String.starts_with ~prefix:"libasmrun" basename then
          ((c_compiler_debug_paths_are_absolute
              && Toolchain.asmrun_assembled_with_cc)
           || (assembler_embeds_build_path
                 && not Toolchain.asmrun_assembled_with_cc)
           || ext = Config.ext_dll && Toolchain.linker_embeds_build_path)
        else if (ext = Config.ext_dll || ext = ".cmxs")
           && (not Toolchain.linker_propagates_debug_information
               || Toolchain.linker_embeds_build_path) then
          Toolchain.linker_embeds_build_path
        else
          has_ocaml_debug_info
          || contains_c_debug_info && c_compiler_debug_paths_are_absolute
          || contains_assembled_objects && assembler_embeds_build_path
          || ext = Config.ext_obj
             && Toolchain.c_compiler_always_embeds_build_path
      in
      let prefix =
        if embeds_stdlib_location then
          LocationSet.singleton Prefix
        else
          LocationSet.empty
      in
      let prefix =
        if config.has_relative_libdir <> None
           && basename = "Makefile.config" then
          LocationSet.add Relative prefix
        else
          prefix
      in
      if contains_build_path then
        LocationSet.add Build prefix
      else
        prefix
  in
  let scan f rel_root =
    let dir = f env in
    scan dir rel_root (Unix.opendir dir)
  in
  let ~failed, ~results, ~reproducible:results_are_reproducible, ~consistent =
    ~failed:false, ~results:[], ~reproducible:true, ~consistent:true
    |> scan Environment.bindir "$bindir" bindir_rules
    |> scan Environment.libdir "$libdir" libdir_rules
  in
  flush stderr;
  let () =
    if results_are_reproducible && not consistent then
      Environment.fail_because
        "Internal error: bindir_rules and libdir_rules disagree with \
         reproducible_rules"
    else if results_are_reproducible <> reproducible then
      Environment.fail_because
        "The build is %sexpected to be reproducible"
        (if not reproducible then "not " else "")
  in
  let sections =
    let f acc (_, seen) = LocationSet.union acc seen in
    List.fold_left f LocationSet.empty results
    |> LocationSet.elements
    |> List.sort Stdlib.compare
    |> List.map Option.some
    |> List.cons None in
  let results =
    let aggregate acc ((file, seen) as item) =
      let extension =
        if String.starts_with ~prefix:"$bindir" file then
          "$bindir/"
        else if Filename.basename file = "META" then
          "/META"
        else
          let extension = Filename.extension file in
          if extension = ".conf" || extension = ".config" then
            ""
          else if extension = ".in" then
            Filename.extension (Filename.remove_extension file) ^ extension
          else
            extension
      in
      let (files, all_seen) =
        try StringMap.find extension acc
        with Not_found -> [], LocationSet.empty
      in
      StringMap.add extension (item::files, LocationSet.union seen all_seen) acc
    in
    let aggregated = List.fold_left aggregate StringMap.empty results in
    let collapse extension (files, all_seen) acc =
      if extension = "" then
        List.rev_append files acc
      else
        let test section =
          let test =
            Option.fold ~none:LocationSet.is_empty ~some:LocationSet.mem section
          in
          let section =
            Option.fold ~none:LocationSet.empty
                        ~some:LocationSet.singleton section
          in
          match List.partition (fun (_, s) -> test s) files with
          | _::_, (([] | [_] | [_; _]) as exceptions) ->
              let extension, exceptions =
                if extension.[0] = '.' then
                  "*" ^ extension, List.map fst exceptions
                else if extension.[0] = '/' then
                  "**" ^ extension, List.map fst exceptions
                else
                  let l = String.length extension in
                  let chop (f, _) = String.sub f l (String.length f - l) in
                  extension ^ "*", List.map chop exceptions
              in
              let suffix =
                if exceptions = [] then
                  ""
                else
                  " (except " ^ String.concat " and " exceptions ^ ")"
              in
              let files =
                let keep (file, seen) =
                  let seen = LocationSet.diff seen section in
                  if LocationSet.is_empty seen then
                    None
                  else
                    Some (file, seen)
                in
                List.filter_map keep files
              in
              let item = (extension ^ suffix, section) in
              Some (item :: List.rev_append files acc)
          | _, _ ->
              None
        in
        let result =
          LocationSet.elements all_seen
          |> List.sort Stdlib.compare
          |> List.map Option.some
          |> List.cons None
          |> List.find_map test
        in
        match result with
        | Some acc ->
            acc
        | None ->
            List.rev_append files acc
    in
    StringMap.fold collapse aggregated []
  in
  let display section =
    let test =
      match section with
      | None ->
          Printf.printf "\nRelocatable files:\n";
          LocationSet.is_empty
      | Some path ->
          let name =
            match path with
            | Build -> "build path"
            | Prefix -> "installation prefix"
            | Relative -> "relative suffix"
          in
          Printf.printf "\nFiles containing the %s:\n" name;
          LocationSet.mem path
    in
    (* Put wildcard patterns first *)
    let compare l r = Stdlib.compare (l.[0] <> '*', l) (r.[0] <> '*', r) in
    let results =
      List.filter_map (fun (f, s) -> if test s then Some f else None) results
      |> List.sort compare
    in
    let pp_sep f () = Format.pp_print_char f ','; Format.pp_print_space f () in
    let pp_results = Format.(pp_print_list ~pp_sep pp_print_string) in
    Format.printf "@[<hov 4>  %a@]@." pp_results results
  in
  if failed then
    Environment.fail_because "Installed files don't match expectation"
  else
  List.iter display sections
