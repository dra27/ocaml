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
(let (*match*/269 = 3 *match*/270 = 2 *match*/271 = 1)
||||||| parent of adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
(let (*match*/274 = 3 *match*/275 = 2 *match*/276 = 1)
=======
(let (*match*/275 = 3 *match*/276 = 2 *match*/277 = 1)
>>>>>>> adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
  (catch
    (catch
<<<<<<< HEAD
      (catch (if (!= *match*/270 3) (exit 3) (exit 1)) with (3)
        (if (!= *match*/269 1) (exit 2) (exit 1)))
||||||| parent of adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
      (catch (if (!= *match*/275 3) (exit 3) (exit 1)) with (3)
        (if (!= *match*/274 1) (exit 2) (exit 1)))
=======
      (catch (if (!= *match*/276 3) (exit 3) (exit 1)) with (3)
        (if (!= *match*/275 1) (exit 2) (exit 1)))
>>>>>>> adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
     with (2) 0)
   with (1) 1))
<<<<<<< HEAD
(let (*match*/269 = 3 *match*/270 = 2 *match*/271 = 1)
  (catch (if (!= *match*/270 3) (if (!= *match*/269 1) 0 (exit 1)) (exit 1))
||||||| parent of adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
(let (*match*/274 = 3 *match*/275 = 2 *match*/276 = 1)
  (catch (if (!= *match*/275 3) (if (!= *match*/274 1) 0 (exit 1)) (exit 1))
=======
(let (*match*/275 = 3 *match*/276 = 2 *match*/277 = 1)
  (catch (if (!= *match*/276 3) (if (!= *match*/275 1) 0 (exit 1)) (exit 1))
>>>>>>> adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
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
(let (*match*/274 = 3 *match*/275 = 2 *match*/276 = 1)
||||||| parent of adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
(let (*match*/279 = 3 *match*/280 = 2 *match*/281 = 1)
=======
(let (*match*/280 = 3 *match*/281 = 2 *match*/282 = 1)
>>>>>>> adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
  (catch
    (catch
      (catch
<<<<<<< HEAD
        (if (!= *match*/275 3) (exit 6)
          (let (x/278 =a (makeblock 0 *match*/274 *match*/275 *match*/276))
            (exit 4 x/278)))
||||||| parent of adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
        (if (!= *match*/280 3) (exit 6)
          (let (x/283 =a (makeblock 0 *match*/279 *match*/280 *match*/281))
            (exit 4 x/283)))
=======
        (if (!= *match*/281 3) (exit 6)
          (let (x/284 =a (makeblock 0 *match*/280 *match*/281 *match*/282))
            (exit 4 x/284)))
>>>>>>> adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
       with (6)
<<<<<<< HEAD
        (if (!= *match*/274 1) (exit 5)
          (let (x/277 =a (makeblock 0 *match*/274 *match*/275 *match*/276))
            (exit 4 x/277))))
||||||| parent of adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
        (if (!= *match*/279 1) (exit 5)
          (let (x/282 =a (makeblock 0 *match*/279 *match*/280 *match*/281))
            (exit 4 x/282))))
=======
        (if (!= *match*/280 1) (exit 5)
          (let (x/283 =a (makeblock 0 *match*/280 *match*/281 *match*/282))
            (exit 4 x/283))))
>>>>>>> adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
     with (5) 0)
<<<<<<< HEAD
   with (4 x/272) (seq (ignore x/272) 1)))
(let (*match*/274 = 3 *match*/275 = 2 *match*/276 = 1)
||||||| parent of adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
   with (4 x/277) (seq (ignore x/277) 1)))
(let (*match*/279 = 3 *match*/280 = 2 *match*/281 = 1)
=======
   with (4 x/278) (seq (ignore x/278) 1)))
(let (*match*/280 = 3 *match*/281 = 2 *match*/282 = 1)
>>>>>>> adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
  (catch
<<<<<<< HEAD
    (if (!= *match*/275 3)
      (if (!= *match*/274 1) 0
        (exit 4 (makeblock 0 *match*/274 *match*/275 *match*/276)))
      (exit 4 (makeblock 0 *match*/274 *match*/275 *match*/276)))
   with (4 x/272) (seq (ignore x/272) 1)))
||||||| parent of adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
    (if (!= *match*/280 3)
      (if (!= *match*/279 1) 0
        (exit 4 (makeblock 0 *match*/279 *match*/280 *match*/281)))
      (exit 4 (makeblock 0 *match*/279 *match*/280 *match*/281)))
   with (4 x/277) (seq (ignore x/277) 1)))
=======
    (if (!= *match*/281 3)
      (if (!= *match*/280 1) 0
        (exit 4 (makeblock 0 *match*/280 *match*/281 *match*/282)))
      (exit 4 (makeblock 0 *match*/280 *match*/281 *match*/282)))
   with (4 x/278) (seq (ignore x/278) 1)))
>>>>>>> adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
- : bool = false
|}];;

(* Regression test for #3780 *)
let _ = fun a b ->
  match a, b with
  | ((true, _) as _g)
  | ((false, _) as _g) -> ()
[%%expect{|
<<<<<<< HEAD
(function a/279[int] b/280 : int 0)
(function a/279[int] b/280 : int 0)
||||||| parent of adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
(function a/284[int] b/285 : int 0)
(function a/284[int] b/285 : int 0)
=======
(function a/285[int] b/286 : int 0)
(function a/285[int] b/286 : int 0)
>>>>>>> adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
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
(function a/283[int] b/284 (let (p/285 =a (makeblock 0 a/283 b/284)) p/285))
(function a/283[int] b/284 (makeblock 0 a/283 b/284))
||||||| parent of adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
(function a/288[int] b/289 (let (p/290 =a (makeblock 0 a/288 b/289)) p/290))
(function a/288[int] b/289 (makeblock 0 a/288 b/289))
=======
(function a/289[int] b/290 (let (p/291 =a (makeblock 0 a/289 b/290)) p/291))
(function a/289[int] b/290 (makeblock 0 a/289 b/290))
>>>>>>> adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
- : bool -> 'a -> bool * 'a = <fun>
|}]

let _ = fun a b -> match a, b with
| ((true, _) as p)
| ((false, _) as p) -> p
(* inside, trivial *)
[%%expect{|
<<<<<<< HEAD
(function a/287[int] b/288 (let (p/289 =a (makeblock 0 a/287 b/288)) p/289))
(function a/287[int] b/288 (makeblock 0 a/287 b/288))
||||||| parent of adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
(function a/292[int] b/293 (let (p/294 =a (makeblock 0 a/292 b/293)) p/294))
(function a/292[int] b/293 (makeblock 0 a/292 b/293))
=======
(function a/293[int] b/294 (let (p/295 =a (makeblock 0 a/293 b/294)) p/295))
(function a/293[int] b/294 (makeblock 0 a/293 b/294))
>>>>>>> adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
- : bool -> 'a -> bool * 'a = <fun>
|}];;

let _ = fun a b -> match a, b with
| (true as x, _) as p -> x, p
| (false as x, _) as p -> x, p
(* outside, simple *)
[%%expect {|
<<<<<<< HEAD
(function a/293[int] b/294
  (let (x/295 =a[int] a/293 p/296 =a (makeblock 0 a/293 b/294))
    (makeblock 0 (int,*) x/295 p/296)))
(function a/293[int] b/294
  (makeblock 0 (int,*) a/293 (makeblock 0 a/293 b/294)))
||||||| parent of adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
(function a/298[int] b/299
  (let (x/300 =a[int] a/298 p/301 =a (makeblock 0 a/298 b/299))
    (makeblock 0 (int,*) x/300 p/301)))
(function a/298[int] b/299
  (makeblock 0 (int,*) a/298 (makeblock 0 a/298 b/299)))
=======
(function a/299[int] b/300
  (let (x/301 =a[int] a/299 p/302 =a (makeblock 0 a/299 b/300))
    (makeblock 0 (int,*) x/301 p/302)))
(function a/299[int] b/300
  (makeblock 0 (int,*) a/299 (makeblock 0 a/299 b/300)))
>>>>>>> adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
- : bool -> 'a -> bool * (bool * 'a) = <fun>
|}]

let _ = fun a b -> match a, b with
| ((true as x, _) as p)
| ((false as x, _) as p) -> x, p
(* inside, simple *)
[%%expect {|
<<<<<<< HEAD
(function a/299[int] b/300
  (let (x/301 =a[int] a/299 p/302 =a (makeblock 0 a/299 b/300))
    (makeblock 0 (int,*) x/301 p/302)))
(function a/299[int] b/300
  (makeblock 0 (int,*) a/299 (makeblock 0 a/299 b/300)))
||||||| parent of adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
(function a/304[int] b/305
  (let (x/306 =a[int] a/304 p/307 =a (makeblock 0 a/304 b/305))
    (makeblock 0 (int,*) x/306 p/307)))
(function a/304[int] b/305
  (makeblock 0 (int,*) a/304 (makeblock 0 a/304 b/305)))
=======
(function a/305[int] b/306
  (let (x/307 =a[int] a/305 p/308 =a (makeblock 0 a/305 b/306))
    (makeblock 0 (int,*) x/307 p/308)))
(function a/305[int] b/306
  (makeblock 0 (int,*) a/305 (makeblock 0 a/305 b/306)))
>>>>>>> adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
- : bool -> 'a -> bool * (bool * 'a) = <fun>
|}]

let _ = fun a b -> match a, b with
| (true as x, _) as p -> x, p
| (false, x) as p -> x, p
(* outside, complex *)
[%%expect{|
<<<<<<< HEAD
(function a/309[int] b/310[int]
  (if a/309
    (let (x/311 =a[int] a/309 p/312 =a (makeblock 0 a/309 b/310))
      (makeblock 0 (int,*) x/311 p/312))
    (let (x/313 =a b/310 p/314 =a (makeblock 0 a/309 b/310))
      (makeblock 0 (int,*) x/313 p/314))))
(function a/309[int] b/310[int]
  (if a/309 (makeblock 0 (int,*) a/309 (makeblock 0 a/309 b/310))
    (makeblock 0 (int,*) b/310 (makeblock 0 a/309 b/310))))
||||||| parent of adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
(function a/314[int] b/315[int]
  (if a/314
    (let (x/316 =a[int] a/314 p/317 =a (makeblock 0 a/314 b/315))
      (makeblock 0 (int,*) x/316 p/317))
    (let (x/318 =a b/315 p/319 =a (makeblock 0 a/314 b/315))
      (makeblock 0 (int,*) x/318 p/319))))
(function a/314[int] b/315[int]
  (if a/314 (makeblock 0 (int,*) a/314 (makeblock 0 a/314 b/315))
    (makeblock 0 (int,*) b/315 (makeblock 0 a/314 b/315))))
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
>>>>>>> adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
- : bool -> bool -> bool * (bool * bool) = <fun>
|}]

let _ = fun a b -> match a, b with
| ((true as x, _) as p)
| ((false, x) as p)
  -> x, p
(* inside, complex *)
[%%expect{|
<<<<<<< HEAD
(function a/315[int] b/316[int]
||||||| parent of adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
(function a/320[int] b/321[int]
=======
(function a/321[int] b/322[int]
>>>>>>> adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
  (catch
<<<<<<< HEAD
    (if a/315
      (let (x/323 =a[int] a/315 p/324 =a (makeblock 0 a/315 b/316))
        (exit 10 x/323 p/324))
      (let (x/321 =a b/316 p/322 =a (makeblock 0 a/315 b/316))
        (exit 10 x/321 p/322)))
   with (10 x/317[int] p/318) (makeblock 0 (int,*) x/317 p/318)))
(function a/315[int] b/316[int]
||||||| parent of adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
    (if a/320
      (let (x/328 =a[int] a/320 p/329 =a (makeblock 0 a/320 b/321))
        (exit 10 x/328 p/329))
      (let (x/326 =a b/321 p/327 =a (makeblock 0 a/320 b/321))
        (exit 10 x/326 p/327)))
   with (10 x/322[int] p/323) (makeblock 0 (int,*) x/322 p/323)))
(function a/320[int] b/321[int]
=======
    (if a/321
      (let (x/329 =a[int] a/321 p/330 =a (makeblock 0 a/321 b/322))
        (exit 10 x/329 p/330))
      (let (x/327 =a b/322 p/328 =a (makeblock 0 a/321 b/322))
        (exit 10 x/327 p/328)))
   with (10 x/323[int] p/324) (makeblock 0 (int,*) x/323 p/324)))
(function a/321[int] b/322[int]
>>>>>>> adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
  (catch
<<<<<<< HEAD
    (if a/315 (exit 10 a/315 (makeblock 0 a/315 b/316))
      (exit 10 b/316 (makeblock 0 a/315 b/316)))
   with (10 x/317[int] p/318) (makeblock 0 (int,*) x/317 p/318)))
||||||| parent of adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
    (if a/320 (exit 10 a/320 (makeblock 0 a/320 b/321))
      (exit 10 b/321 (makeblock 0 a/320 b/321)))
   with (10 x/322[int] p/323) (makeblock 0 (int,*) x/322 p/323)))
=======
    (if a/321 (exit 10 a/321 (makeblock 0 a/321 b/322))
      (exit 10 b/322 (makeblock 0 a/321 b/322)))
   with (10 x/323[int] p/324) (makeblock 0 (int,*) x/323 p/324)))
>>>>>>> adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
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
(function a/325[int] b/326[int]
  (if a/325
    (let (x/327 =a[int] a/325 _p/328 =a (makeblock 0 a/325 b/326))
      (makeblock 0 (int,*) x/327 [0: 1 1]))
    (let (x/329 =a[int] a/325 p/330 =a (makeblock 0 a/325 b/326))
      (makeblock 0 (int,*) x/329 p/330))))
(function a/325[int] b/326[int]
  (if a/325 (makeblock 0 (int,*) a/325 [0: 1 1])
    (makeblock 0 (int,*) a/325 (makeblock 0 a/325 b/326))))
||||||| parent of adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
(function a/330[int] b/331[int]
  (if a/330
    (let (x/332 =a[int] a/330 _p/333 =a (makeblock 0 a/330 b/331))
      (makeblock 0 (int,*) x/332 [0: 1 1]))
    (let (x/334 =a[int] a/330 p/335 =a (makeblock 0 a/330 b/331))
      (makeblock 0 (int,*) x/334 p/335))))
(function a/330[int] b/331[int]
  (if a/330 (makeblock 0 (int,*) a/330 [0: 1 1])
    (makeblock 0 (int,*) a/330 (makeblock 0 a/330 b/331))))
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
>>>>>>> adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
- : bool -> bool -> bool * (bool * bool) = <fun>
|}]

let _ = fun a b -> match a, b with
| ((true as x, _) as p)
| ((false as x, _) as p) -> x, p
(* inside, onecase *)
[%%expect{|
<<<<<<< HEAD
(function a/331[int] b/332
  (let (x/333 =a[int] a/331 p/334 =a (makeblock 0 a/331 b/332))
    (makeblock 0 (int,*) x/333 p/334)))
(function a/331[int] b/332
  (makeblock 0 (int,*) a/331 (makeblock 0 a/331 b/332)))
||||||| parent of adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
(function a/336[int] b/337
  (let (x/338 =a[int] a/336 p/339 =a (makeblock 0 a/336 b/337))
    (makeblock 0 (int,*) x/338 p/339)))
(function a/336[int] b/337
  (makeblock 0 (int,*) a/336 (makeblock 0 a/336 b/337)))
=======
(function a/337[int] b/338
  (let (x/339 =a[int] a/337 p/340 =a (makeblock 0 a/337 b/338))
    (makeblock 0 (int,*) x/339 p/340)))
(function a/337[int] b/338
  (makeblock 0 (int,*) a/337 (makeblock 0 a/337 b/338)))
>>>>>>> adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
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
(function a/344[int] b/345
||||||| parent of adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
(function a/349[int] b/350
=======
(function a/350[int] b/351
>>>>>>> adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
  (catch
<<<<<<< HEAD
    (if a/344 (if b/345 (let (p/346 =a (field_imm 0 b/345)) p/346) (exit 12))
||||||| parent of adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
    (if a/349 (if b/350 (let (p/351 =a (field_imm 0 b/350)) p/351) (exit 12))
=======
    (if a/350 (if b/351 (let (p/352 =a (field_imm 0 b/351)) p/352) (exit 12))
>>>>>>> adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
      (exit 12))
<<<<<<< HEAD
   with (12) (let (p/347 =a (makeblock 0 a/344 b/345)) p/347)))
(function a/344[int] b/345
  (catch (if a/344 (if b/345 (field_imm 0 b/345) (exit 12)) (exit 12))
   with (12) (makeblock 0 a/344 b/345)))
||||||| parent of adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
   with (12) (let (p/352 =a (makeblock 0 a/349 b/350)) p/352)))
(function a/349[int] b/350
  (catch (if a/349 (if b/350 (field_imm 0 b/350) (exit 12)) (exit 12))
   with (12) (makeblock 0 a/349 b/350)))
=======
   with (12) (let (p/353 =a (makeblock 0 a/350 b/351)) p/353)))
(function a/350[int] b/351
  (catch (if a/350 (if b/351 (field_imm 0 b/351) (exit 12)) (exit 12))
   with (12) (makeblock 0 a/350 b/351)))
>>>>>>> adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
- : bool -> bool tuplist -> bool * bool tuplist = <fun>
|}]

let _ = fun a b -> match a, b with
| (true, Cons p)
| ((_, _) as p) -> p
(* inside, tuplist *)
[%%expect{|
<<<<<<< HEAD
(function a/348[int] b/349
||||||| parent of adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
(function a/353[int] b/354
=======
(function a/354[int] b/355
>>>>>>> adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
  (catch
    (catch
<<<<<<< HEAD
      (if a/348
        (if b/349 (let (p/353 =a (field_imm 0 b/349)) (exit 13 p/353))
||||||| parent of adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
      (if a/353
        (if b/354 (let (p/358 =a (field_imm 0 b/354)) (exit 13 p/358))
=======
      (if a/354
        (if b/355 (let (p/359 =a (field_imm 0 b/355)) (exit 13 p/359))
>>>>>>> adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
          (exit 14))
        (exit 14))
<<<<<<< HEAD
     with (14) (let (p/352 =a (makeblock 0 a/348 b/349)) (exit 13 p/352)))
   with (13 p/350) p/350))
(function a/348[int] b/349
||||||| parent of adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
     with (14) (let (p/357 =a (makeblock 0 a/353 b/354)) (exit 13 p/357)))
   with (13 p/355) p/355))
(function a/353[int] b/354
=======
     with (14) (let (p/358 =a (makeblock 0 a/354 b/355)) (exit 13 p/358)))
   with (13 p/356) p/356))
(function a/354[int] b/355
>>>>>>> adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
  (catch
    (catch
<<<<<<< HEAD
      (if a/348 (if b/349 (exit 13 (field_imm 0 b/349)) (exit 14)) (exit 14))
     with (14) (exit 13 (makeblock 0 a/348 b/349)))
   with (13 p/350) p/350))
||||||| parent of adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
      (if a/353 (if b/354 (exit 13 (field_imm 0 b/354)) (exit 14)) (exit 14))
     with (14) (exit 13 (makeblock 0 a/353 b/354)))
   with (13 p/355) p/355))
=======
      (if a/354 (if b/355 (exit 13 (field_imm 0 b/355)) (exit 14)) (exit 14))
     with (14) (exit 13 (makeblock 0 a/354 b/355)))
   with (13 p/356) p/356))
>>>>>>> adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
- : bool -> bool tuplist -> bool * bool tuplist = <fun>
|}]
