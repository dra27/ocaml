(* TEST
 *)

(* This tests the Filename.is_relative and Filename.is_implicit functions.
   Each tuple below contains a test path and the expected outcome on each
   of the three platforms (Absolute, Drive-Relative, CWD-Relative, or Implicit).
*)
let tests = [
  (* Unix   | Win32  | Cygwin | Test *)
     `Imp   , `Abs   , `Abs   , {|\\server\share|};
     `Imp   , `Abs   , `Abs   , {|\\server/share|};
     `Imp   , `Abs   , `Abs   , {|\/server\share|};
     `Imp   , `Abs   , `Abs   , {|\/server/share|};
     `Abs   , `Abs   , `Abs   , {|/\server\share|};
     `Abs   , `Abs   , `Abs   , {|/\server/share|};
     `Abs   , `Abs   , `Abs   , {|//server\share|};
     `Abs   , `Abs   , `Abs   , {|//server/share|};
     `Imp   , `Abs   , `Abs   , {|C:\|};
     `Imp   , `Abs   , `Abs   , {|C:/|};
     `Imp   , `Drv   , `Drv   , {|\|};
     `Abs   , `Drv   , `Abs   , {|/|};
     `Imp   , `Drv   , `Drv   , {|\dir|};
     `Abs   , `Drv   , `Abs   , {|/dir|};
     `Imp   , `Drv   , `Imp   , {|C:|};
     `Imp   , `Drv   , `Imp   , {|C:file-in-cwd|};
     `Imp   , `Drv   , `Abs   , {|C:dir-in-cwd\file|};
     `Imp   , `Drv   , `Imp   , {|C:dir-in-cwd/file|};
     `Imp   , `Imp   , `Imp   , {|.|};
     `Imp   , `Rel   , `Rel   , {|.\|};
     `Rel   , `Rel   , `Rel   , {|./|};
     `Imp   , `Imp   , `Imp   , {|..|};
     `Imp   , `Rel   , `Rel   , {|..\|};
     `Rel   , `Rel   , `Rel   , {|../|};
     `Imp   , `Rel   , `Rel   , {|.\file-in-cwd|};
     `Rel   , `Rel   , `Rel   , {|./file-in-cwd|};
     `Imp   , `Rel   , `Rel   , {|..\file-in-cwd|};
     `Rel   , `Rel   , `Rel   , {|../file-in-cwd|};
]

let get_expected_outcomes result test =
  match result with
  | `Abs -> (test, false, false, false)
  | `Drv -> (test, true, false, false)
  | `Rel -> (test, false, true, false)
  | `Imp -> (test, false, true, true) (* Filename.is_implicit f => Filename.is_relative f *)

let get_platform_outcome =
  if Sys.cygwin then
    fun (_, _, outcome, test) -> get_expected_outcomes outcome test
  else if Sys.win32 then
    fun (_, outcome, _, test) -> get_expected_outcomes outcome test
  else
    fun (outcome, _, _, test) -> get_expected_outcomes outcome test

let execute (case, is_drive_relative, is_relative, is_implicit) =
  Printf.printf "Testing %S\n  is_drive_relative: " case;
  if is_drive_relative = Filename.is_drive_relative case then
    print_endline "passed"
  else
    Printf.printf "failed (expected %b)\n" is_drive_relative;
  print_string "  is_relative: ";
  if is_relative = Filename.is_relative case then
    print_endline "passed"
  else
    Printf.printf "failed (expected %b)\n" is_relative;
  print_string "  is_implicit: ";
  if is_implicit = Filename.is_implicit case then
    print_endline "passed"
  else
    Printf.printf "failed (expected %b)\n" is_implicit

let () =
  List.iter execute @@ List.map get_platform_outcome tests
