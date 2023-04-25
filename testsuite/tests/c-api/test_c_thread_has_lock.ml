(* TEST
<<<<<<< HEAD
   modules = "test_c_thread_has_lock_cstubs.c"
   * skip
   reason = "OCaml 5 only"
   ** bytecode
   ** native
||||||| parent of 18bd88faf2 (New script language for ocamltest (PR#12185))
   modules = "test_c_thread_has_lock_cstubs.c"
   * bytecode
   * native
=======
 modules = "test_c_thread_has_lock_cstubs.c";
 {
   bytecode;
 }{
   native;
 }
>>>>>>> 18bd88faf2 (New script language for ocamltest (PR#12185))
*)

external test_with_lock : unit -> bool = "with_lock"
external test_without_lock : unit -> bool = "without_lock"

let passed b = Printf.printf (if b then "passed\n" else "failed\n")

let f () =
  passed (not (test_without_lock ())) ;
  passed (test_with_lock ())

let _ =
  f ();
