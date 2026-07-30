(* TEST
 expect;
*)

(* "_" parses as an expression (a "hole", Pexp_hole) anywhere a simple
   expression is allowed, but is rejected by the type-checker: holes
   are intended to be eliminated by a ppx rewriter. *)

type r = { a : int }
let f (x : int) = x
let g ~_:x = x
let o ?_:(x = 0) () = x
[%%expect{|
type r = { a : int; }
val f : int -> int = <fun>
val g : _:'a -> 'a = <fun>
val o : ?_:int -> unit -> int = <fun>
|}]

(* "~_:" and "?_:" lex as labels named "_", so these do not involve
   holes at all. *)

let ok = g ~_:3
[%%expect{|
val ok : int = 3
|}]

let ok = o ?_:(Some 5) ()
[%%expect{|
val ok : int = 5
|}]

(* Holes where a general expression can start. *)

let x = _
[%%expect{|
Line 1, characters 8-9:
1 | let x = _
            ^
Error: wildcard "_" not expected.
|}]

let p = (_, 0)
[%%expect{|
Line 1, characters 9-10:
1 | let p = (_, 0)
             ^
Error: wildcard "_" not expected.
|}]

let r1 = { a = _ }
[%%expect{|
Line 1, characters 15-16:
1 | let r1 = { a = _ }
                   ^
Error: wildcard "_" not expected.
|}]

let n = 1 + _
[%%expect{|
Line 1, characters 12-13:
1 | let n = 1 + _
                ^
Error: wildcard "_" not expected.
|}]

let c = if _ then 0 else 1
[%%expect{|
Line 1, characters 11-12:
1 | let c = if _ then 0 else 1
               ^
Error: wildcard "_" not expected.
|}]

let t = (_ : int)
[%%expect{|
Line 1, characters 9-10:
1 | let t = (_ : int)
             ^
Error: wildcard "_" not expected.
|}]

let fn = fun () -> _
[%%expect{|
Line 1, characters 19-20:
1 | let fn = fun () -> _
                       ^
Error: wildcard "_" not expected.
|}]

let ap = _ 0
[%%expect{|
Line 1, characters 9-10:
1 | let ap = _ 0
             ^
Error: wildcard "_" not expected.
|}]

let fd = _.a
[%%expect{|
Line 1, characters 9-10:
1 | let fd = _.a
             ^
Error: wildcard "_" not expected.
|}]

(* Holes in function-argument positions. *)

let a1 = f _
[%%expect{|
Line 1, characters 11-12:
1 | let a1 = f _
               ^
Error: wildcard "_" not expected.
|}]

let a2 = Some _
[%%expect{|
Line 1, characters 14-15:
1 | let a2 = Some _
                  ^
Error: wildcard "_" not expected.
|}]

let a3 = lazy _
[%%expect{|
Line 1, characters 14-15:
1 | let a3 = lazy _
                  ^
Error: wildcard "_" not expected.
|}]

let a4 = f ~x:_
[%%expect{|
Line 1, characters 14-15:
1 | let a4 = f ~x:_
                  ^
Error: The function applied to this argument has type int -> int
This argument cannot be applied with label "~x"
|}]

let a5 = g ~_
[%%expect{|
Line 1, characters 11-13:
1 | let a5 = g ~_
               ^^
Error: wildcard "_" not expected.
|}]

let a6 = g ~_:_
[%%expect{|
Line 1, characters 14-15:
1 | let a6 = g ~_:_
                  ^
Error: wildcard "_" not expected.
|}]

let a7 = o ?_
[%%expect{|
Line 1, characters 11-13:
1 | let a7 = o ?_
               ^^
Error: wildcard "_" not expected.
|}]

let a8 = o ?_:_
[%%expect{|
Line 1, characters 14-15:
1 | let a8 = o ?_:_
                  ^
Error: wildcard "_" not expected.
|}]
