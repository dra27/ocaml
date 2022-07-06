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
(let (*match*/289 = 3 *match*/290 = 2 *match*/291 = 1)
||||||| parent of bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
(let (*match*/294 = 3 *match*/295 = 2 *match*/296 = 1)
=======
(let (*match*/275 = 3 *match*/276 = 2 *match*/277 = 1)
>>>>>>> bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
  (catch
    (catch
<<<<<<< HEAD
      (catch (if (!= *match*/290 3) (exit 3) (exit 1)) with (3)
        (if (!= *match*/289 1) (exit 2) (exit 1)))
||||||| parent of bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
      (catch (if (!= *match*/295 3) (exit 3) (exit 1)) with (3)
        (if (!= *match*/294 1) (exit 2) (exit 1)))
=======
      (catch (if (!= *match*/276 3) (exit 3) (exit 1)) with (3)
        (if (!= *match*/275 1) (exit 2) (exit 1)))
>>>>>>> bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
     with (2) 0)
   with (1) 1))
<<<<<<< HEAD
(let (*match*/289 = 3 *match*/290 = 2 *match*/291 = 1)
  (catch (if (!= *match*/290 3) (if (!= *match*/289 1) 0 (exit 1)) (exit 1))
||||||| parent of bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
(let (*match*/294 = 3 *match*/295 = 2 *match*/296 = 1)
  (catch (if (!= *match*/295 3) (if (!= *match*/294 1) 0 (exit 1)) (exit 1))
=======
(let (*match*/275 = 3 *match*/276 = 2 *match*/277 = 1)
  (catch (if (!= *match*/276 3) (if (!= *match*/275 1) 0 (exit 1)) (exit 1))
>>>>>>> bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
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
(let (*match*/294 = 3 *match*/295 = 2 *match*/296 = 1)
||||||| parent of bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
(let (*match*/299 = 3 *match*/300 = 2 *match*/301 = 1)
=======
(let (*match*/280 = 3 *match*/281 = 2 *match*/282 = 1)
>>>>>>> bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
  (catch
    (catch
      (catch
<<<<<<< HEAD
        (if (!= *match*/295 3) (exit 6)
          (let (x/298 =a (makeblock 0 *match*/294 *match*/295 *match*/296))
            (exit 4 x/298)))
||||||| parent of bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
        (if (!= *match*/300 3) (exit 6)
          (let (x/303 =a (makeblock 0 *match*/299 *match*/300 *match*/301))
            (exit 4 x/303)))
=======
        (if (!= *match*/281 3) (exit 6)
          (let (x/284 =a (makeblock 0 *match*/280 *match*/281 *match*/282))
            (exit 4 x/284)))
>>>>>>> bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
       with (6)
<<<<<<< HEAD
        (if (!= *match*/294 1) (exit 5)
          (let (x/297 =a (makeblock 0 *match*/294 *match*/295 *match*/296))
            (exit 4 x/297))))
||||||| parent of bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
        (if (!= *match*/299 1) (exit 5)
          (let (x/302 =a (makeblock 0 *match*/299 *match*/300 *match*/301))
            (exit 4 x/302))))
=======
        (if (!= *match*/280 1) (exit 5)
          (let (x/283 =a (makeblock 0 *match*/280 *match*/281 *match*/282))
            (exit 4 x/283))))
>>>>>>> bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
     with (5) 0)
<<<<<<< HEAD
   with (4 x/292) (seq (ignore x/292) 1)))
(let (*match*/294 = 3 *match*/295 = 2 *match*/296 = 1)
||||||| parent of bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
   with (4 x/297) (seq (ignore x/297) 1)))
(let (*match*/299 = 3 *match*/300 = 2 *match*/301 = 1)
=======
   with (4 x/278) (seq (ignore x/278) 1)))
(let (*match*/280 = 3 *match*/281 = 2 *match*/282 = 1)
>>>>>>> bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
  (catch
<<<<<<< HEAD
    (if (!= *match*/295 3)
      (if (!= *match*/294 1) 0
        (exit 4 (makeblock 0 *match*/294 *match*/295 *match*/296)))
      (exit 4 (makeblock 0 *match*/294 *match*/295 *match*/296)))
   with (4 x/292) (seq (ignore x/292) 1)))
||||||| parent of bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
    (if (!= *match*/300 3)
      (if (!= *match*/299 1) 0
        (exit 4 (makeblock 0 *match*/299 *match*/300 *match*/301)))
      (exit 4 (makeblock 0 *match*/299 *match*/300 *match*/301)))
   with (4 x/297) (seq (ignore x/297) 1)))
=======
    (if (!= *match*/281 3)
      (if (!= *match*/280 1) 0
        (exit 4 (makeblock 0 *match*/280 *match*/281 *match*/282)))
      (exit 4 (makeblock 0 *match*/280 *match*/281 *match*/282)))
   with (4 x/278) (seq (ignore x/278) 1)))
>>>>>>> bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
- : bool = false
|}];;

(* Regression test for #3780 *)
let _ = fun a b ->
  match a, b with
  | ((true, _) as _g)
  | ((false, _) as _g) -> ()
[%%expect{|
<<<<<<< HEAD
(function a/299[int] b/300 : int 0)
(function a/299[int] b/300 : int 0)
||||||| parent of bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
(function a/304[int] b/305 : int 0)
(function a/304[int] b/305 : int 0)
=======
(function a/285[int] b/286 : int 0)
(function a/285[int] b/286 : int 0)
>>>>>>> bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
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
(function a/303[int] b/304 (let (p/305 =a (makeblock 0 a/303 b/304)) p/305))
(function a/303[int] b/304 (makeblock 0 a/303 b/304))
||||||| parent of bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
(function a/308[int] b/309 (let (p/310 =a (makeblock 0 a/308 b/309)) p/310))
(function a/308[int] b/309 (makeblock 0 a/308 b/309))
=======
(function a/289[int] b/290 (let (p/291 =a (makeblock 0 a/289 b/290)) p/291))
(function a/289[int] b/290 (makeblock 0 a/289 b/290))
>>>>>>> bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
- : bool -> 'a -> bool * 'a = <fun>
|}]

let _ = fun a b -> match a, b with
| ((true, _) as p)
| ((false, _) as p) -> p
(* inside, trivial *)
[%%expect{|
<<<<<<< HEAD
(function a/307[int] b/308 (let (p/309 =a (makeblock 0 a/307 b/308)) p/309))
(function a/307[int] b/308 (makeblock 0 a/307 b/308))
||||||| parent of bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
(function a/312[int] b/313 (let (p/314 =a (makeblock 0 a/312 b/313)) p/314))
(function a/312[int] b/313 (makeblock 0 a/312 b/313))
=======
(function a/293[int] b/294 (let (p/295 =a (makeblock 0 a/293 b/294)) p/295))
(function a/293[int] b/294 (makeblock 0 a/293 b/294))
>>>>>>> bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
- : bool -> 'a -> bool * 'a = <fun>
|}];;

let _ = fun a b -> match a, b with
| (true as x, _) as p -> x, p
| (false as x, _) as p -> x, p
(* outside, simple *)
[%%expect {|
<<<<<<< HEAD
(function a/313[int] b/314
  (let (x/315 =a[int] a/313 p/316 =a (makeblock 0 a/313 b/314))
    (makeblock 0 (int,*) x/315 p/316)))
(function a/313[int] b/314
  (makeblock 0 (int,*) a/313 (makeblock 0 a/313 b/314)))
||||||| parent of bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
(function a/318[int] b/319
  (let (x/320 =a[int] a/318 p/321 =a (makeblock 0 a/318 b/319))
    (makeblock 0 (int,*) x/320 p/321)))
(function a/318[int] b/319
  (makeblock 0 (int,*) a/318 (makeblock 0 a/318 b/319)))
=======
(function a/299[int] b/300
  (let (x/301 =a[int] a/299 p/302 =a (makeblock 0 a/299 b/300))
    (makeblock 0 (int,*) x/301 p/302)))
(function a/299[int] b/300
  (makeblock 0 (int,*) a/299 (makeblock 0 a/299 b/300)))
>>>>>>> bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
- : bool -> 'a -> bool * (bool * 'a) = <fun>
|}]

let _ = fun a b -> match a, b with
| ((true as x, _) as p)
| ((false as x, _) as p) -> x, p
(* inside, simple *)
[%%expect {|
<<<<<<< HEAD
(function a/319[int] b/320
  (let (x/321 =a[int] a/319 p/322 =a (makeblock 0 a/319 b/320))
    (makeblock 0 (int,*) x/321 p/322)))
(function a/319[int] b/320
  (makeblock 0 (int,*) a/319 (makeblock 0 a/319 b/320)))
||||||| parent of bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
(function a/324[int] b/325
  (let (x/326 =a[int] a/324 p/327 =a (makeblock 0 a/324 b/325))
    (makeblock 0 (int,*) x/326 p/327)))
(function a/324[int] b/325
  (makeblock 0 (int,*) a/324 (makeblock 0 a/324 b/325)))
=======
(function a/305[int] b/306
  (let (x/307 =a[int] a/305 p/308 =a (makeblock 0 a/305 b/306))
    (makeblock 0 (int,*) x/307 p/308)))
(function a/305[int] b/306
  (makeblock 0 (int,*) a/305 (makeblock 0 a/305 b/306)))
>>>>>>> bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
- : bool -> 'a -> bool * (bool * 'a) = <fun>
|}]

let _ = fun a b -> match a, b with
| (true as x, _) as p -> x, p
| (false, x) as p -> x, p
(* outside, complex *)
[%%expect{|
<<<<<<< HEAD
(function a/329[int] b/330[int]
  (if a/329
    (let (x/331 =a[int] a/329 p/332 =a (makeblock 0 a/329 b/330))
      (makeblock 0 (int,*) x/331 p/332))
    (let (x/333 =a b/330 p/334 =a (makeblock 0 a/329 b/330))
      (makeblock 0 (int,*) x/333 p/334))))
(function a/329[int] b/330[int]
  (if a/329 (makeblock 0 (int,*) a/329 (makeblock 0 a/329 b/330))
    (makeblock 0 (int,*) b/330 (makeblock 0 a/329 b/330))))
||||||| parent of bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
(function a/334[int] b/335[int]
  (if a/334
    (let (x/336 =a[int] a/334 p/337 =a (makeblock 0 a/334 b/335))
      (makeblock 0 (int,*) x/336 p/337))
    (let (x/338 =a b/335 p/339 =a (makeblock 0 a/334 b/335))
      (makeblock 0 (int,*) x/338 p/339))))
(function a/334[int] b/335[int]
  (if a/334 (makeblock 0 (int,*) a/334 (makeblock 0 a/334 b/335))
    (makeblock 0 (int,*) b/335 (makeblock 0 a/334 b/335))))
=======
(function a/315[int] b/316[int]
  (if a/315
    (let (x/317 =a[int] a/315 p/318 =a (makeblock 0 a/315 b/316))
      (makeblock 0 (int,*) x/317 p/318))
    (let (x/319 =a b/316 p/320 =a (makeblock 0 a/315 b/316))
      (makeblock 0 (int,*) x/319 p/320))))
(function a/315[int] b/316[int]
  (if a/315 (makeblock 0 (int,*) a/315 (makeblock 0 a/315 b/316))
    (makeblock 0 (int,*) b/316 (makeblock 0 a/315 b/316))))
>>>>>>> bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
- : bool -> bool -> bool * (bool * bool) = <fun>
|}]

let _ = fun a b -> match a, b with
| ((true as x, _) as p)
| ((false, x) as p)
  -> x, p
(* inside, complex *)
[%%expect{|
<<<<<<< HEAD
(function a/335[int] b/336[int]
||||||| parent of bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
(function a/340[int] b/341[int]
=======
(function a/321[int] b/322[int]
>>>>>>> bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
  (catch
<<<<<<< HEAD
    (if a/335
      (let (x/343 =a[int] a/335 p/344 =a (makeblock 0 a/335 b/336))
        (exit 10 x/343 p/344))
      (let (x/341 =a b/336 p/342 =a (makeblock 0 a/335 b/336))
        (exit 10 x/341 p/342)))
   with (10 x/337[int] p/338) (makeblock 0 (int,*) x/337 p/338)))
(function a/335[int] b/336[int]
||||||| parent of bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
    (if a/340
      (let (x/348 =a[int] a/340 p/349 =a (makeblock 0 a/340 b/341))
        (exit 10 x/348 p/349))
      (let (x/346 =a b/341 p/347 =a (makeblock 0 a/340 b/341))
        (exit 10 x/346 p/347)))
   with (10 x/342[int] p/343) (makeblock 0 (int,*) x/342 p/343)))
(function a/340[int] b/341[int]
=======
    (if a/321
      (let (x/329 =a[int] a/321 p/330 =a (makeblock 0 a/321 b/322))
        (exit 10 x/329 p/330))
      (let (x/327 =a b/322 p/328 =a (makeblock 0 a/321 b/322))
        (exit 10 x/327 p/328)))
   with (10 x/323[int] p/324) (makeblock 0 (int,*) x/323 p/324)))
(function a/321[int] b/322[int]
>>>>>>> bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
  (catch
<<<<<<< HEAD
    (if a/335 (exit 10 a/335 (makeblock 0 a/335 b/336))
      (exit 10 b/336 (makeblock 0 a/335 b/336)))
   with (10 x/337[int] p/338) (makeblock 0 (int,*) x/337 p/338)))
||||||| parent of bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
    (if a/340 (exit 10 a/340 (makeblock 0 a/340 b/341))
      (exit 10 b/341 (makeblock 0 a/340 b/341)))
   with (10 x/342[int] p/343) (makeblock 0 (int,*) x/342 p/343)))
=======
    (if a/321 (exit 10 a/321 (makeblock 0 a/321 b/322))
      (exit 10 b/322 (makeblock 0 a/321 b/322)))
   with (10 x/323[int] p/324) (makeblock 0 (int,*) x/323 p/324)))
>>>>>>> bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
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
(function a/345[int] b/346[int]
  (if a/345
    (let (x/347 =a[int] a/345 _p/348 =a (makeblock 0 a/345 b/346))
      (makeblock 0 (int,*) x/347 [0: 1 1]))
    (let (x/349 =a[int] a/345 p/350 =a (makeblock 0 a/345 b/346))
      (makeblock 0 (int,*) x/349 p/350))))
(function a/345[int] b/346[int]
  (if a/345 (makeblock 0 (int,*) a/345 [0: 1 1])
    (makeblock 0 (int,*) a/345 (makeblock 0 a/345 b/346))))
||||||| parent of bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
(function a/350[int] b/351[int]
  (if a/350
    (let (x/352 =a[int] a/350 _p/353 =a (makeblock 0 a/350 b/351))
      (makeblock 0 (int,*) x/352 [0: 1 1]))
    (let (x/354 =a[int] a/350 p/355 =a (makeblock 0 a/350 b/351))
      (makeblock 0 (int,*) x/354 p/355))))
(function a/350[int] b/351[int]
  (if a/350 (makeblock 0 (int,*) a/350 [0: 1 1])
    (makeblock 0 (int,*) a/350 (makeblock 0 a/350 b/351))))
=======
(function a/331[int] b/332[int]
  (if a/331
    (let (x/333 =a[int] a/331 _p/334 =a (makeblock 0 a/331 b/332))
      (makeblock 0 (int,*) x/333 [0: 1 1]))
    (let (x/335 =a[int] a/331 p/336 =a (makeblock 0 a/331 b/332))
      (makeblock 0 (int,*) x/335 p/336))))
(function a/331[int] b/332[int]
  (if a/331 (makeblock 0 (int,*) a/331 [0: 1 1])
    (makeblock 0 (int,*) a/331 (makeblock 0 a/331 b/332))))
>>>>>>> bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
- : bool -> bool -> bool * (bool * bool) = <fun>
|}]

let _ = fun a b -> match a, b with
| ((true as x, _) as p)
| ((false as x, _) as p) -> x, p
(* inside, onecase *)
[%%expect{|
<<<<<<< HEAD
(function a/351[int] b/352
  (let (x/353 =a[int] a/351 p/354 =a (makeblock 0 a/351 b/352))
    (makeblock 0 (int,*) x/353 p/354)))
(function a/351[int] b/352
  (makeblock 0 (int,*) a/351 (makeblock 0 a/351 b/352)))
||||||| parent of bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
(function a/356[int] b/357
  (let (x/358 =a[int] a/356 p/359 =a (makeblock 0 a/356 b/357))
    (makeblock 0 (int,*) x/358 p/359)))
(function a/356[int] b/357
  (makeblock 0 (int,*) a/356 (makeblock 0 a/356 b/357)))
=======
(function a/337[int] b/338
  (let (x/339 =a[int] a/337 p/340 =a (makeblock 0 a/337 b/338))
    (makeblock 0 (int,*) x/339 p/340)))
(function a/337[int] b/338
  (makeblock 0 (int,*) a/337 (makeblock 0 a/337 b/338)))
>>>>>>> bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
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
(function a/364[int] b/365
||||||| parent of bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
(function a/369[int] b/370
=======
(function a/350[int] b/351
>>>>>>> bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
  (catch
<<<<<<< HEAD
    (if a/364 (if b/365 (let (p/366 =a (field_imm 0 b/365)) p/366) (exit 12))
||||||| parent of bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
    (if a/369 (if b/370 (let (p/371 =a (field_imm 0 b/370)) p/371) (exit 12))
=======
    (if a/350 (if b/351 (let (p/352 =a (field_imm 0 b/351)) p/352) (exit 12))
>>>>>>> bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
      (exit 12))
<<<<<<< HEAD
   with (12) (let (p/367 =a (makeblock 0 a/364 b/365)) p/367)))
(function a/364[int] b/365
  (catch (if a/364 (if b/365 (field_imm 0 b/365) (exit 12)) (exit 12))
   with (12) (makeblock 0 a/364 b/365)))
||||||| parent of bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
   with (12) (let (p/372 =a (makeblock 0 a/369 b/370)) p/372)))
(function a/369[int] b/370
  (catch (if a/369 (if b/370 (field_imm 0 b/370) (exit 12)) (exit 12))
   with (12) (makeblock 0 a/369 b/370)))
=======
   with (12) (let (p/353 =a (makeblock 0 a/350 b/351)) p/353)))
(function a/350[int] b/351
  (catch (if a/350 (if b/351 (field_imm 0 b/351) (exit 12)) (exit 12))
   with (12) (makeblock 0 a/350 b/351)))
>>>>>>> bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
- : bool -> bool tuplist -> bool * bool tuplist = <fun>
|}]

let _ = fun a b -> match a, b with
| (true, Cons p)
| ((_, _) as p) -> p
(* inside, tuplist *)
[%%expect{|
<<<<<<< HEAD
(function a/368[int] b/369
||||||| parent of bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
(function a/373[int] b/374
=======
(function a/354[int] b/355
>>>>>>> bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
  (catch
    (catch
<<<<<<< HEAD
      (if a/368
        (if b/369 (let (p/373 =a (field_imm 0 b/369)) (exit 13 p/373))
||||||| parent of bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
      (if a/373
        (if b/374 (let (p/378 =a (field_imm 0 b/374)) (exit 13 p/378))
=======
      (if a/354
        (if b/355 (let (p/359 =a (field_imm 0 b/355)) (exit 13 p/359))
>>>>>>> bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
          (exit 14))
        (exit 14))
<<<<<<< HEAD
     with (14) (let (p/372 =a (makeblock 0 a/368 b/369)) (exit 13 p/372)))
   with (13 p/370) p/370))
(function a/368[int] b/369
||||||| parent of bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
     with (14) (let (p/377 =a (makeblock 0 a/373 b/374)) (exit 13 p/377)))
   with (13 p/375) p/375))
(function a/373[int] b/374
=======
     with (14) (let (p/358 =a (makeblock 0 a/354 b/355)) (exit 13 p/358)))
   with (13 p/356) p/356))
(function a/354[int] b/355
>>>>>>> bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
  (catch
    (catch
<<<<<<< HEAD
      (if a/368 (if b/369 (exit 13 (field_imm 0 b/369)) (exit 14)) (exit 14))
     with (14) (exit 13 (makeblock 0 a/368 b/369)))
   with (13 p/370) p/370))
||||||| parent of bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
      (if a/373 (if b/374 (exit 13 (field_imm 0 b/374)) (exit 14)) (exit 14))
     with (14) (exit 13 (makeblock 0 a/373 b/374)))
   with (13 p/375) p/375))
=======
      (if a/354 (if b/355 (exit 13 (field_imm 0 b/355)) (exit 14)) (exit 14))
     with (14) (exit 13 (makeblock 0 a/354 b/355)))
   with (13 p/356) p/356))
>>>>>>> bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
- : bool -> bool tuplist -> bool * bool tuplist = <fun>
|}]
