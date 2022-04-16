(* TEST
<<<<<<< HEAD
* skip
reason = "OCaml 5 only"
** hasunix
include unix
*** bytecode
*** native
||||||| parent of 5fac555874 (Do not link unix library when not necessary (PR#11197))
* hasunix
include unix
** bytecode
** native
=======
>>>>>>> 5fac555874 (Do not link unix library when not necessary (PR#11197))
*)

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
