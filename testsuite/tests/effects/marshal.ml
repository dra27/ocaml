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

open Effect
open Effect.Deep

type _ t += E : unit t

let () =
  try_with perform E
  { effc = fun (type a) (e : a t) ->
      Some (fun k ->
          match Marshal.to_string k [] with
          | _ -> assert false
          | exception (Invalid_argument _) -> print_endline "ok"
          ) }
