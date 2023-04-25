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
          | F : unit t

let () =
  let ok1 = ref false
  and ok2 = ref true
  and ok3 = ref false in
  let f e r =
    try perform e with
    | Unhandled E -> r := not !r
  in
  f E ok1;
  Printf.printf "%b\n%!" !ok1;

  begin try f F ok2 with Unhandled _ -> () end;
  Printf.printf "%b\n%!" !ok2;

  try_with (f E) ok3 {
    effc = fun (type a) (e : a t) ->
      match e with
      | F -> Some (fun k -> assert false)
      | _ -> None
  };
  Printf.printf "%b\n%!" !ok3
