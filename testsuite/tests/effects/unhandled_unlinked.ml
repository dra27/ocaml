(* TEST
<<<<<<< HEAD
     exit_status= "2"
     * skip
     reason = "OCaml 5 only"
||||||| parent of 18bd88faf2 (New script language for ocamltest (PR#12185))
     exit_status= "2"
=======
 exit_status = "2";
>>>>>>> 18bd88faf2 (New script language for ocamltest (PR#12185))
*)

open Effect
type _ t += E : unit t
let _ = perform E
