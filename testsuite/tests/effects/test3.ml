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
exception X

let () =
  Printf.printf "%d\n%!" @@
  match_with (fun () ->
    Printf.printf "in handler. raising X\n%!";
    raise X) ()
    { retc = (fun v -> v);
      exnc = (function
        | X -> 10
        | e -> raise e);
      effc = (fun (type a) (e : a t) ->
        match e with
        | E -> Some (fun k -> 11)
        | e -> None) }
