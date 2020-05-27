(* TEST
   * windows
   ** bytecode
   ** native
 *)

(* Tests for Filename.{dirname, basename concat}. These test cases are for
   Windows and Cygwin and cover some of the weirder corner cases. The result
   of concat is either the same or the test or can be overridden. Any asterisks
   in the expected concat result are converted to Filename.dir_sep (which allows
   tests to be written for Cygwin and Windows which change slightly on concat)
 *)
let tests = [
(* Test         | dirname      | basename   | concat *)
  (* Second colon should be ignored (invalid on Win32; valid on Cygwin) *)
  {|C:\foo:bar|}, {|C:\|}      , {|foo:bar|}, None;
  {|C:/foo:bar|}, {|C:/|}      , {|foo:bar|}, None;
 (if Sys.cygwin then
  {|C:foo:bar|} , {|.|}        , {|C:foo:bar|}, Some "./C:foo:bar"
  else
  {|C:foo:bar|} , {|C:|}       , {|foo:bar|}, None
 );
  (* Drive relative specifications *)
 (if Sys.cygwin then
  {|C:|}        , {|.|}        , {|C:|}     , Some {|./C:|}
  else
  {|C:|}        , {|C:|}       , {|.|}      , Some {|C:.|}
 );
  {|C:\|}       , {|C:\|}      , {|\|}      , Some {|C:\\|};
  {|C:/|}       , {|C:/|}      , {|/|}      , Some {|C://|};
]

let check l a b =
  if a = b then
    Printf.printf "%s: passed\n" l
  else
    Printf.printf "%s: failed (%s)\n" l a

let expand_concat (default, d, b, s) =
  let s =
    Option.value s ~default
    |> String.map (function '*' -> Filename.dir_sep.[0] | c -> c)
  in
    (default, d, b, s)

let tests = List.map expand_concat tests

let execute (path, expected_dirname, expected_basename, expected_concat) =
  Printf.printf "Test: %s\n" path;
  let dirname = Filename.dirname path in
  check "dirname" dirname expected_dirname;
  let basename = Filename.basename path in
  check "basename" basename expected_basename;
  let concat = Filename.concat dirname basename in
  check "concat" concat expected_concat

let () =
  List.iter execute tests
