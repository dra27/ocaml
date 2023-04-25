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

open Domain

let test_main_domain () =
  assert ((Domain.self () :> int) = 0);
  assert (Domain.is_main_domain ());
  ()

let id () = ()

let newdom_id () =
  let d = Domain.spawn id in
  let n = Domain.get_id d in
  join d;
  (n :> int)

let test_different_ids () =
  let d1 = Domain.spawn id in
  let d2 = Domain.spawn id in
  assert (get_id d1 <> get_id d2);
  join d1; join d2;
  let d3 = Domain.spawn id in
  assert (get_id d1 <> get_id d3);
  join d3


let () =
  test_main_domain ();
  test_different_ids ();
  print_endline "ok"
