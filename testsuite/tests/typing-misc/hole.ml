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
Line 1, characters 12-13:
1 | let a5 = g ~_
                ^
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
Line 1, characters 12-13:
1 | let a7 = o ?_
                ^
Error: wildcard "_" not expected.
|}]

let a8 = o ?_:_
[%%expect{|
Line 1, characters 14-15:
1 | let a8 = o ?_:_
                  ^
Error: wildcard "_" not expected.
|}]

(* "_" also parses as a module expression (a hole, Pmod_hole) and is
   likewise rejected by the type-checker. *)

module type S = sig end
module F (X : S) = struct end
[%%expect{|
module type S = sig end
module F : (X : S) -> sig end
|}]

module M = _
[%%expect{|
Line 1, characters 11-12:
1 | module M = _
               ^
Error: wildcard "_" not expected.
|}]

module N = F(_)
[%%expect{|
Line 1, characters 13-14:
1 | module N = F(_)
                 ^
Error: wildcard "_" not expected.
|}]

module O = (_ : S)
[%%expect{|
Line 1, characters 12-13:
1 | module O = (_ : S)
                ^
Error: wildcard "_" not expected.
|}]

include _
[%%expect{|
Line 1, characters 8-9:
1 | include _
            ^
Error: wildcard "_" not expected.
|}]

open _
[%%expect{|
Line 1, characters 5-6:
1 | open _
         ^
Error: wildcard "_" not expected.
|}]

module type P = module type of _
[%%expect{|
Line 1, characters 31-32:
1 | module type P = module type of _
                                   ^
Error: wildcard "_" not expected.
|}]

let x = (module _ : S)
[%%expect{|
Line 1, characters 16-17:
1 | let x = (module _ : S)
                    ^
Error: wildcard "_" not expected.
|}]

let y = let module L = _ in ()
[%%expect{|
Line 1, characters 23-24:
1 | let y = let module L = _ in ()
                           ^
Error: wildcard "_" not expected.
|}]
