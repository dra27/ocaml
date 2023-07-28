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

let main argv ppf =
  Compmisc.process_use_config argv;
  let program = "ocamlc" in
  (* The functor must be called _after_ Compmisc.process_use_config *)
  let module Options =
    Main_args.Make_bytecomp_options (Main_args.Default.Main) in
  Clflags.add_arguments __LOC__ Options.list;
  Clflags.add_arguments __LOC__
    ["-depend", Arg.Unit Makedepend.main_from_option,
     "<options> Compute dependencies (use 'ocamlc -depend -help' for details)"];
  let exception Continue in
  match
    Compenv.readenv ppf Before_args;
    Compenv.parse_arguments (ref argv) Compenv.anonymous program;
    Compmisc.read_clflags_from_env ();
    if !Clflags.plugin then
      Compenv.fatal "-plugin is only supported up to OCaml 4.08.0";
    begin try
      Compenv.process_deferred_actions
        (ppf,
         Compile.implementation,
         Compile.interface,
         ".cmo",
         ".cma");
    with Arg.Bad msg ->
      begin
        prerr_endline msg;
        Clflags.print_arguments program;
        exit 2
      end
    end;
    if Clflags.(should_stop_after Compiler_pass.Lambda)
      then raise Continue;
    Compenv.readenv ppf Before_link;
    if List.fold_left
         (fun c x -> if !x then succ c else c) 0
         [Clflags.make_archive; Clflags.make_package; Compenv.stop_early;
          Clflags.output_c_object] > 1 then begin
      let module P = Clflags.Compiler_pass in
      match !Clflags.stop_after with
      | None ->
          Compenv.fatal
            "Please specify at most one of -pack, -a, -c, -output-obj";
      | Some ((P.Parsing | P.Typing | P.Lambda) as p) ->
        assert (P.is_compilation_pass p);
        Printf.ksprintf Compenv.fatal
          "Options -i and -stop-after (%s) \
           are  incompatible with -pack, -a, -output-obj"
          (String.concat "|"
             (P.available_pass_names ~filter:(fun _ -> true) ~native:false))
      | Some (P.Scheduling | P.Emit) -> assert false (* native only *)
    end;
    if !Clflags.make_archive then begin
      Compmisc.init_path ();

      Bytelibrarian.create_archive
        (Compenv.get_objfiles ~with_ocamlparam:false)
        (Compenv.extract_output !Clflags.output_name);
      Warnings.check_fatal ();
    end
    else if !Clflags.make_package then begin
      Compmisc.init_path ();
      let extracted_output = Compenv.extract_output !Clflags.output_name in
      let revd = Compenv.get_objfiles ~with_ocamlparam:false in
      Compmisc.with_ppf_dump ~file_prefix:extracted_output (fun ppf_dump ->
        Bytepackager.package_files ~ppf_dump (Compmisc.initial_env ())
          revd (extracted_output));
      Warnings.check_fatal ();
    end
    else if not !Compenv.stop_early && !Clflags.objfiles <> [] then begin
      let target =
        if !Clflags.output_c_object
        && not !Clflags.output_complete_executable then
          let s = Compenv.extract_output !Clflags.output_name in
          if (Filename.check_suffix s Clflags.config.ext_obj
            || Filename.check_suffix s Clflags.config.ext_dll
            || Filename.check_suffix s ".c")
          then s
          else
            Compenv.fatal
              (Printf.sprintf
                 "The extension of the output file must be .c, %s or %s"
                 Clflags.config.ext_obj Clflags.config.ext_dll
              )
        else
          Compenv.default_output !Clflags.output_name
      in
      Compmisc.init_path ();
      Bytelink.link (Compenv.get_objfiles ~with_ocamlparam:true) target;
      Warnings.check_fatal ();
    end;
  with
  | exception (Compenv.Exit_with_status n) ->
    n
  | exception Continue
  | () ->
    Compmisc.with_ppf_dump ~file_prefix:"profile"
      (fun ppf -> Profile.print ppf !Clflags.profile_columns);
    0
  | exception x ->
  Location.report_exception ppf x;
  2
