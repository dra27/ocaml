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


let _ =
  (* start a dummy domain and shut it down to cause a domain reuse *)
  let d = Domain.spawn (fun _ -> ()) in
  Domain.join d;
  let _d = Domain.spawn (fun _ ->
    Unix.sleep 10;
    print_endline "Should not reach here!") in
  Gc.full_major ();
  print_endline "OK"
