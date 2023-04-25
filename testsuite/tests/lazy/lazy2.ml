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

open Domain

let () =
  let l = lazy (print_string "Lazy Forced\n") in
  let d = spawn (fun () -> Lazy.force l) in
  join d
