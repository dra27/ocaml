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
  assert (Mutex.try_lock m);
  Mutex.unlock m;
  print_endline "passed"
