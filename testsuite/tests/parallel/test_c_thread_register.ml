(* TEST
<<<<<<< HEAD
   * skip
   reason = "OCaml 5 only"
   modules = "test_c_thread_register_cstubs.c"
   ** hassysthreads
   include systhreads
   *** bytecode
   *** native
||||||| parent of 18bd88faf2 (New script language for ocamltest (PR#12185))
   modules = "test_c_thread_register_cstubs.c"
   * hassysthreads
   include systhreads
   ** bytecode
   ** native
=======
 modules = "test_c_thread_register_cstubs.c";
 include systhreads;
 hassysthreads;
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
  let d =
    Domain.spawn begin fun () ->
      spawn_thread passed;
      Thread.delay 0.5
    end
  in
  let t = Thread.create (fun () -> Thread.delay 1.0) () in
  Thread.join t;
  Domain.join d
