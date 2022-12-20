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
<<<<<<< HEAD
(let (*match*/270 = 3 *match*/271 = 2 *match*/272 = 1)
||||||| parent of a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
(let (*match*/275 = 3 *match*/276 = 2 *match*/277 = 1)
=======
(let (*match*/276 = 3 *match*/277 = 2 *match*/278 = 1)
>>>>>>> a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
  (catch
    (catch
<<<<<<< HEAD
      (catch (if (!= *match*/271 3) (exit 3) (exit 1)) with (3)
        (if (!= *match*/270 1) (exit 2) (exit 1)))
||||||| parent of a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
      (catch (if (!= *match*/276 3) (exit 3) (exit 1)) with (3)
        (if (!= *match*/275 1) (exit 2) (exit 1)))
=======
      (catch (if (!= *match*/277 3) (exit 3) (exit 1)) with (3)
        (if (!= *match*/276 1) (exit 2) (exit 1)))
>>>>>>> a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
     with (2) 0)
   with (1) 1))
<<<<<<< HEAD
(let (*match*/270 = 3 *match*/271 = 2 *match*/272 = 1)
  (catch (if (!= *match*/271 3) (if (!= *match*/270 1) 0 (exit 1)) (exit 1))
||||||| parent of a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
(let (*match*/275 = 3 *match*/276 = 2 *match*/277 = 1)
  (catch (if (!= *match*/276 3) (if (!= *match*/275 1) 0 (exit 1)) (exit 1))
=======
(let (*match*/276 = 3 *match*/277 = 2 *match*/278 = 1)
  (catch (if (!= *match*/277 3) (if (!= *match*/276 1) 0 (exit 1)) (exit 1))
>>>>>>> a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
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
<<<<<<< HEAD
(let (*match*/275 = 3 *match*/276 = 2 *match*/277 = 1)
||||||| parent of a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
(let (*match*/280 = 3 *match*/281 = 2 *match*/282 = 1)
=======
(let (*match*/281 = 3 *match*/282 = 2 *match*/283 = 1)
>>>>>>> a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
  (catch
    (catch
      (catch
<<<<<<< HEAD
        (if (!= *match*/276 3) (exit 6)
          (let (x/279 =a (makeblock 0 *match*/275 *match*/276 *match*/277))
            (exit 4 x/279)))
||||||| parent of a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
        (if (!= *match*/281 3) (exit 6)
          (let (x/284 =a (makeblock 0 *match*/280 *match*/281 *match*/282))
            (exit 4 x/284)))
=======
        (if (!= *match*/282 3) (exit 6)
          (let (x/285 =a (makeblock 0 *match*/281 *match*/282 *match*/283))
            (exit 4 x/285)))
>>>>>>> a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
       with (6)
<<<<<<< HEAD
        (if (!= *match*/275 1) (exit 5)
          (let (x/278 =a (makeblock 0 *match*/275 *match*/276 *match*/277))
            (exit 4 x/278))))
||||||| parent of a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
        (if (!= *match*/280 1) (exit 5)
          (let (x/283 =a (makeblock 0 *match*/280 *match*/281 *match*/282))
            (exit 4 x/283))))
=======
        (if (!= *match*/281 1) (exit 5)
          (let (x/284 =a (makeblock 0 *match*/281 *match*/282 *match*/283))
            (exit 4 x/284))))
>>>>>>> a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
     with (5) 0)
<<<<<<< HEAD
   with (4 x/273) (seq (ignore x/273) 1)))
(let (*match*/275 = 3 *match*/276 = 2 *match*/277 = 1)
||||||| parent of a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
   with (4 x/278) (seq (ignore x/278) 1)))
(let (*match*/280 = 3 *match*/281 = 2 *match*/282 = 1)
=======
   with (4 x/279) (seq (ignore x/279) 1)))
(let (*match*/281 = 3 *match*/282 = 2 *match*/283 = 1)
>>>>>>> a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
  (catch
<<<<<<< HEAD
    (if (!= *match*/276 3)
      (if (!= *match*/275 1) 0
        (exit 4 (makeblock 0 *match*/275 *match*/276 *match*/277)))
      (exit 4 (makeblock 0 *match*/275 *match*/276 *match*/277)))
   with (4 x/273) (seq (ignore x/273) 1)))
||||||| parent of a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
    (if (!= *match*/281 3)
      (if (!= *match*/280 1) 0
        (exit 4 (makeblock 0 *match*/280 *match*/281 *match*/282)))
      (exit 4 (makeblock 0 *match*/280 *match*/281 *match*/282)))
   with (4 x/278) (seq (ignore x/278) 1)))
=======
    (if (!= *match*/282 3)
      (if (!= *match*/281 1) 0
        (exit 4 (makeblock 0 *match*/281 *match*/282 *match*/283)))
      (exit 4 (makeblock 0 *match*/281 *match*/282 *match*/283)))
   with (4 x/279) (seq (ignore x/279) 1)))
>>>>>>> a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
- : bool = false
|}];;

(* Regression test for #3780 *)
let _ = fun a b ->
  match a, b with
  | ((true, _) as _g)
  | ((false, _) as _g) -> ()
[%%expect{|
<<<<<<< HEAD
(function a/280[int] b/281 : int 0)
(function a/280[int] b/281 : int 0)
||||||| parent of a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
(function a/285[int] b/286 : int 0)
(function a/285[int] b/286 : int 0)
=======
(function a/286[int] b/287 : int 0)
(function a/286[int] b/287 : int 0)
>>>>>>> a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
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
<<<<<<< HEAD
(function a/284[int] b/285 (let (p/286 =a (makeblock 0 a/284 b/285)) p/286))
(function a/284[int] b/285 (makeblock 0 a/284 b/285))
||||||| parent of a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
(function a/289[int] b/290 (let (p/291 =a (makeblock 0 a/289 b/290)) p/291))
(function a/289[int] b/290 (makeblock 0 a/289 b/290))
=======
(function a/290[int] b/291 (let (p/292 =a (makeblock 0 a/290 b/291)) p/292))
(function a/290[int] b/291 (makeblock 0 a/290 b/291))
>>>>>>> a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
- : bool -> 'a -> bool * 'a = <fun>
|}]

let _ = fun a b -> match a, b with
| ((true, _) as p)
| ((false, _) as p) -> p
(* inside, trivial *)
[%%expect{|
<<<<<<< HEAD
(function a/288[int] b/289 (let (p/290 =a (makeblock 0 a/288 b/289)) p/290))
(function a/288[int] b/289 (makeblock 0 a/288 b/289))
||||||| parent of a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
(function a/293[int] b/294 (let (p/295 =a (makeblock 0 a/293 b/294)) p/295))
(function a/293[int] b/294 (makeblock 0 a/293 b/294))
=======
(function a/294[int] b/295 (let (p/296 =a (makeblock 0 a/294 b/295)) p/296))
(function a/294[int] b/295 (makeblock 0 a/294 b/295))
>>>>>>> a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
- : bool -> 'a -> bool * 'a = <fun>
|}];;

let _ = fun a b -> match a, b with
| (true as x, _) as p -> x, p
| (false as x, _) as p -> x, p
(* outside, simple *)
[%%expect {|
<<<<<<< HEAD
(function a/294[int] b/295
  (let (x/296 =a[int] a/294 p/297 =a (makeblock 0 a/294 b/295))
    (makeblock 0 (int,*) x/296 p/297)))
(function a/294[int] b/295
  (makeblock 0 (int,*) a/294 (makeblock 0 a/294 b/295)))
||||||| parent of a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
(function a/299[int] b/300
  (let (x/301 =a[int] a/299 p/302 =a (makeblock 0 a/299 b/300))
    (makeblock 0 (int,*) x/301 p/302)))
(function a/299[int] b/300
  (makeblock 0 (int,*) a/299 (makeblock 0 a/299 b/300)))
=======
(function a/300[int] b/301
  (let (x/302 =a[int] a/300 p/303 =a (makeblock 0 a/300 b/301))
    (makeblock 0 (int,*) x/302 p/303)))
(function a/300[int] b/301
  (makeblock 0 (int,*) a/300 (makeblock 0 a/300 b/301)))
>>>>>>> a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
- : bool -> 'a -> bool * (bool * 'a) = <fun>
|}]

let _ = fun a b -> match a, b with
| ((true as x, _) as p)
| ((false as x, _) as p) -> x, p
(* inside, simple *)
[%%expect {|
<<<<<<< HEAD
(function a/300[int] b/301
  (let (x/302 =a[int] a/300 p/303 =a (makeblock 0 a/300 b/301))
    (makeblock 0 (int,*) x/302 p/303)))
(function a/300[int] b/301
  (makeblock 0 (int,*) a/300 (makeblock 0 a/300 b/301)))
||||||| parent of a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
(function a/305[int] b/306
  (let (x/307 =a[int] a/305 p/308 =a (makeblock 0 a/305 b/306))
    (makeblock 0 (int,*) x/307 p/308)))
(function a/305[int] b/306
  (makeblock 0 (int,*) a/305 (makeblock 0 a/305 b/306)))
=======
(function a/306[int] b/307
  (let (x/308 =a[int] a/306 p/309 =a (makeblock 0 a/306 b/307))
    (makeblock 0 (int,*) x/308 p/309)))
(function a/306[int] b/307
  (makeblock 0 (int,*) a/306 (makeblock 0 a/306 b/307)))
>>>>>>> a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
- : bool -> 'a -> bool * (bool * 'a) = <fun>
|}]

let _ = fun a b -> match a, b with
| (true as x, _) as p -> x, p
| (false, x) as p -> x, p
(* outside, complex *)
[%%expect{|
<<<<<<< HEAD
(function a/310[int] b/311[int]
  (if a/310
    (let (x/312 =a[int] a/310 p/313 =a (makeblock 0 a/310 b/311))
      (makeblock 0 (int,*) x/312 p/313))
    (let (x/314 =a b/311 p/315 =a (makeblock 0 a/310 b/311))
      (makeblock 0 (int,*) x/314 p/315))))
(function a/310[int] b/311[int]
  (if a/310 (makeblock 0 (int,*) a/310 (makeblock 0 a/310 b/311))
    (makeblock 0 (int,*) b/311 (makeblock 0 a/310 b/311))))
||||||| parent of a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
(function a/315[int] b/316[int]
  (if a/315
    (let (x/317 =a[int] a/315 p/318 =a (makeblock 0 a/315 b/316))
      (makeblock 0 (int,*) x/317 p/318))
    (let (x/319 =a b/316 p/320 =a (makeblock 0 a/315 b/316))
      (makeblock 0 (int,*) x/319 p/320))))
(function a/315[int] b/316[int]
  (if a/315 (makeblock 0 (int,*) a/315 (makeblock 0 a/315 b/316))
    (makeblock 0 (int,*) b/316 (makeblock 0 a/315 b/316))))
=======
(function a/316[int] b/317[int]
  (if a/316
    (let (x/318 =a[int] a/316 p/319 =a (makeblock 0 a/316 b/317))
      (makeblock 0 (int,*) x/318 p/319))
    (let (x/320 =a b/317 p/321 =a (makeblock 0 a/316 b/317))
      (makeblock 0 (int,*) x/320 p/321))))
(function a/316[int] b/317[int]
  (if a/316 (makeblock 0 (int,*) a/316 (makeblock 0 a/316 b/317))
    (makeblock 0 (int,*) b/317 (makeblock 0 a/316 b/317))))
>>>>>>> a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
- : bool -> bool -> bool * (bool * bool) = <fun>
|}]

let _ = fun a b -> match a, b with
| ((true as x, _) as p)
| ((false, x) as p)
  -> x, p
(* inside, complex *)
[%%expect{|
<<<<<<< HEAD
(function a/316[int] b/317[int]
||||||| parent of a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
(function a/321[int] b/322[int]
=======
(function a/322[int] b/323[int]
>>>>>>> a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
  (catch
<<<<<<< HEAD
    (if a/316
      (let (x/324 =a[int] a/316 p/325 =a (makeblock 0 a/316 b/317))
        (exit 10 x/324 p/325))
      (let (x/322 =a b/317 p/323 =a (makeblock 0 a/316 b/317))
        (exit 10 x/322 p/323)))
   with (10 x/318[int] p/319) (makeblock 0 (int,*) x/318 p/319)))
(function a/316[int] b/317[int]
||||||| parent of a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
    (if a/321
      (let (x/329 =a[int] a/321 p/330 =a (makeblock 0 a/321 b/322))
        (exit 10 x/329 p/330))
      (let (x/327 =a b/322 p/328 =a (makeblock 0 a/321 b/322))
        (exit 10 x/327 p/328)))
   with (10 x/323[int] p/324) (makeblock 0 (int,*) x/323 p/324)))
(function a/321[int] b/322[int]
=======
    (if a/322
      (let (x/330 =a[int] a/322 p/331 =a (makeblock 0 a/322 b/323))
        (exit 10 x/330 p/331))
      (let (x/328 =a b/323 p/329 =a (makeblock 0 a/322 b/323))
        (exit 10 x/328 p/329)))
   with (10 x/324[int] p/325) (makeblock 0 (int,*) x/324 p/325)))
(function a/322[int] b/323[int]
>>>>>>> a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
  (catch
<<<<<<< HEAD
    (if a/316 (exit 10 a/316 (makeblock 0 a/316 b/317))
      (exit 10 b/317 (makeblock 0 a/316 b/317)))
   with (10 x/318[int] p/319) (makeblock 0 (int,*) x/318 p/319)))
||||||| parent of a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
    (if a/321 (exit 10 a/321 (makeblock 0 a/321 b/322))
      (exit 10 b/322 (makeblock 0 a/321 b/322)))
   with (10 x/323[int] p/324) (makeblock 0 (int,*) x/323 p/324)))
=======
    (if a/322 (exit 10 a/322 (makeblock 0 a/322 b/323))
      (exit 10 b/323 (makeblock 0 a/322 b/323)))
   with (10 x/324[int] p/325) (makeblock 0 (int,*) x/324 p/325)))
>>>>>>> a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
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
<<<<<<< HEAD
(function a/326[int] b/327[int]
  (if a/326
    (let (x/328 =a[int] a/326 _p/329 =a (makeblock 0 a/326 b/327))
      (makeblock 0 (int,*) x/328 [0: 1 1]))
    (let (x/330 =a[int] a/326 p/331 =a (makeblock 0 a/326 b/327))
      (makeblock 0 (int,*) x/330 p/331))))
(function a/326[int] b/327[int]
  (if a/326 (makeblock 0 (int,*) a/326 [0: 1 1])
    (makeblock 0 (int,*) a/326 (makeblock 0 a/326 b/327))))
||||||| parent of a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
(function a/331[int] b/332[int]
  (if a/331
    (let (x/333 =a[int] a/331 _p/334 =a (makeblock 0 a/331 b/332))
      (makeblock 0 (int,*) x/333 [0: 1 1]))
    (let (x/335 =a[int] a/331 p/336 =a (makeblock 0 a/331 b/332))
      (makeblock 0 (int,*) x/335 p/336))))
(function a/331[int] b/332[int]
  (if a/331 (makeblock 0 (int,*) a/331 [0: 1 1])
    (makeblock 0 (int,*) a/331 (makeblock 0 a/331 b/332))))
=======
(function a/332[int] b/333[int]
  (if a/332
    (let (x/334 =a[int] a/332 _p/335 =a (makeblock 0 a/332 b/333))
      (makeblock 0 (int,*) x/334 [0: 1 1]))
    (let (x/336 =a[int] a/332 p/337 =a (makeblock 0 a/332 b/333))
      (makeblock 0 (int,*) x/336 p/337))))
(function a/332[int] b/333[int]
  (if a/332 (makeblock 0 (int,*) a/332 [0: 1 1])
    (makeblock 0 (int,*) a/332 (makeblock 0 a/332 b/333))))
>>>>>>> a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
- : bool -> bool -> bool * (bool * bool) = <fun>
|}]

let _ = fun a b -> match a, b with
| ((true as x, _) as p)
| ((false as x, _) as p) -> x, p
(* inside, onecase *)
[%%expect{|
<<<<<<< HEAD
(function a/332[int] b/333
  (let (x/334 =a[int] a/332 p/335 =a (makeblock 0 a/332 b/333))
    (makeblock 0 (int,*) x/334 p/335)))
(function a/332[int] b/333
  (makeblock 0 (int,*) a/332 (makeblock 0 a/332 b/333)))
||||||| parent of a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
(function a/337[int] b/338
  (let (x/339 =a[int] a/337 p/340 =a (makeblock 0 a/337 b/338))
    (makeblock 0 (int,*) x/339 p/340)))
(function a/337[int] b/338
  (makeblock 0 (int,*) a/337 (makeblock 0 a/337 b/338)))
=======
(function a/338[int] b/339
  (let (x/340 =a[int] a/338 p/341 =a (makeblock 0 a/338 b/339))
    (makeblock 0 (int,*) x/340 p/341)))
(function a/338[int] b/339
  (makeblock 0 (int,*) a/338 (makeblock 0 a/338 b/339)))
>>>>>>> a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
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
<<<<<<< HEAD
(function a/345[int] b/346
||||||| parent of a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
(function a/350[int] b/351
=======
(function a/351[int] b/352
>>>>>>> a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
  (catch
<<<<<<< HEAD
    (if a/345 (if b/346 (let (p/347 =a (field_imm 0 b/346)) p/347) (exit 12))
||||||| parent of a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
    (if a/350 (if b/351 (let (p/352 =a (field_imm 0 b/351)) p/352) (exit 12))
=======
    (if a/351 (if b/352 (let (p/353 =a (field_imm 0 b/352)) p/353) (exit 12))
>>>>>>> a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
      (exit 12))
<<<<<<< HEAD
   with (12) (let (p/348 =a (makeblock 0 a/345 b/346)) p/348)))
(function a/345[int] b/346
  (catch (if a/345 (if b/346 (field_imm 0 b/346) (exit 12)) (exit 12))
   with (12) (makeblock 0 a/345 b/346)))
||||||| parent of a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
   with (12) (let (p/353 =a (makeblock 0 a/350 b/351)) p/353)))
(function a/350[int] b/351
  (catch (if a/350 (if b/351 (field_imm 0 b/351) (exit 12)) (exit 12))
   with (12) (makeblock 0 a/350 b/351)))
=======
   with (12) (let (p/354 =a (makeblock 0 a/351 b/352)) p/354)))
(function a/351[int] b/352
  (catch (if a/351 (if b/352 (field_imm 0 b/352) (exit 12)) (exit 12))
   with (12) (makeblock 0 a/351 b/352)))
>>>>>>> a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
- : bool -> bool tuplist -> bool * bool tuplist = <fun>
|}]

let _ = fun a b -> match a, b with
| (true, Cons p)
| ((_, _) as p) -> p
(* inside, tuplist *)
[%%expect{|
<<<<<<< HEAD
(function a/349[int] b/350
||||||| parent of a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
(function a/354[int] b/355
=======
(function a/355[int] b/356
>>>>>>> a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
  (catch
    (catch
<<<<<<< HEAD
      (if a/349
        (if b/350 (let (p/354 =a (field_imm 0 b/350)) (exit 13 p/354))
||||||| parent of a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
      (if a/354
        (if b/355 (let (p/359 =a (field_imm 0 b/355)) (exit 13 p/359))
=======
      (if a/355
        (if b/356 (let (p/360 =a (field_imm 0 b/356)) (exit 13 p/360))
>>>>>>> a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
          (exit 14))
        (exit 14))
<<<<<<< HEAD
     with (14) (let (p/353 =a (makeblock 0 a/349 b/350)) (exit 13 p/353)))
   with (13 p/351) p/351))
(function a/349[int] b/350
||||||| parent of a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
     with (14) (let (p/358 =a (makeblock 0 a/354 b/355)) (exit 13 p/358)))
   with (13 p/356) p/356))
(function a/354[int] b/355
=======
     with (14) (let (p/359 =a (makeblock 0 a/355 b/356)) (exit 13 p/359)))
   with (13 p/357) p/357))
(function a/355[int] b/356
>>>>>>> a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
  (catch
    (catch
<<<<<<< HEAD
      (if a/349 (if b/350 (exit 13 (field_imm 0 b/350)) (exit 14)) (exit 14))
     with (14) (exit 13 (makeblock 0 a/349 b/350)))
   with (13 p/351) p/351))
||||||| parent of a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
      (if a/354 (if b/355 (exit 13 (field_imm 0 b/355)) (exit 14)) (exit 14))
     with (14) (exit 13 (makeblock 0 a/354 b/355)))
   with (13 p/356) p/356))
=======
      (if a/355 (if b/356 (exit 13 (field_imm 0 b/356)) (exit 14)) (exit 14))
     with (14) (exit 13 (makeblock 0 a/355 b/356)))
   with (13 p/357) p/357))
>>>>>>> a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
- : bool -> bool tuplist -> bool * bool tuplist = <fun>
|}]
