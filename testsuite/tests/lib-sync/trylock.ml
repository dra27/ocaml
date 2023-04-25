<<<<<<< HEAD
(* TEST
   * skip
   reason = "OCaml 5 only"
*)
||||||| parent of 18bd88faf2 (New script language for ocamltest (PR#12185))
(* TEST
*)
=======
(* TEST *)
>>>>>>> 18bd88faf2 (New script language for ocamltest (PR#12185))

(* Test Mutex.try_lock *)

let () =
  let m = Mutex.create () in
  Mutex.lock m;
  let res = Mutex.try_lock m in
  if res = false then
    print_endline "passed"
  else
    print_endline "FAILED (try_lock returned true)"
