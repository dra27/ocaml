(* TEST
<<<<<<< HEAD
   ocamlopt_flags += " -O3 "
   * skip
   reason = "OCaml 5 only"
||||||| parent of 18bd88faf2 (New script language for ocamltest (PR#12185))
   ocamlopt_flags += " -O3 "
=======
 ocamlopt_flags += " -O3 ";
>>>>>>> 18bd88faf2 (New script language for ocamltest (PR#12185))
*)

exception E

let main () =
  let l = lazy (raise E) in

  begin try Lazy.force_val l with
  | E -> ()
  end;

  begin try Lazy.force_val l with
  | Lazy.Undefined -> ()
  end;

  let d = Domain.spawn (fun () ->
    begin try Lazy.force_val l with
    | Lazy.Undefined -> ()
    end)
  in
  Domain.join d;
  print_endline "OK"

let _ = main ()
