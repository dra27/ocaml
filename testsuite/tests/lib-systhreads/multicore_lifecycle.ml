(* TEST
<<<<<<< HEAD
* skip
reason = "OCaml 5 only"
** hassysthreads
include systhreads
*** bytecode
*** native
||||||| parent of 18bd88faf2 (New script language for ocamltest (PR#12185))
* hassysthreads
include systhreads
** bytecode
** native
=======
 include systhreads;
 hassysthreads;
 {
   bytecode;
 }{
   native;
 }
>>>>>>> 18bd88faf2 (New script language for ocamltest (PR#12185))
*)

let _ =
  let t = ref (Thread.self ()) in
  let d = Domain.spawn begin fun () ->
     let thread_func () = Unix.sleep 5 in
     let tt = Thread.create thread_func () in
     t := tt;
    ()
   end
  in
  Domain.join d;
  Thread.join (!t);
  Domain.join @@ Domain.spawn (fun () -> print_endline "ok")
