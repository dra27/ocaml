(* TEST
   flags = "-drawlambda -dlambda"
   * expect
*)

(* Note: the tests below contain *both* the -drawlambda and
   the -dlambda intermediate representations:
   -drawlambda is the Lambda code generated directly by the
     pattern-matching compiler; it contain "alias" bindings or static
     exits that are unused, and will be removed by simplification, or
     that are used only once, and will be inlined by simplification.
   -dlambda is the Lambda code resulting from simplification.

  The -drawlambda output more closely matches what the
  pattern-compiler produces, and the -dlambda output more closely
  matches the final generated code.

  In this test we decided to show both to notice that some allocations
  are "optimized away" during simplification (see "here flattening is
  an optimization" below).
*)

match (3, 2, 1) with
| (_, 3, _)
| (1, _, _) -> true
| _ -> false
;;
[%%expect{|
(let (*match*/270 = 3 *match*/271 = 2 *match*/272 = 1)
  (catch
    (catch
      (catch (if (!= *match*/271 3) (exit 3) (exit 1)) with (3)
        (if (!= *match*/270 1) (exit 2) (exit 1)))
     with (2) 0)
   with (1) 1))
(let (*match*/270 = 3 *match*/271 = 2 *match*/272 = 1)
  (catch (if (!= *match*/271 3) (if (!= *match*/270 1) 0 (exit 1)) (exit 1))
   with (1) 1))
- : bool = false
|}];;

(* This tests needs to allocate the tuple to bind 'x',
   but this is only done in the branches that use it. *)
match (3, 2, 1) with
| ((_, 3, _) as x)
| ((1, _, _) as x) -> ignore x; true
| _ -> false
;;
[%%expect{|
(let (*match*/275 = 3 *match*/276 = 2 *match*/277 = 1)
  (catch
    (catch
      (catch
        (if (!= *match*/276 3) (exit 6)
          (let (x/279 =a (makeblock 0 *match*/275 *match*/276 *match*/277))
            (exit 4 x/279)))
       with (6)
        (if (!= *match*/275 1) (exit 5)
          (let (x/278 =a (makeblock 0 *match*/275 *match*/276 *match*/277))
            (exit 4 x/278))))
     with (5) 0)
   with (4 x/273) (seq (ignore x/273) 1)))
(let (*match*/275 = 3 *match*/276 = 2 *match*/277 = 1)
  (catch
    (if (!= *match*/276 3)
      (if (!= *match*/275 1) 0
        (exit 4 (makeblock 0 *match*/275 *match*/276 *match*/277)))
      (exit 4 (makeblock 0 *match*/275 *match*/276 *match*/277)))
   with (4 x/273) (seq (ignore x/273) 1)))
- : bool = false
|}];;

(* Regression test for #3780 *)
let _ = fun a b ->
  match a, b with
  | ((true, _) as _g)
  | ((false, _) as _g) -> ()
[%%expect{|
(function a/280[int] b/281 : int 0)
(function a/280[int] b/281 : int 0)
- : bool -> 'a -> unit = <fun>
|}];;

(* More complete tests.

   The test cases below compare the compiler output on alias patterns
   that are outside an or-pattern (handled during half-simplification,
   then flattened) or inside an or-pattern (handled during simplification).

   We used to have a Cannot_flatten exception that would result in fairly
   different code generated in both cases, but now the compilation strategy
   is fairly similar.
*)
let _ = fun a b -> match a, b with
| (true, _) as p -> p
| (false, _) as p -> p
(* outside, trivial *)
[%%expect {|
(function a/284[int] b/285 (let (p/286 =a (makeblock 0 a/284 b/285)) p/286))
(function a/284[int] b/285 (makeblock 0 a/284 b/285))
- : bool -> 'a -> bool * 'a = <fun>
|}]

let _ = fun a b -> match a, b with
| ((true, _) as p)
| ((false, _) as p) -> p
(* inside, trivial *)
[%%expect{|
(function a/288[int] b/289 (let (p/290 =a (makeblock 0 a/288 b/289)) p/290))
(function a/288[int] b/289 (makeblock 0 a/288 b/289))
- : bool -> 'a -> bool * 'a = <fun>
|}];;

let _ = fun a b -> match a, b with
| (true as x, _) as p -> x, p
| (false as x, _) as p -> x, p
(* outside, simple *)
[%%expect {|
(function a/294[int] b/295
  (let (x/296 =a[int] a/294 p/297 =a (makeblock 0 a/294 b/295))
    (makeblock 0 (int,*) x/296 p/297)))
(function a/294[int] b/295
  (makeblock 0 (int,*) a/294 (makeblock 0 a/294 b/295)))
- : bool -> 'a -> bool * (bool * 'a) = <fun>
|}]

let _ = fun a b -> match a, b with
| ((true as x, _) as p)
| ((false as x, _) as p) -> x, p
(* inside, simple *)
[%%expect {|
(function a/300[int] b/301
  (let (x/302 =a[int] a/300 p/303 =a (makeblock 0 a/300 b/301))
    (makeblock 0 (int,*) x/302 p/303)))
(function a/300[int] b/301
  (makeblock 0 (int,*) a/300 (makeblock 0 a/300 b/301)))
- : bool -> 'a -> bool * (bool * 'a) = <fun>
|}]

let _ = fun a b -> match a, b with
| (true as x, _) as p -> x, p
| (false, x) as p -> x, p
(* outside, complex *)
[%%expect{|
(function a/310[int] b/311[int]
  (if a/310
    (let (x/312 =a[int] a/310 p/313 =a (makeblock 0 a/310 b/311))
      (makeblock 0 (int,*) x/312 p/313))
    (let (x/314 =a b/311 p/315 =a (makeblock 0 a/310 b/311))
      (makeblock 0 (int,*) x/314 p/315))))
(function a/310[int] b/311[int]
  (if a/310 (makeblock 0 (int,*) a/310 (makeblock 0 a/310 b/311))
    (makeblock 0 (int,*) b/311 (makeblock 0 a/310 b/311))))
- : bool -> bool -> bool * (bool * bool) = <fun>
|}]

let _ = fun a b -> match a, b with
| ((true as x, _) as p)
| ((false, x) as p)
  -> x, p
(* inside, complex *)
[%%expect{|
(function a/316[int] b/317[int]
  (catch
    (if a/316
      (let (x/324 =a[int] a/316 p/325 =a (makeblock 0 a/316 b/317))
        (exit 10 x/324 p/325))
      (let (x/322 =a b/317 p/323 =a (makeblock 0 a/316 b/317))
        (exit 10 x/322 p/323)))
   with (10 x/318[int] p/319) (makeblock 0 (int,*) x/318 p/319)))
(function a/316[int] b/317[int]
  (catch
    (if a/316 (exit 10 a/316 (makeblock 0 a/316 b/317))
      (exit 10 b/317 (makeblock 0 a/316 b/317)))
   with (10 x/318[int] p/319) (makeblock 0 (int,*) x/318 p/319)))
- : bool -> bool -> bool * (bool * bool) = <fun>
|}]

(* here flattening is an optimisation: the allocation is moved as an
   alias within each branch, and in the first branch it is unused and
   will be removed by simplification, so the final code
   (see the -dlambda output) will not allocate in the first branch. *)
let _ = fun a b -> match a, b with
| (true as x, _) as _p -> x, (true, true)
| (false as x, _) as p -> x, p
(* outside, onecase *)
[%%expect {|
(function a/326[int] b/327[int]
  (if a/326
    (let (x/328 =a[int] a/326 _p/329 =a (makeblock 0 a/326 b/327))
      (makeblock 0 (int,*) x/328 [0: 1 1]))
    (let (x/330 =a[int] a/326 p/331 =a (makeblock 0 a/326 b/327))
      (makeblock 0 (int,*) x/330 p/331))))
(function a/326[int] b/327[int]
  (if a/326 (makeblock 0 (int,*) a/326 [0: 1 1])
    (makeblock 0 (int,*) a/326 (makeblock 0 a/326 b/327))))
- : bool -> bool -> bool * (bool * bool) = <fun>
|}]

let _ = fun a b -> match a, b with
| ((true as x, _) as p)
| ((false as x, _) as p) -> x, p
(* inside, onecase *)
[%%expect{|
(function a/332[int] b/333
  (let (x/334 =a[int] a/332 p/335 =a (makeblock 0 a/332 b/333))
    (makeblock 0 (int,*) x/334 p/335)))
(function a/332[int] b/333
  (makeblock 0 (int,*) a/332 (makeblock 0 a/332 b/333)))
- : bool -> 'a -> bool * (bool * 'a) = <fun>
|}]

type 'a tuplist = Nil | Cons of ('a * 'a tuplist)
[%%expect{|
0
0
type 'a tuplist = Nil | Cons of ('a * 'a tuplist)
|}]

(* another example where we avoid an allocation in the first case *)
let _ =fun a b -> match a, b with
| (true, Cons p) -> p
| (_, _) as p -> p
(* outside, tuplist *)
[%%expect {|
(function a/345[int] b/346
  (catch
    (if a/345 (if b/346 (let (p/347 =a (field_imm 0 b/346)) p/347) (exit 12))
      (exit 12))
   with (12) (let (p/348 =a (makeblock 0 a/345 b/346)) p/348)))
(function a/345[int] b/346
  (catch (if a/345 (if b/346 (field_imm 0 b/346) (exit 12)) (exit 12))
   with (12) (makeblock 0 a/345 b/346)))
- : bool -> bool tuplist -> bool * bool tuplist = <fun>
|}]

let _ = fun a b -> match a, b with
| (true, Cons p)
| ((_, _) as p) -> p
(* inside, tuplist *)
[%%expect{|
(function a/349[int] b/350
  (catch
    (catch
      (if a/349
        (if b/350 (let (p/354 =a (field_imm 0 b/350)) (exit 13 p/354))
          (exit 14))
        (exit 14))
     with (14) (let (p/353 =a (makeblock 0 a/349 b/350)) (exit 13 p/353)))
   with (13 p/351) p/351))
(function a/349[int] b/350
  (catch
    (catch
      (if a/349 (if b/350 (exit 13 (field_imm 0 b/350)) (exit 14)) (exit 14))
     with (14) (exit 13 (makeblock 0 a/349 b/350)))
   with (13 p/351) p/351))
- : bool -> bool tuplist -> bool * bool tuplist = <fun>
|}]
