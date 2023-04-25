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
exception Done

let handle_partial f =
  try_with f ()
  { effc = fun (type a) (e : a t) ->
      match e with
      | E -> Some (fun k -> assert false)
      | _ -> None }

let f () x = perform E

let () =
  match_with (handle_partial f) ()
  { retc = (fun x -> assert false);
    exnc = (function
      | Done -> print_string "ok\n"
      | e -> raise e);
    effc = fun (type a) (e : a t) ->
      match e with
      | E -> Some (fun (k : (a, _) continuation) -> discontinue k Done)
      | _ -> None }
