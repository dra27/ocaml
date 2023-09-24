(* TEST
<<<<<<< HEAD
include runtime_events
* skip
reason = "OCaml 5 only"
||||||| parent of 18bd88faf2 (New script language for ocamltest (PR#12185))
include runtime_events
=======
 include runtime_events;
>>>>>>> 18bd88faf2 (New script language for ocamltest (PR#12185))
*)
open Runtime_events

let () =
    start ();
    let cursor = create_cursor None in
    let empty_callbacks = Callbacks.create () in
    let runtime_begin domain_id ts phase =
      match phase with
      | EV_MINOR ->
        ignore(read_poll cursor empty_callbacks None)
      | _ -> () in
    let callbacks = Callbacks.create ~runtime_begin ()
    in
    Gc.full_major ();
    try begin
      ignore(read_poll cursor callbacks None);
      Printf.printf "Exception ignored"
    end with
      Failure(_) ->
        (* Got an exception because we tried to reenter *)
        Printf.printf "OK"
