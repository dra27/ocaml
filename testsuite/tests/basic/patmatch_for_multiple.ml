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
(let (*match*/272 = 3 *match*/273 = 2 *match*/274 = 1)
||||||| parent of be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
(let (*match*/277 = 3 *match*/278 = 2 *match*/279 = 1)
=======
(let (*match*/274 = 3 *match*/275 = 2 *match*/276 = 1)
>>>>>>> be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
  (catch
    (catch
<<<<<<< HEAD
      (catch (if (!= *match*/273 3) (exit 3) (exit 1)) with (3)
        (if (!= *match*/272 1) (exit 2) (exit 1)))
||||||| parent of be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
      (catch (if (!= *match*/278 3) (exit 3) (exit 1)) with (3)
        (if (!= *match*/277 1) (exit 2) (exit 1)))
=======
      (catch (if (!= *match*/275 3) (exit 3) (exit 1)) with (3)
        (if (!= *match*/274 1) (exit 2) (exit 1)))
>>>>>>> be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
     with (2) 0)
   with (1) 1))
<<<<<<< HEAD
(let (*match*/272 = 3 *match*/273 = 2 *match*/274 = 1)
  (catch (if (!= *match*/273 3) (if (!= *match*/272 1) 0 (exit 1)) (exit 1))
||||||| parent of be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
(let (*match*/277 = 3 *match*/278 = 2 *match*/279 = 1)
  (catch (if (!= *match*/278 3) (if (!= *match*/277 1) 0 (exit 1)) (exit 1))
=======
(let (*match*/274 = 3 *match*/275 = 2 *match*/276 = 1)
  (catch (if (!= *match*/275 3) (if (!= *match*/274 1) 0 (exit 1)) (exit 1))
>>>>>>> be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
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
(let (*match*/277 = 3 *match*/278 = 2 *match*/279 = 1)
||||||| parent of be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
(let (*match*/282 = 3 *match*/283 = 2 *match*/284 = 1)
=======
(let (*match*/279 = 3 *match*/280 = 2 *match*/281 = 1)
>>>>>>> be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
  (catch
    (catch
      (catch
<<<<<<< HEAD
        (if (!= *match*/278 3) (exit 6)
          (let (x/281 =a (makeblock 0 *match*/277 *match*/278 *match*/279))
            (exit 4 x/281)))
||||||| parent of be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
        (if (!= *match*/283 3) (exit 6)
          (let (x/286 =a (makeblock 0 *match*/282 *match*/283 *match*/284))
            (exit 4 x/286)))
=======
        (if (!= *match*/280 3) (exit 6)
          (let (x/283 =a (makeblock 0 *match*/279 *match*/280 *match*/281))
            (exit 4 x/283)))
>>>>>>> be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
       with (6)
<<<<<<< HEAD
        (if (!= *match*/277 1) (exit 5)
          (let (x/280 =a (makeblock 0 *match*/277 *match*/278 *match*/279))
            (exit 4 x/280))))
||||||| parent of be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
        (if (!= *match*/282 1) (exit 5)
          (let (x/285 =a (makeblock 0 *match*/282 *match*/283 *match*/284))
            (exit 4 x/285))))
=======
        (if (!= *match*/279 1) (exit 5)
          (let (x/282 =a (makeblock 0 *match*/279 *match*/280 *match*/281))
            (exit 4 x/282))))
>>>>>>> be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
     with (5) 0)
<<<<<<< HEAD
   with (4 x/275) (seq (ignore x/275) 1)))
(let (*match*/277 = 3 *match*/278 = 2 *match*/279 = 1)
||||||| parent of be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
   with (4 x/280) (seq (ignore x/280) 1)))
(let (*match*/282 = 3 *match*/283 = 2 *match*/284 = 1)
=======
   with (4 x/277) (seq (ignore x/277) 1)))
(let (*match*/279 = 3 *match*/280 = 2 *match*/281 = 1)
>>>>>>> be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
  (catch
<<<<<<< HEAD
    (if (!= *match*/278 3)
      (if (!= *match*/277 1) 0
        (exit 4 (makeblock 0 *match*/277 *match*/278 *match*/279)))
      (exit 4 (makeblock 0 *match*/277 *match*/278 *match*/279)))
   with (4 x/275) (seq (ignore x/275) 1)))
||||||| parent of be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
    (if (!= *match*/283 3)
      (if (!= *match*/282 1) 0
        (exit 4 (makeblock 0 *match*/282 *match*/283 *match*/284)))
      (exit 4 (makeblock 0 *match*/282 *match*/283 *match*/284)))
   with (4 x/280) (seq (ignore x/280) 1)))
=======
    (if (!= *match*/280 3)
      (if (!= *match*/279 1) 0
        (exit 4 (makeblock 0 *match*/279 *match*/280 *match*/281)))
      (exit 4 (makeblock 0 *match*/279 *match*/280 *match*/281)))
   with (4 x/277) (seq (ignore x/277) 1)))
>>>>>>> be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
- : bool = false
|}];;

(* Regression test for #3780 *)
let _ = fun a b ->
  match a, b with
  | ((true, _) as _g)
  | ((false, _) as _g) -> ()
[%%expect{|
<<<<<<< HEAD
(function a/282[int] b/283 : int 0)
(function a/282[int] b/283 : int 0)
||||||| parent of be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
(function a/287[int] b/288 : int 0)
(function a/287[int] b/288 : int 0)
=======
(function a/284[int] b/285 : int 0)
(function a/284[int] b/285 : int 0)
>>>>>>> be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
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
(function a/286[int] b/287 (let (p/288 =a (makeblock 0 a/286 b/287)) p/288))
(function a/286[int] b/287 (makeblock 0 a/286 b/287))
||||||| parent of be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
(function a/291[int] b/292 (let (p/293 =a (makeblock 0 a/291 b/292)) p/293))
(function a/291[int] b/292 (makeblock 0 a/291 b/292))
=======
(function a/288[int] b/289 (let (p/290 =a (makeblock 0 a/288 b/289)) p/290))
(function a/288[int] b/289 (makeblock 0 a/288 b/289))
>>>>>>> be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
- : bool -> 'a -> bool * 'a = <fun>
|}]

let _ = fun a b -> match a, b with
| ((true, _) as p)
| ((false, _) as p) -> p
(* inside, trivial *)
[%%expect{|
<<<<<<< HEAD
(function a/290[int] b/291 (let (p/292 =a (makeblock 0 a/290 b/291)) p/292))
(function a/290[int] b/291 (makeblock 0 a/290 b/291))
||||||| parent of be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
(function a/295[int] b/296 (let (p/297 =a (makeblock 0 a/295 b/296)) p/297))
(function a/295[int] b/296 (makeblock 0 a/295 b/296))
=======
(function a/292[int] b/293 (let (p/294 =a (makeblock 0 a/292 b/293)) p/294))
(function a/292[int] b/293 (makeblock 0 a/292 b/293))
>>>>>>> be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
- : bool -> 'a -> bool * 'a = <fun>
|}];;

let _ = fun a b -> match a, b with
| (true as x, _) as p -> x, p
| (false as x, _) as p -> x, p
(* outside, simple *)
[%%expect {|
<<<<<<< HEAD
(function a/296[int] b/297
  (let (x/298 =a[int] a/296 p/299 =a (makeblock 0 a/296 b/297))
    (makeblock 0 (int,*) x/298 p/299)))
(function a/296[int] b/297
  (makeblock 0 (int,*) a/296 (makeblock 0 a/296 b/297)))
||||||| parent of be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
(function a/301[int] b/302
  (let (x/303 =a[int] a/301 p/304 =a (makeblock 0 a/301 b/302))
    (makeblock 0 (int,*) x/303 p/304)))
(function a/301[int] b/302
  (makeblock 0 (int,*) a/301 (makeblock 0 a/301 b/302)))
=======
(function a/298[int] b/299
  (let (x/300 =a[int] a/298 p/301 =a (makeblock 0 a/298 b/299))
    (makeblock 0 (int,*) x/300 p/301)))
(function a/298[int] b/299
  (makeblock 0 (int,*) a/298 (makeblock 0 a/298 b/299)))
>>>>>>> be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
- : bool -> 'a -> bool * (bool * 'a) = <fun>
|}]

let _ = fun a b -> match a, b with
| ((true as x, _) as p)
| ((false as x, _) as p) -> x, p
(* inside, simple *)
[%%expect {|
<<<<<<< HEAD
(function a/302[int] b/303
  (let (x/304 =a[int] a/302 p/305 =a (makeblock 0 a/302 b/303))
    (makeblock 0 (int,*) x/304 p/305)))
(function a/302[int] b/303
  (makeblock 0 (int,*) a/302 (makeblock 0 a/302 b/303)))
||||||| parent of be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
(function a/307[int] b/308
  (let (x/309 =a[int] a/307 p/310 =a (makeblock 0 a/307 b/308))
    (makeblock 0 (int,*) x/309 p/310)))
(function a/307[int] b/308
  (makeblock 0 (int,*) a/307 (makeblock 0 a/307 b/308)))
=======
(function a/304[int] b/305
  (let (x/306 =a[int] a/304 p/307 =a (makeblock 0 a/304 b/305))
    (makeblock 0 (int,*) x/306 p/307)))
(function a/304[int] b/305
  (makeblock 0 (int,*) a/304 (makeblock 0 a/304 b/305)))
>>>>>>> be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
- : bool -> 'a -> bool * (bool * 'a) = <fun>
|}]

let _ = fun a b -> match a, b with
| (true as x, _) as p -> x, p
| (false, x) as p -> x, p
(* outside, complex *)
[%%expect{|
<<<<<<< HEAD
(function a/312[int] b/313[int]
  (if a/312
    (let (x/314 =a[int] a/312 p/315 =a (makeblock 0 a/312 b/313))
      (makeblock 0 (int,*) x/314 p/315))
    (let (x/316 =a b/313 p/317 =a (makeblock 0 a/312 b/313))
      (makeblock 0 (int,*) x/316 p/317))))
(function a/312[int] b/313[int]
  (if a/312 (makeblock 0 (int,*) a/312 (makeblock 0 a/312 b/313))
    (makeblock 0 (int,*) b/313 (makeblock 0 a/312 b/313))))
||||||| parent of be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
(function a/317[int] b/318[int]
  (if a/317
    (let (x/319 =a[int] a/317 p/320 =a (makeblock 0 a/317 b/318))
      (makeblock 0 (int,*) x/319 p/320))
    (let (x/321 =a b/318 p/322 =a (makeblock 0 a/317 b/318))
      (makeblock 0 (int,*) x/321 p/322))))
(function a/317[int] b/318[int]
  (if a/317 (makeblock 0 (int,*) a/317 (makeblock 0 a/317 b/318))
    (makeblock 0 (int,*) b/318 (makeblock 0 a/317 b/318))))
=======
(function a/314[int] b/315[int]
  (if a/314
    (let (x/316 =a[int] a/314 p/317 =a (makeblock 0 a/314 b/315))
      (makeblock 0 (int,*) x/316 p/317))
    (let (x/318 =a b/315 p/319 =a (makeblock 0 a/314 b/315))
      (makeblock 0 (int,*) x/318 p/319))))
(function a/314[int] b/315[int]
  (if a/314 (makeblock 0 (int,*) a/314 (makeblock 0 a/314 b/315))
    (makeblock 0 (int,*) b/315 (makeblock 0 a/314 b/315))))
>>>>>>> be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
- : bool -> bool -> bool * (bool * bool) = <fun>
|}]

let _ = fun a b -> match a, b with
| ((true as x, _) as p)
| ((false, x) as p)
  -> x, p
(* inside, complex *)
[%%expect{|
<<<<<<< HEAD
(function a/318[int] b/319[int]
||||||| parent of be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
(function a/323[int] b/324[int]
=======
(function a/320[int] b/321[int]
>>>>>>> be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
  (catch
<<<<<<< HEAD
    (if a/318
      (let (x/326 =a[int] a/318 p/327 =a (makeblock 0 a/318 b/319))
        (exit 10 x/326 p/327))
      (let (x/324 =a b/319 p/325 =a (makeblock 0 a/318 b/319))
        (exit 10 x/324 p/325)))
   with (10 x/320[int] p/321) (makeblock 0 (int,*) x/320 p/321)))
(function a/318[int] b/319[int]
||||||| parent of be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
    (if a/323
      (let (x/331 =a[int] a/323 p/332 =a (makeblock 0 a/323 b/324))
        (exit 10 x/331 p/332))
      (let (x/329 =a b/324 p/330 =a (makeblock 0 a/323 b/324))
        (exit 10 x/329 p/330)))
   with (10 x/325[int] p/326) (makeblock 0 (int,*) x/325 p/326)))
(function a/323[int] b/324[int]
=======
    (if a/320
      (let (x/328 =a[int] a/320 p/329 =a (makeblock 0 a/320 b/321))
        (exit 10 x/328 p/329))
      (let (x/326 =a b/321 p/327 =a (makeblock 0 a/320 b/321))
        (exit 10 x/326 p/327)))
   with (10 x/322[int] p/323) (makeblock 0 (int,*) x/322 p/323)))
(function a/320[int] b/321[int]
>>>>>>> be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
  (catch
<<<<<<< HEAD
    (if a/318 (exit 10 a/318 (makeblock 0 a/318 b/319))
      (exit 10 b/319 (makeblock 0 a/318 b/319)))
   with (10 x/320[int] p/321) (makeblock 0 (int,*) x/320 p/321)))
||||||| parent of be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
    (if a/323 (exit 10 a/323 (makeblock 0 a/323 b/324))
      (exit 10 b/324 (makeblock 0 a/323 b/324)))
   with (10 x/325[int] p/326) (makeblock 0 (int,*) x/325 p/326)))
=======
    (if a/320 (exit 10 a/320 (makeblock 0 a/320 b/321))
      (exit 10 b/321 (makeblock 0 a/320 b/321)))
   with (10 x/322[int] p/323) (makeblock 0 (int,*) x/322 p/323)))
>>>>>>> be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
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
(function a/328[int] b/329[int]
  (if a/328
    (let (x/330 =a[int] a/328 _p/331 =a (makeblock 0 a/328 b/329))
      (makeblock 0 (int,*) x/330 [0: 1 1]))
    (let (x/332 =a[int] a/328 p/333 =a (makeblock 0 a/328 b/329))
      (makeblock 0 (int,*) x/332 p/333))))
(function a/328[int] b/329[int]
  (if a/328 (makeblock 0 (int,*) a/328 [0: 1 1])
    (makeblock 0 (int,*) a/328 (makeblock 0 a/328 b/329))))
||||||| parent of be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
(function a/333[int] b/334[int]
  (if a/333
    (let (x/335 =a[int] a/333 _p/336 =a (makeblock 0 a/333 b/334))
      (makeblock 0 (int,*) x/335 [0: 1 1]))
    (let (x/337 =a[int] a/333 p/338 =a (makeblock 0 a/333 b/334))
      (makeblock 0 (int,*) x/337 p/338))))
(function a/333[int] b/334[int]
  (if a/333 (makeblock 0 (int,*) a/333 [0: 1 1])
    (makeblock 0 (int,*) a/333 (makeblock 0 a/333 b/334))))
=======
(function a/330[int] b/331[int]
  (if a/330
    (let (x/332 =a[int] a/330 _p/333 =a (makeblock 0 a/330 b/331))
      (makeblock 0 (int,*) x/332 [0: 1 1]))
    (let (x/334 =a[int] a/330 p/335 =a (makeblock 0 a/330 b/331))
      (makeblock 0 (int,*) x/334 p/335))))
(function a/330[int] b/331[int]
  (if a/330 (makeblock 0 (int,*) a/330 [0: 1 1])
    (makeblock 0 (int,*) a/330 (makeblock 0 a/330 b/331))))
>>>>>>> be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
- : bool -> bool -> bool * (bool * bool) = <fun>
|}]

let _ = fun a b -> match a, b with
| ((true as x, _) as p)
| ((false as x, _) as p) -> x, p
(* inside, onecase *)
[%%expect{|
<<<<<<< HEAD
(function a/334[int] b/335
  (let (x/336 =a[int] a/334 p/337 =a (makeblock 0 a/334 b/335))
    (makeblock 0 (int,*) x/336 p/337)))
(function a/334[int] b/335
  (makeblock 0 (int,*) a/334 (makeblock 0 a/334 b/335)))
||||||| parent of be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
(function a/339[int] b/340
  (let (x/341 =a[int] a/339 p/342 =a (makeblock 0 a/339 b/340))
    (makeblock 0 (int,*) x/341 p/342)))
(function a/339[int] b/340
  (makeblock 0 (int,*) a/339 (makeblock 0 a/339 b/340)))
=======
(function a/336[int] b/337
  (let (x/338 =a[int] a/336 p/339 =a (makeblock 0 a/336 b/337))
    (makeblock 0 (int,*) x/338 p/339)))
(function a/336[int] b/337
  (makeblock 0 (int,*) a/336 (makeblock 0 a/336 b/337)))
>>>>>>> be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
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
(function a/347[int] b/348
||||||| parent of be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
(function a/352[int] b/353
=======
(function a/349[int] b/350
>>>>>>> be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
  (catch
<<<<<<< HEAD
    (if a/347 (if b/348 (let (p/349 =a (field_imm 0 b/348)) p/349) (exit 12))
||||||| parent of be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
    (if a/352 (if b/353 (let (p/354 =a (field_imm 0 b/353)) p/354) (exit 12))
=======
    (if a/349 (if b/350 (let (p/351 =a (field_imm 0 b/350)) p/351) (exit 12))
>>>>>>> be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
      (exit 12))
<<<<<<< HEAD
   with (12) (let (p/350 =a (makeblock 0 a/347 b/348)) p/350)))
(function a/347[int] b/348
  (catch (if a/347 (if b/348 (field_imm 0 b/348) (exit 12)) (exit 12))
   with (12) (makeblock 0 a/347 b/348)))
||||||| parent of be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
   with (12) (let (p/355 =a (makeblock 0 a/352 b/353)) p/355)))
(function a/352[int] b/353
  (catch (if a/352 (if b/353 (field_imm 0 b/353) (exit 12)) (exit 12))
   with (12) (makeblock 0 a/352 b/353)))
=======
   with (12) (let (p/352 =a (makeblock 0 a/349 b/350)) p/352)))
(function a/349[int] b/350
  (catch (if a/349 (if b/350 (field_imm 0 b/350) (exit 12)) (exit 12))
   with (12) (makeblock 0 a/349 b/350)))
>>>>>>> be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
- : bool -> bool tuplist -> bool * bool tuplist = <fun>
|}]

let _ = fun a b -> match a, b with
| (true, Cons p)
| ((_, _) as p) -> p
(* inside, tuplist *)
[%%expect{|
<<<<<<< HEAD
(function a/351[int] b/352
||||||| parent of be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
(function a/356[int] b/357
=======
(function a/353[int] b/354
>>>>>>> be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
  (catch
    (catch
<<<<<<< HEAD
      (if a/351
        (if b/352 (let (p/356 =a (field_imm 0 b/352)) (exit 13 p/356))
||||||| parent of be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
      (if a/356
        (if b/357 (let (p/361 =a (field_imm 0 b/357)) (exit 13 p/361))
=======
      (if a/353
        (if b/354 (let (p/358 =a (field_imm 0 b/354)) (exit 13 p/358))
>>>>>>> be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
          (exit 14))
        (exit 14))
<<<<<<< HEAD
     with (14) (let (p/355 =a (makeblock 0 a/351 b/352)) (exit 13 p/355)))
   with (13 p/353) p/353))
(function a/351[int] b/352
||||||| parent of be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
     with (14) (let (p/360 =a (makeblock 0 a/356 b/357)) (exit 13 p/360)))
   with (13 p/358) p/358))
(function a/356[int] b/357
=======
     with (14) (let (p/357 =a (makeblock 0 a/353 b/354)) (exit 13 p/357)))
   with (13 p/355) p/355))
(function a/353[int] b/354
>>>>>>> be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
  (catch
    (catch
<<<<<<< HEAD
      (if a/351 (if b/352 (exit 13 (field_imm 0 b/352)) (exit 14)) (exit 14))
     with (14) (exit 13 (makeblock 0 a/351 b/352)))
   with (13 p/353) p/353))
||||||| parent of be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
      (if a/356 (if b/357 (exit 13 (field_imm 0 b/357)) (exit 14)) (exit 14))
     with (14) (exit 13 (makeblock 0 a/356 b/357)))
   with (13 p/358) p/358))
=======
      (if a/353 (if b/354 (exit 13 (field_imm 0 b/354)) (exit 14)) (exit 14))
     with (14) (exit 13 (makeblock 0 a/353 b/354)))
   with (13 p/355) p/355))
>>>>>>> be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
- : bool -> bool tuplist -> bool * bool tuplist = <fun>
|}]
