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

let is_clang =
  List.mem "clang" (String.split_on_char '-' Config.c_compiler_vendor)

let is_clang_assembler =
  (* The clang-cl build of the MSVC port still has to MASM at present *)
  is_clang && Config.ccomp_type <> "msvc"

(* Determine two properties of the way programs are linked w.r.t. debug
   information: does debug information use absolute paths, and is (some) debug
   information in .o files always transferred to the resulting executable,
   even if it is not linked with -g. These are properties of the platform, so
   there should be no file-specific references in these definitions. *)
let (~absolute_paths:c_compiler_debug_paths_can_be_absolute,
     ~implicit_debug_info:linker_propagates_debug_information,
     ~embeds:c_compiler_always_embeds_build_path,
     ~asmrun_assembled_with_cc) =
  if Config.ccomp_type = "msvc" then
    (* The MSVC port calls the linker directly, and debugging information is
       not propagated. At present, building with clang-cl also uses the
       Microsoft Linker. clang-cl, however, embeds relative paths in objects
       (for reasons which are not entirely clear) *)
    (~absolute_paths:(not is_clang),
     ~implicit_debug_info:false,
     ~embeds:true,
     ~asmrun_assembled_with_cc:false)
  else
    (~absolute_paths:true,
     ~implicit_debug_info:true,
     ~embeds:false,
     ~asmrun_assembled_with_cc:true)

let assembler_embeds_build_path =
  if is_clang_assembler && Config.system = "macosx" then
    (* Xcode 16 targetting macOS 15 or later uses DWARF v5 and embeds build
       paths by default, cf. https://developer.apple.com/documentation/xcode-release-notes/xcode-16-release-notes *)
    match String.split_on_char '-' Config.c_compiler_vendor,
          String.split_on_char '-' Config.target with
    | ["clang"; major; _], [_; "apple"; darwin]
      when String.starts_with ~prefix:"darwin" darwin ->
        (* Xcode 16.0 shipped with clang-16.00.0.26.3
           macOS 15 uses Darwin 24.x *)
        let clang_major =
          Scanf.sscanf_opt major "%u%!" (fun x -> x >= 16)
          |> Option.value ~default:true (* Assume up-to-date *)
        and darwin_major =
          Scanf.sscanf_opt darwin "darwin%u." (fun x -> x >= 24)
          |> Option.value ~default:true (* Assume up-to-date *)
        in
        clang_major && darwin_major
    | _ ->
        false
  else
    not (String.starts_with ~prefix:"mingw" Config.system)
    && not is_clang_assembler

let linker_embeds_build_path =
  Config.system = "macosx"

(* linker_is_flexlink is true for Cygwin when shared library support is enabled
   and always true for native Windows. *)
let linker_is_flexlink =
  Sys.win32 || Sys.cygwin && Config.supports_shared_libraries

(* exe ["foo" = "foo.exe"] on Windows or ["foo"] otherwise. *)
let exe =
  if Sys.win32 then
    Fun.flip (^) ".exe"
  else
    Fun.id

(* The execution and argv[0] tests need to know whether caml_executable_name is
   implemented for this platform (at present, Linux, macOS and native Windows
   are; *BSD and Cygwin are not) *)
external proc_self_exe : unit -> string option = "caml_sys_proc_self_exe"
let no_caml_executable_name = (proc_self_exe () = None)
