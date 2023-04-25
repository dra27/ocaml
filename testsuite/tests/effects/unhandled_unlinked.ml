(* TEST
 exit_status = "2";
 reason = "OCaml 5 only";
 skip;
*)

open Effect
type _ t += E : unit t
let _ = perform E
