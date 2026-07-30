(* TEST_BELOW *)

(* "_" is a simple expression (Pexp_hole) *)
let _ = _;;
f _ 0;;
_ 0;;
_.a;;
_ # m;;
(_ : int);;
(_, _);;
Some _;;
lazy _;;
1 + _;;

(* Labelled argument sugar *)
f ~_ ?_ ~_:_ ?_:_;;

(* TEST
 flags = "-dparsetree -dno-locations -stop-after parsing";
 setup-ocamlc.byte-build-env;
 ocamlc.byte;
 check-ocamlc.byte-output;
*)
