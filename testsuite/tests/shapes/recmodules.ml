(* TEST
   flags = "-dshape"
   * expect
*)

(**********)
(* Simple *)
(**********)

module rec A : sig
   type t = Leaf of B.t
 end = struct
   type t = Leaf of B.t
 end
 and B
   : sig type t = int end
   = struct type t = int end
[%%expect{|
{
 "A"[module] -> {
                 "t"[type] -> <.8>;
                 };
 "B"[module] -> {
                 "t"[type] -> <.10>;
                 };
 }
module rec A : sig type t = Leaf of B.t end
and B : sig type t = int end
|}]

(*****************)
(* Intf only ... *)
(*****************)

(* reduce is going to die on this. *)

module rec A : sig
   type t = Leaf of B.t
 end = A

and B : sig
  type t = int
end = B
[%%expect{|
{
<<<<<<< HEAD
 "A"[module] -> A/300<.11>;
 "B"[module] -> B/301<.12>;
||||||| parent of be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
 "A"[module] -> A/305<.11>;
 "B"[module] -> B/306<.12>;
=======
 "A"[module] -> A/302<.11>;
 "B"[module] -> B/303<.12>;
>>>>>>> be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
 }
module rec A : sig type t = Leaf of B.t end
and B : sig type t = int end
|}]

(***************************)
(* Example from the manual *)
(***************************)

 module rec A : sig
   type t = Leaf of string | Node of ASet.t
   val compare: t -> t -> int
 end = struct
   type t = Leaf of string | Node of ASet.t
   let compare t1 t2 =
     match (t1, t2) with
     | (Leaf s1, Leaf s2) -> Stdlib.compare s1 s2
     | (Leaf _, Node _) -> 1
     | (Node _, Leaf _) -> -1
     | (Node n1, Node n2) -> ASet.compare n1 n2
 end

(* we restrict the sig to limit the bloat in the expected output. *)
and ASet : sig
  type t
  type elt = A.t
  val compare : t -> t -> int
end = Set.Make(A)
[%%expect{|
{
 "A"[module] -> {
                 "compare"[value] -> <.38>;
                 "t"[type] -> <.35>;
                 };
 "ASet"[module] ->
     {
      "compare"[value] ->
<<<<<<< HEAD
          CU Stdlib . "Set"[module] . "Make"[module](A/322<.19>) .
||||||| parent of be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
          CU Stdlib . "Set"[module] . "Make"[module](A/327<.19>) .
=======
          CU Stdlib . "Set"[module] . "Make"[module](A/324<.19>) .
>>>>>>> be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
          "compare"[value];
      "elt"[type] ->
<<<<<<< HEAD
          CU Stdlib . "Set"[module] . "Make"[module](A/322<.19>) .
||||||| parent of be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
          CU Stdlib . "Set"[module] . "Make"[module](A/327<.19>) .
=======
          CU Stdlib . "Set"[module] . "Make"[module](A/324<.19>) .
>>>>>>> be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
          "elt"[type];
      "t"[type] ->
<<<<<<< HEAD
          CU Stdlib . "Set"[module] . "Make"[module](A/322<.19>) . "t"[type];
||||||| parent of be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
          CU Stdlib . "Set"[module] . "Make"[module](A/327<.19>) . "t"[type];
=======
          CU Stdlib . "Set"[module] . "Make"[module](A/324<.19>) . "t"[type];
>>>>>>> be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
      };
 }
module rec A :
  sig
    type t = Leaf of string | Node of ASet.t
    val compare : t -> t -> int
  end
and ASet : sig type t type elt = A.t val compare : t -> t -> int end
|}]
