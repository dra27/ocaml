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

(* when run with the bytecode debug runtime, this test
   used to trigger a bug where the constant [13]
   remained unpromoted *)

let rec burn l =
  if List.hd l > 14 then ()
  else burn (l @ l |> List.map (fun x -> x + 1))

let () =
  ignore (Domain.spawn (fun () -> burn [13]));
  burn [0];
  Printf.printf "all done\n%!"
