(* TEST
   * skip
   reason = "OCaml 5 only"
 *)

open Effect
open Effect.Deep

type _ t += E : unit t

let () =
  Printf.printf "%d\n%!" @@
    try_with (fun x -> x) 10
    { effc = (fun (type a) (e : a t) ->
        match e with
        | E -> Some (fun k -> 11)
        | e -> None) }
