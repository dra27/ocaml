(* TEST
<<<<<<< HEAD
include unix
* skip
reason = "OCaml 5 only"
** hasunix
*** not-windows
**** bytecode
**** native
||||||| parent of 18bd88faf2 (New script language for ocamltest (PR#12185))
include unix
* hasunix
** not-windows
*** bytecode
*** native
=======
 include unix;
 hasunix;
 not-windows;
 {
   bytecode;
 }{
   native;
 }
>>>>>>> 18bd88faf2 (New script language for ocamltest (PR#12185))
*)

(* on Multicore, fork is not allowed is another domain is, and was running. *)
(* this test checks that we can't fork if another domain ran before. *)

let expect_exn ="Unix.fork may not be called while other domains were created"

let () =
  let d = Domain.spawn (fun () -> ()) in
  Domain.join d;
  match Unix.fork () with
  | exception Failure msg ->
     if String.equal msg expect_exn then
       print_endline "OK"
     else
       Printf.printf "failed: expected Failure: %s, got %s\n" expect_exn msg
  | _ -> print_endline "NOK"
