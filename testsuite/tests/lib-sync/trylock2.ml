(* TEST
 reason = "OCaml 5 only";
 skip;
 *)

(* Test Mutex.try_lock *)

let () =
  let m = Mutex.create () in
  assert (Mutex.try_lock m);
  Mutex.unlock m;
  print_endline "passed"
