Sys.catch_break false;;
let counter = ref 0
let () =
      Sys.set_signal Sys.sigint (Sys.Signal_handle (fun _ ->
        incr counter;
        Printf.printf "signalled %d times\n%!" !counter;
        if Random.int 10 = 0 then Gc.full_major ()));
      Printf.printf "Waiting for input.\n%!";
      let s = input_line stdin in
      Printf.printf "Got: %s\n%!" s
