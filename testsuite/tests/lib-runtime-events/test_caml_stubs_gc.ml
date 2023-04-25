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

let got_minor = ref false

let () =
    start ();
    let cursor = create_cursor None in
    let runtime_begin domain_id ts phase =
      match phase with
      | EV_MINOR ->
        Gc.full_major ();
        got_minor := true
      | _ -> () in
    let callbacks = Callbacks.create ~runtime_begin ()
    in
    Gc.full_major ();
    ignore(read_poll cursor callbacks (Some 1_000));
    assert(!got_minor)
