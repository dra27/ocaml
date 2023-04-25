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

let rec even n =
  if n = 0 then true
  else try_with odd (n-1)
       { effc = fun (type a) (e : a t) ->
           match e with
           | E -> Some (fun k -> assert false)
           | _ -> None }
and odd n =
  if n = 0 then false
  else even (n-1)

let _ =
  let n = 100_000 in
  Printf.printf "even %d is %B\n%!" n (even n)
