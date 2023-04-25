(* TEST
<<<<<<< HEAD
* hassysthreads
include systhreads
** bytecode
** native
||||||| parent of 18bd88faf2 (New script language for ocamltest (PR#12185))
* hassysthreads
include systhreads
* skip
reason = "port stat-mem-prof : https://github.com/ocaml/ocaml/pull/8634"
** bytecode
** native
=======
 {
   include systhreads;
   hassysthreads;
 }{
   reason = "port stat-mem-prof : https://github.com/ocaml/ocaml/pull/8634";
   skip;
   {
     bytecode;
   }{
     native;
   }
 }
>>>>>>> 18bd88faf2 (New script language for ocamltest (PR#12185))
*)

let _ =
  let main_thread = Thread.id (Thread.self ()) in
  Gc.Memprof.(start ~callstack_size:10 ~sampling_rate:1.
                { null_tracker with alloc_minor = fun _ ->
                      if Thread.id (Thread.self ()) <> main_thread then
                        raise Thread.Exit;
                      None });
  let t = Thread.create (fun () ->
      ignore (Sys.opaque_identity (ref 1));
      assert false) ()
  in
  Thread.join t;
  Gc.Memprof.stop ()

[@@@ocaml.alert "-deprecated"]

let _ =
  Gc.Memprof.(start ~callstack_size:10 ~sampling_rate:1.
    { null_tracker with alloc_minor = fun _ -> Thread.exit (); None });
  ignore (Sys.opaque_identity (ref 1));
  assert false
