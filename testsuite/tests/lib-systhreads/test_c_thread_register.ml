(* TEST
<<<<<<< HEAD
   modules = "test_c_thread_register_cstubs.c"
   * hassysthreads
   include systhreads
   ** not-windows
   *** not-bsd
   **** bytecode
   **** native
||||||| parent of 18bd88faf2 (New script language for ocamltest (PR#12185))
   modules = "test_c_thread_register_cstubs.c"
   * hassysthreads
   include systhreads
   ** not-bsd
   *** bytecode
   *** native
=======
 modules = "test_c_thread_register_cstubs.c";
 include systhreads;
 hassysthreads;
 not-bsd;
 {
   bytecode;
 }{
   native;
 }
>>>>>>> 18bd88faf2 (New script language for ocamltest (PR#12185))
*)

(* spins a external thread from C and register it to the OCaml runtime *)

external spawn_thread : (unit -> unit) -> unit = "spawn_thread"

let passed () = Printf.printf "passed\n"

let _ =
  spawn_thread (passed);
  Thread.delay 0.5
