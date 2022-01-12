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
(let (*match*/274 = 3 *match*/275 = 2 *match*/276 = 1)
||||||| parent of 749037f069 (Remove deprecated functions (PR#10867))
(let (*match*/279 = 3 *match*/280 = 2 *match*/281 = 1)
=======
(let (*match*/277 = 3 *match*/278 = 2 *match*/279 = 1)
>>>>>>> 749037f069 (Remove deprecated functions (PR#10867))
  (catch
    (catch
<<<<<<< HEAD
      (catch (if (!= *match*/275 3) (exit 3) (exit 1)) with (3)
        (if (!= *match*/274 1) (exit 2) (exit 1)))
||||||| parent of 749037f069 (Remove deprecated functions (PR#10867))
      (catch (if (!= *match*/280 3) (exit 3) (exit 1)) with (3)
        (if (!= *match*/279 1) (exit 2) (exit 1)))
=======
      (catch (if (!= *match*/278 3) (exit 3) (exit 1)) with (3)
        (if (!= *match*/277 1) (exit 2) (exit 1)))
>>>>>>> 749037f069 (Remove deprecated functions (PR#10867))
     with (2) 0)
   with (1) 1))
<<<<<<< HEAD
(let (*match*/274 = 3 *match*/275 = 2 *match*/276 = 1)
  (catch (if (!= *match*/275 3) (if (!= *match*/274 1) 0 (exit 1)) (exit 1))
||||||| parent of 749037f069 (Remove deprecated functions (PR#10867))
(let (*match*/279 = 3 *match*/280 = 2 *match*/281 = 1)
  (catch (if (!= *match*/280 3) (if (!= *match*/279 1) 0 (exit 1)) (exit 1))
=======
(let (*match*/277 = 3 *match*/278 = 2 *match*/279 = 1)
  (catch (if (!= *match*/278 3) (if (!= *match*/277 1) 0 (exit 1)) (exit 1))
>>>>>>> 749037f069 (Remove deprecated functions (PR#10867))
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
(let (*match*/279 = 3 *match*/280 = 2 *match*/281 = 1)
||||||| parent of 749037f069 (Remove deprecated functions (PR#10867))
(let (*match*/284 = 3 *match*/285 = 2 *match*/286 = 1)
=======
(let (*match*/282 = 3 *match*/283 = 2 *match*/284 = 1)
>>>>>>> 749037f069 (Remove deprecated functions (PR#10867))
  (catch
    (catch
      (catch
<<<<<<< HEAD
        (if (!= *match*/280 3) (exit 6)
          (let (x/283 =a (makeblock 0 *match*/279 *match*/280 *match*/281))
            (exit 4 x/283)))
||||||| parent of 749037f069 (Remove deprecated functions (PR#10867))
        (if (!= *match*/285 3) (exit 6)
          (let (x/288 =a (makeblock 0 *match*/284 *match*/285 *match*/286))
            (exit 4 x/288)))
=======
        (if (!= *match*/283 3) (exit 6)
          (let (x/286 =a (makeblock 0 *match*/282 *match*/283 *match*/284))
            (exit 4 x/286)))
>>>>>>> 749037f069 (Remove deprecated functions (PR#10867))
       with (6)
<<<<<<< HEAD
        (if (!= *match*/279 1) (exit 5)
          (let (x/282 =a (makeblock 0 *match*/279 *match*/280 *match*/281))
            (exit 4 x/282))))
||||||| parent of 749037f069 (Remove deprecated functions (PR#10867))
        (if (!= *match*/284 1) (exit 5)
          (let (x/287 =a (makeblock 0 *match*/284 *match*/285 *match*/286))
            (exit 4 x/287))))
=======
        (if (!= *match*/282 1) (exit 5)
          (let (x/285 =a (makeblock 0 *match*/282 *match*/283 *match*/284))
            (exit 4 x/285))))
>>>>>>> 749037f069 (Remove deprecated functions (PR#10867))
     with (5) 0)
<<<<<<< HEAD
   with (4 x/277) (seq (ignore x/277) 1)))
(let (*match*/279 = 3 *match*/280 = 2 *match*/281 = 1)
||||||| parent of 749037f069 (Remove deprecated functions (PR#10867))
   with (4 x/282) (seq (ignore x/282) 1)))
(let (*match*/284 = 3 *match*/285 = 2 *match*/286 = 1)
=======
   with (4 x/280) (seq (ignore x/280) 1)))
(let (*match*/282 = 3 *match*/283 = 2 *match*/284 = 1)
>>>>>>> 749037f069 (Remove deprecated functions (PR#10867))
  (catch
<<<<<<< HEAD
    (if (!= *match*/280 3)
      (if (!= *match*/279 1) 0
        (exit 4 (makeblock 0 *match*/279 *match*/280 *match*/281)))
      (exit 4 (makeblock 0 *match*/279 *match*/280 *match*/281)))
   with (4 x/277) (seq (ignore x/277) 1)))
||||||| parent of 749037f069 (Remove deprecated functions (PR#10867))
    (if (!= *match*/285 3)
      (if (!= *match*/284 1) 0
        (exit 4 (makeblock 0 *match*/284 *match*/285 *match*/286)))
      (exit 4 (makeblock 0 *match*/284 *match*/285 *match*/286)))
   with (4 x/282) (seq (ignore x/282) 1)))
=======
    (if (!= *match*/283 3)
      (if (!= *match*/282 1) 0
        (exit 4 (makeblock 0 *match*/282 *match*/283 *match*/284)))
      (exit 4 (makeblock 0 *match*/282 *match*/283 *match*/284)))
   with (4 x/280) (seq (ignore x/280) 1)))
>>>>>>> 749037f069 (Remove deprecated functions (PR#10867))
- : bool = false
|}];;

(* Regression test for #3780 *)
let _ = fun a b ->
  match a, b with
  | ((true, _) as _g)
  | ((false, _) as _g) -> ()
[%%expect{|
<<<<<<< HEAD
(function a/284[int] b/285 : int 0)
(function a/284[int] b/285 : int 0)
||||||| parent of 749037f069 (Remove deprecated functions (PR#10867))
(function a/289[int] b/290 : int 0)
(function a/289[int] b/290 : int 0)
=======
(function a/287[int] b/288 : int 0)
(function a/287[int] b/288 : int 0)
>>>>>>> 749037f069 (Remove deprecated functions (PR#10867))
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
(function a/288[int] b/289 (let (p/290 =a (makeblock 0 a/288 b/289)) p/290))
(function a/288[int] b/289 (makeblock 0 a/288 b/289))
||||||| parent of 749037f069 (Remove deprecated functions (PR#10867))
(function a/293[int] b/294 (let (p/295 =a (makeblock 0 a/293 b/294)) p/295))
(function a/293[int] b/294 (makeblock 0 a/293 b/294))
=======
(function a/291[int] b/292 (let (p/293 =a (makeblock 0 a/291 b/292)) p/293))
(function a/291[int] b/292 (makeblock 0 a/291 b/292))
>>>>>>> 749037f069 (Remove deprecated functions (PR#10867))
- : bool -> 'a -> bool * 'a = <fun>
|}]

let _ = fun a b -> match a, b with
| ((true, _) as p)
| ((false, _) as p) -> p
(* inside, trivial *)
[%%expect{|
<<<<<<< HEAD
(function a/292[int] b/293 (let (p/294 =a (makeblock 0 a/292 b/293)) p/294))
(function a/292[int] b/293 (makeblock 0 a/292 b/293))
||||||| parent of 749037f069 (Remove deprecated functions (PR#10867))
(function a/297[int] b/298 (let (p/299 =a (makeblock 0 a/297 b/298)) p/299))
(function a/297[int] b/298 (makeblock 0 a/297 b/298))
=======
(function a/295[int] b/296 (let (p/297 =a (makeblock 0 a/295 b/296)) p/297))
(function a/295[int] b/296 (makeblock 0 a/295 b/296))
>>>>>>> 749037f069 (Remove deprecated functions (PR#10867))
- : bool -> 'a -> bool * 'a = <fun>
|}];;

let _ = fun a b -> match a, b with
| (true as x, _) as p -> x, p
| (false as x, _) as p -> x, p
(* outside, simple *)
[%%expect {|
<<<<<<< HEAD
(function a/298[int] b/299
  (let (x/300 =a[int] a/298 p/301 =a (makeblock 0 a/298 b/299))
    (makeblock 0 (int,*) x/300 p/301)))
(function a/298[int] b/299
  (makeblock 0 (int,*) a/298 (makeblock 0 a/298 b/299)))
||||||| parent of 749037f069 (Remove deprecated functions (PR#10867))
(function a/303[int] b/304
  (let (x/305 =a[int] a/303 p/306 =a (makeblock 0 a/303 b/304))
    (makeblock 0 (int,*) x/305 p/306)))
(function a/303[int] b/304
  (makeblock 0 (int,*) a/303 (makeblock 0 a/303 b/304)))
=======
(function a/301[int] b/302
  (let (x/303 =a[int] a/301 p/304 =a (makeblock 0 a/301 b/302))
    (makeblock 0 (int,*) x/303 p/304)))
(function a/301[int] b/302
  (makeblock 0 (int,*) a/301 (makeblock 0 a/301 b/302)))
>>>>>>> 749037f069 (Remove deprecated functions (PR#10867))
- : bool -> 'a -> bool * (bool * 'a) = <fun>
|}]

let _ = fun a b -> match a, b with
| ((true as x, _) as p)
| ((false as x, _) as p) -> x, p
(* inside, simple *)
[%%expect {|
<<<<<<< HEAD
(function a/304[int] b/305
  (let (x/306 =a[int] a/304 p/307 =a (makeblock 0 a/304 b/305))
    (makeblock 0 (int,*) x/306 p/307)))
(function a/304[int] b/305
  (makeblock 0 (int,*) a/304 (makeblock 0 a/304 b/305)))
||||||| parent of 749037f069 (Remove deprecated functions (PR#10867))
(function a/309[int] b/310
  (let (x/311 =a[int] a/309 p/312 =a (makeblock 0 a/309 b/310))
    (makeblock 0 (int,*) x/311 p/312)))
(function a/309[int] b/310
  (makeblock 0 (int,*) a/309 (makeblock 0 a/309 b/310)))
=======
(function a/307[int] b/308
  (let (x/309 =a[int] a/307 p/310 =a (makeblock 0 a/307 b/308))
    (makeblock 0 (int,*) x/309 p/310)))
(function a/307[int] b/308
  (makeblock 0 (int,*) a/307 (makeblock 0 a/307 b/308)))
>>>>>>> 749037f069 (Remove deprecated functions (PR#10867))
- : bool -> 'a -> bool * (bool * 'a) = <fun>
|}]

let _ = fun a b -> match a, b with
| (true as x, _) as p -> x, p
| (false, x) as p -> x, p
(* outside, complex *)
[%%expect{|
<<<<<<< HEAD
(function a/314[int] b/315[int]
  (if a/314
    (let (x/316 =a[int] a/314 p/317 =a (makeblock 0 a/314 b/315))
      (makeblock 0 (int,*) x/316 p/317))
    (let (x/318 =a b/315 p/319 =a (makeblock 0 a/314 b/315))
      (makeblock 0 (int,*) x/318 p/319))))
(function a/314[int] b/315[int]
  (if a/314 (makeblock 0 (int,*) a/314 (makeblock 0 a/314 b/315))
    (makeblock 0 (int,*) b/315 (makeblock 0 a/314 b/315))))
||||||| parent of 749037f069 (Remove deprecated functions (PR#10867))
(function a/319[int] b/320[int]
  (if a/319
    (let (x/321 =a[int] a/319 p/322 =a (makeblock 0 a/319 b/320))
      (makeblock 0 (int,*) x/321 p/322))
    (let (x/323 =a b/320 p/324 =a (makeblock 0 a/319 b/320))
      (makeblock 0 (int,*) x/323 p/324))))
(function a/319[int] b/320[int]
  (if a/319 (makeblock 0 (int,*) a/319 (makeblock 0 a/319 b/320))
    (makeblock 0 (int,*) b/320 (makeblock 0 a/319 b/320))))
=======
(function a/317[int] b/318[int]
  (if a/317
    (let (x/319 =a[int] a/317 p/320 =a (makeblock 0 a/317 b/318))
      (makeblock 0 (int,*) x/319 p/320))
    (let (x/321 =a b/318 p/322 =a (makeblock 0 a/317 b/318))
      (makeblock 0 (int,*) x/321 p/322))))
(function a/317[int] b/318[int]
  (if a/317 (makeblock 0 (int,*) a/317 (makeblock 0 a/317 b/318))
    (makeblock 0 (int,*) b/318 (makeblock 0 a/317 b/318))))
>>>>>>> 749037f069 (Remove deprecated functions (PR#10867))
- : bool -> bool -> bool * (bool * bool) = <fun>
|}]

let _ = fun a b -> match a, b with
| ((true as x, _) as p)
| ((false, x) as p)
  -> x, p
(* inside, complex *)
[%%expect{|
<<<<<<< HEAD
(function a/320[int] b/321[int]
||||||| parent of 749037f069 (Remove deprecated functions (PR#10867))
(function a/325[int] b/326[int]
=======
(function a/323[int] b/324[int]
>>>>>>> 749037f069 (Remove deprecated functions (PR#10867))
  (catch
<<<<<<< HEAD
    (if a/320
      (let (x/328 =a[int] a/320 p/329 =a (makeblock 0 a/320 b/321))
        (exit 10 x/328 p/329))
      (let (x/326 =a b/321 p/327 =a (makeblock 0 a/320 b/321))
        (exit 10 x/326 p/327)))
   with (10 x/322[int] p/323) (makeblock 0 (int,*) x/322 p/323)))
(function a/320[int] b/321[int]
||||||| parent of 749037f069 (Remove deprecated functions (PR#10867))
    (if a/325
      (let (x/333 =a[int] a/325 p/334 =a (makeblock 0 a/325 b/326))
        (exit 10 x/333 p/334))
      (let (x/331 =a b/326 p/332 =a (makeblock 0 a/325 b/326))
        (exit 10 x/331 p/332)))
   with (10 x/327[int] p/328) (makeblock 0 (int,*) x/327 p/328)))
(function a/325[int] b/326[int]
=======
    (if a/323
      (let (x/331 =a[int] a/323 p/332 =a (makeblock 0 a/323 b/324))
        (exit 10 x/331 p/332))
      (let (x/329 =a b/324 p/330 =a (makeblock 0 a/323 b/324))
        (exit 10 x/329 p/330)))
   with (10 x/325[int] p/326) (makeblock 0 (int,*) x/325 p/326)))
(function a/323[int] b/324[int]
>>>>>>> 749037f069 (Remove deprecated functions (PR#10867))
  (catch
<<<<<<< HEAD
    (if a/320 (exit 10 a/320 (makeblock 0 a/320 b/321))
      (exit 10 b/321 (makeblock 0 a/320 b/321)))
   with (10 x/322[int] p/323) (makeblock 0 (int,*) x/322 p/323)))
||||||| parent of 749037f069 (Remove deprecated functions (PR#10867))
    (if a/325 (exit 10 a/325 (makeblock 0 a/325 b/326))
      (exit 10 b/326 (makeblock 0 a/325 b/326)))
   with (10 x/327[int] p/328) (makeblock 0 (int,*) x/327 p/328)))
=======
    (if a/323 (exit 10 a/323 (makeblock 0 a/323 b/324))
      (exit 10 b/324 (makeblock 0 a/323 b/324)))
   with (10 x/325[int] p/326) (makeblock 0 (int,*) x/325 p/326)))
>>>>>>> 749037f069 (Remove deprecated functions (PR#10867))
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
(function a/330[int] b/331[int]
  (if a/330
    (let (x/332 =a[int] a/330 _p/333 =a (makeblock 0 a/330 b/331))
      (makeblock 0 (int,*) x/332 [0: 1 1]))
    (let (x/334 =a[int] a/330 p/335 =a (makeblock 0 a/330 b/331))
      (makeblock 0 (int,*) x/334 p/335))))
(function a/330[int] b/331[int]
  (if a/330 (makeblock 0 (int,*) a/330 [0: 1 1])
    (makeblock 0 (int,*) a/330 (makeblock 0 a/330 b/331))))
||||||| parent of 749037f069 (Remove deprecated functions (PR#10867))
(function a/335[int] b/336[int]
  (if a/335
    (let (x/337 =a[int] a/335 _p/338 =a (makeblock 0 a/335 b/336))
      (makeblock 0 (int,*) x/337 [0: 1 1]))
    (let (x/339 =a[int] a/335 p/340 =a (makeblock 0 a/335 b/336))
      (makeblock 0 (int,*) x/339 p/340))))
(function a/335[int] b/336[int]
  (if a/335 (makeblock 0 (int,*) a/335 [0: 1 1])
    (makeblock 0 (int,*) a/335 (makeblock 0 a/335 b/336))))
=======
(function a/333[int] b/334[int]
  (if a/333
    (let (x/335 =a[int] a/333 _p/336 =a (makeblock 0 a/333 b/334))
      (makeblock 0 (int,*) x/335 [0: 1 1]))
    (let (x/337 =a[int] a/333 p/338 =a (makeblock 0 a/333 b/334))
      (makeblock 0 (int,*) x/337 p/338))))
(function a/333[int] b/334[int]
  (if a/333 (makeblock 0 (int,*) a/333 [0: 1 1])
    (makeblock 0 (int,*) a/333 (makeblock 0 a/333 b/334))))
>>>>>>> 749037f069 (Remove deprecated functions (PR#10867))
- : bool -> bool -> bool * (bool * bool) = <fun>
|}]

let _ = fun a b -> match a, b with
| ((true as x, _) as p)
| ((false as x, _) as p) -> x, p
(* inside, onecase *)
[%%expect{|
<<<<<<< HEAD
(function a/336[int] b/337
  (let (x/338 =a[int] a/336 p/339 =a (makeblock 0 a/336 b/337))
    (makeblock 0 (int,*) x/338 p/339)))
(function a/336[int] b/337
  (makeblock 0 (int,*) a/336 (makeblock 0 a/336 b/337)))
||||||| parent of 749037f069 (Remove deprecated functions (PR#10867))
(function a/341[int] b/342
  (let (x/343 =a[int] a/341 p/344 =a (makeblock 0 a/341 b/342))
    (makeblock 0 (int,*) x/343 p/344)))
(function a/341[int] b/342
  (makeblock 0 (int,*) a/341 (makeblock 0 a/341 b/342)))
=======
(function a/339[int] b/340
  (let (x/341 =a[int] a/339 p/342 =a (makeblock 0 a/339 b/340))
    (makeblock 0 (int,*) x/341 p/342)))
(function a/339[int] b/340
  (makeblock 0 (int,*) a/339 (makeblock 0 a/339 b/340)))
>>>>>>> 749037f069 (Remove deprecated functions (PR#10867))
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
(function a/349[int] b/350
||||||| parent of 749037f069 (Remove deprecated functions (PR#10867))
(function a/354[int] b/355
=======
(function a/352[int] b/353
>>>>>>> 749037f069 (Remove deprecated functions (PR#10867))
  (catch
<<<<<<< HEAD
    (if a/349 (if b/350 (let (p/351 =a (field_imm 0 b/350)) p/351) (exit 12))
||||||| parent of 749037f069 (Remove deprecated functions (PR#10867))
    (if a/354 (if b/355 (let (p/356 =a (field_imm 0 b/355)) p/356) (exit 12))
=======
    (if a/352 (if b/353 (let (p/354 =a (field_imm 0 b/353)) p/354) (exit 12))
>>>>>>> 749037f069 (Remove deprecated functions (PR#10867))
      (exit 12))
<<<<<<< HEAD
   with (12) (let (p/352 =a (makeblock 0 a/349 b/350)) p/352)))
(function a/349[int] b/350
  (catch (if a/349 (if b/350 (field_imm 0 b/350) (exit 12)) (exit 12))
   with (12) (makeblock 0 a/349 b/350)))
||||||| parent of 749037f069 (Remove deprecated functions (PR#10867))
   with (12) (let (p/357 =a (makeblock 0 a/354 b/355)) p/357)))
(function a/354[int] b/355
  (catch (if a/354 (if b/355 (field_imm 0 b/355) (exit 12)) (exit 12))
   with (12) (makeblock 0 a/354 b/355)))
=======
   with (12) (let (p/355 =a (makeblock 0 a/352 b/353)) p/355)))
(function a/352[int] b/353
  (catch (if a/352 (if b/353 (field_imm 0 b/353) (exit 12)) (exit 12))
   with (12) (makeblock 0 a/352 b/353)))
>>>>>>> 749037f069 (Remove deprecated functions (PR#10867))
- : bool -> bool tuplist -> bool * bool tuplist = <fun>
|}]

let _ = fun a b -> match a, b with
| (true, Cons p)
| ((_, _) as p) -> p
(* inside, tuplist *)
[%%expect{|
<<<<<<< HEAD
(function a/353[int] b/354
||||||| parent of 749037f069 (Remove deprecated functions (PR#10867))
(function a/358[int] b/359
=======
(function a/356[int] b/357
>>>>>>> 749037f069 (Remove deprecated functions (PR#10867))
  (catch
    (catch
<<<<<<< HEAD
      (if a/353
        (if b/354 (let (p/358 =a (field_imm 0 b/354)) (exit 13 p/358))
||||||| parent of 749037f069 (Remove deprecated functions (PR#10867))
      (if a/358
        (if b/359 (let (p/363 =a (field_imm 0 b/359)) (exit 13 p/363))
=======
      (if a/356
        (if b/357 (let (p/361 =a (field_imm 0 b/357)) (exit 13 p/361))
>>>>>>> 749037f069 (Remove deprecated functions (PR#10867))
          (exit 14))
        (exit 14))
<<<<<<< HEAD
     with (14) (let (p/357 =a (makeblock 0 a/353 b/354)) (exit 13 p/357)))
   with (13 p/355) p/355))
(function a/353[int] b/354
||||||| parent of 749037f069 (Remove deprecated functions (PR#10867))
     with (14) (let (p/362 =a (makeblock 0 a/358 b/359)) (exit 13 p/362)))
   with (13 p/360) p/360))
(function a/358[int] b/359
=======
     with (14) (let (p/360 =a (makeblock 0 a/356 b/357)) (exit 13 p/360)))
   with (13 p/358) p/358))
(function a/356[int] b/357
>>>>>>> 749037f069 (Remove deprecated functions (PR#10867))
  (catch
    (catch
<<<<<<< HEAD
      (if a/353 (if b/354 (exit 13 (field_imm 0 b/354)) (exit 14)) (exit 14))
     with (14) (exit 13 (makeblock 0 a/353 b/354)))
   with (13 p/355) p/355))
||||||| parent of 749037f069 (Remove deprecated functions (PR#10867))
      (if a/358 (if b/359 (exit 13 (field_imm 0 b/359)) (exit 14)) (exit 14))
     with (14) (exit 13 (makeblock 0 a/358 b/359)))
   with (13 p/360) p/360))
=======
      (if a/356 (if b/357 (exit 13 (field_imm 0 b/357)) (exit 14)) (exit 14))
     with (14) (exit 13 (makeblock 0 a/356 b/357)))
   with (13 p/358) p/358))
>>>>>>> 749037f069 (Remove deprecated functions (PR#10867))
- : bool -> bool tuplist -> bool * bool tuplist = <fun>
|}]
