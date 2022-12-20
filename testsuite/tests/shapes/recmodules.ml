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
 "A"[module] -> A/298<.11>;
 "B"[module] -> B/299<.12>;
||||||| parent of a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
 "A"[module] -> A/303<.11>;
 "B"[module] -> B/304<.12>;
=======
 "A"[module] -> A/304<.11>;
 "B"[module] -> B/305<.12>;
>>>>>>> a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
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
      CU Stdlib . "Set"[module] . "Make"[module](A/320<.19>) .
||||||| parent of a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
      CU Stdlib . "Set"[module] . "Make"[module](A/325<.19>) .
=======
      CU Stdlib . "Set"[module] . "Make"[module](A/326<.19>) .
>>>>>>> a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
      "compare"[value];
    "elt"[type] ->
<<<<<<< HEAD
      CU Stdlib . "Set"[module] . "Make"[module](A/320<.19>) . "elt"[type];
||||||| parent of a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
      CU Stdlib . "Set"[module] . "Make"[module](A/325<.19>) . "elt"[type];
=======
      CU Stdlib . "Set"[module] . "Make"[module](A/326<.19>) . "elt"[type];
>>>>>>> a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
    "t"[type] ->
<<<<<<< HEAD
      CU Stdlib . "Set"[module] . "Make"[module](A/320<.19>) . "t"[type];
||||||| parent of a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
      CU Stdlib . "Set"[module] . "Make"[module](A/325<.19>) . "t"[type];
=======
      CU Stdlib . "Set"[module] . "Make"[module](A/326<.19>) . "t"[type];
>>>>>>> a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
    };
 }
module rec A :
  sig
    type t = Leaf of string | Node of ASet.t
    val compare : t -> t -> int
  end
and ASet : sig type t type elt = A.t val compare : t -> t -> int end
|}]
