(* TEST
<<<<<<< HEAD
* skip
reason = "OCaml 5 only"
** hasunix
include unix
*** bytecode
*** native
||||||| parent of 18bd88faf2 (New script language for ocamltest (PR#12185))
* hasunix
include unix
** bytecode
** native
=======
 include unix;
 hasunix;
 {
   bytecode;
 }{
   native;
 }
>>>>>>> 18bd88faf2 (New script language for ocamltest (PR#12185))
*)

let continue = Atomic.make true

let rec loop () =
  if Atomic.get continue then loop ()

let rec repeat f = function
  | 0 -> ()
  | n -> f (); repeat f (n - 1)

let f () =
  Atomic.set continue true;
  let d = Domain.spawn loop in
  Unix.sleepf 5E-2;
  Gc.full_major();
  Atomic.set continue false;
  Domain.join d

let _ =
  repeat f 10 ;
  print_endline "OK"
