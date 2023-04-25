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

let _ =
  let key_array =
    Array.init 128 (fun i -> Domain.DLS.new_key (fun _ -> i))
  in
  assert (Domain.DLS.get (key_array.(42)) = 42);
  let d = Domain.spawn (fun _ ->
    assert (Domain.DLS.get (key_array.(63)) = 63))
  in
  Domain.join d;
  print_endline "OK"
