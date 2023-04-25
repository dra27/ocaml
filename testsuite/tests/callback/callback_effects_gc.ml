(* TEST
<<<<<<< HEAD
   ocamlrunparam += ",s=512"
   * skip
   reason = "OCaml 5 only"
   ** native
||||||| parent of 18bd88faf2 (New script language for ocamltest (PR#12185))
   ocamlrunparam += ",s=512"
   * native
=======
 ocamlrunparam += ",s=512";
 native;
>>>>>>> 18bd88faf2 (New script language for ocamltest (PR#12185))
*)

let count = ref 0

let queue = Queue.create ()

let callback (i:int) (ts: int64) =
  (* add items to queue *)
  incr count;
  Queue.push ( (i, ts, ())) queue

external caml_callback : ('a -> 'b -> 'c) -> 'a -> 'b -> 'c = "caml_callback2_exn"

(* main loop *)
let main () =
  for i = 0 to 10000 do
    caml_callback callback (-1) (Int64.of_int i)
  done

(* a dummy effect handler *)
let () =
  Effect.Deep.match_with main () {
    retc = ignore;
    exnc = raise;
    effc = fun _ -> None
  }
