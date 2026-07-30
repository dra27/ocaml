(* TEST_BELOW
(* Blank lines added here to preserve locations. *)
*)

(* Forms involving the wildcard "_" in expression positions which
   remain syntax errors. "_" parses as an expression (Pexp_hole)
   anywhere a simple expression is allowed and is rejected by the
   type-checker: see typing-misc/hole.ml. *)

(* "~_" exists only as a labelled function argument. *)

let x = ~_;;

(* The labelled-argument form "~_:e" requires the unspaced "~_:" label
   token; "f ~_" parses, after which ": 3" is a syntax error. *)

f ~ _ : 3;;

(* TEST
 toplevel;
*)
