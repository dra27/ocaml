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
(let (*match*/269 = 3 *match*/270 = 2 *match*/271 = 1)
  (catch
    (catch
      (catch (if (!= *match*/270 3) (exit 3) (exit 1)) with (3)
        (if (!= *match*/269 1) (exit 2) (exit 1)))
     with (2) 0)
   with (1) 1))
(let (*match*/269 = 3 *match*/270 = 2 *match*/271 = 1)
  (catch (if (!= *match*/270 3) (if (!= *match*/269 1) 0 (exit 1)) (exit 1))
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
(let (*match*/274 = 3 *match*/275 = 2 *match*/276 = 1)
  (catch
    (catch
      (catch
        (if (!= *match*/275 3) (exit 6)
          (let (x/278 =a (makeblock 0 *match*/274 *match*/275 *match*/276))
            (exit 4 x/278)))
       with (6)
        (if (!= *match*/274 1) (exit 5)
          (let (x/277 =a (makeblock 0 *match*/274 *match*/275 *match*/276))
            (exit 4 x/277))))
     with (5) 0)
   with (4 x/272) (seq (ignore x/272) 1)))
(let (*match*/274 = 3 *match*/275 = 2 *match*/276 = 1)
  (catch
    (if (!= *match*/275 3)
      (if (!= *match*/274 1) 0
        (exit 4 (makeblock 0 *match*/274 *match*/275 *match*/276)))
      (exit 4 (makeblock 0 *match*/274 *match*/275 *match*/276)))
   with (4 x/272) (seq (ignore x/272) 1)))
- : bool = false
|}];;

(* Regression test for #3780 *)
let _ = fun a b ->
  match a, b with
  | ((true, _) as _g)
  | ((false, _) as _g) -> ()
[%%expect{|
(function a/279[int] b/280 : int 0)
(function a/279[int] b/280 : int 0)
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
(function a/283[int] b/284 (let (p/285 =a (makeblock 0 a/283 b/284)) p/285))
(function a/283[int] b/284 (makeblock 0 a/283 b/284))
- : bool -> 'a -> bool * 'a = <fun>
|}]

let _ = fun a b -> match a, b with
| ((true, _) as p)
| ((false, _) as p) -> p
(* inside, trivial *)
[%%expect{|
(function a/287[int] b/288 (let (p/289 =a (makeblock 0 a/287 b/288)) p/289))
(function a/287[int] b/288 (makeblock 0 a/287 b/288))
- : bool -> 'a -> bool * 'a = <fun>
|}];;

let _ = fun a b -> match a, b with
| (true as x, _) as p -> x, p
| (false as x, _) as p -> x, p
(* outside, simple *)
[%%expect {|
(function a/293[int] b/294
  (let (x/295 =a[int] a/293 p/296 =a (makeblock 0 a/293 b/294))
    (makeblock 0 (int,*) x/295 p/296)))
(function a/293[int] b/294
  (makeblock 0 (int,*) a/293 (makeblock 0 a/293 b/294)))
- : bool -> 'a -> bool * (bool * 'a) = <fun>
|}]

let _ = fun a b -> match a, b with
| ((true as x, _) as p)
| ((false as x, _) as p) -> x, p
(* inside, simple *)
[%%expect {|
(function a/299[int] b/300
  (let (x/301 =a[int] a/299 p/302 =a (makeblock 0 a/299 b/300))
    (makeblock 0 (int,*) x/301 p/302)))
(function a/299[int] b/300
  (makeblock 0 (int,*) a/299 (makeblock 0 a/299 b/300)))
- : bool -> 'a -> bool * (bool * 'a) = <fun>
|}]

let _ = fun a b -> match a, b with
| (true as x, _) as p -> x, p
| (false, x) as p -> x, p
(* outside, complex *)
[%%expect{|
(function a/309[int] b/310[int]
  (if a/309
    (let (x/311 =a[int] a/309 p/312 =a (makeblock 0 a/309 b/310))
      (makeblock 0 (int,*) x/311 p/312))
    (let (x/313 =a b/310 p/314 =a (makeblock 0 a/309 b/310))
      (makeblock 0 (int,*) x/313 p/314))))
(function a/309[int] b/310[int]
  (if a/309 (makeblock 0 (int,*) a/309 (makeblock 0 a/309 b/310))
    (makeblock 0 (int,*) b/310 (makeblock 0 a/309 b/310))))
- : bool -> bool -> bool * (bool * bool) = <fun>
|}]

let _ = fun a b -> match a, b with
| ((true as x, _) as p)
| ((false, x) as p)
  -> x, p
(* inside, complex *)
[%%expect{|
(function a/315[int] b/316[int]
  (catch
    (if a/315
      (let (x/323 =a[int] a/315 p/324 =a (makeblock 0 a/315 b/316))
        (exit 10 x/323 p/324))
      (let (x/321 =a b/316 p/322 =a (makeblock 0 a/315 b/316))
        (exit 10 x/321 p/322)))
   with (10 x/317[int] p/318) (makeblock 0 (int,*) x/317 p/318)))
(function a/315[int] b/316[int]
  (catch
    (if a/315 (exit 10 a/315 (makeblock 0 a/315 b/316))
      (exit 10 b/316 (makeblock 0 a/315 b/316)))
   with (10 x/317[int] p/318) (makeblock 0 (int,*) x/317 p/318)))
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
(function a/325[int] b/326[int]
  (if a/325
    (let (x/327 =a[int] a/325 _p/328 =a (makeblock 0 a/325 b/326))
      (makeblock 0 (int,*) x/327 [0: 1 1]))
    (let (x/329 =a[int] a/325 p/330 =a (makeblock 0 a/325 b/326))
      (makeblock 0 (int,*) x/329 p/330))))
(function a/325[int] b/326[int]
  (if a/325 (makeblock 0 (int,*) a/325 [0: 1 1])
    (makeblock 0 (int,*) a/325 (makeblock 0 a/325 b/326))))
- : bool -> bool -> bool * (bool * bool) = <fun>
|}]

let _ = fun a b -> match a, b with
| ((true as x, _) as p)
| ((false as x, _) as p) -> x, p
(* inside, onecase *)
[%%expect{|
(function a/331[int] b/332
  (let (x/333 =a[int] a/331 p/334 =a (makeblock 0 a/331 b/332))
    (makeblock 0 (int,*) x/333 p/334)))
(function a/331[int] b/332
  (makeblock 0 (int,*) a/331 (makeblock 0 a/331 b/332)))
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
(function a/344[int] b/345
  (catch
    (if a/344 (if b/345 (let (p/346 =a (field_imm 0 b/345)) p/346) (exit 12))
      (exit 12))
   with (12) (let (p/347 =a (makeblock 0 a/344 b/345)) p/347)))
(function a/344[int] b/345
  (catch (if a/344 (if b/345 (field_imm 0 b/345) (exit 12)) (exit 12))
   with (12) (makeblock 0 a/344 b/345)))
- : bool -> bool tuplist -> bool * bool tuplist = <fun>
|}]

let _ = fun a b -> match a, b with
| (true, Cons p)
| ((_, _) as p) -> p
(* inside, tuplist *)
[%%expect{|
(function a/348[int] b/349
  (catch
    (catch
      (if a/348
        (if b/349 (let (p/353 =a (field_imm 0 b/349)) (exit 13 p/353))
          (exit 14))
        (exit 14))
     with (14) (let (p/352 =a (makeblock 0 a/348 b/349)) (exit 13 p/352)))
   with (13 p/350) p/350))
(function a/348[int] b/349
  (catch
    (catch
      (if a/348 (if b/349 (exit 13 (field_imm 0 b/349)) (exit 14)) (exit 14))
     with (14) (exit 13 (makeblock 0 a/348 b/349)))
   with (13 p/350) p/350))
- : bool -> bool tuplist -> bool * bool tuplist = <fun>
|}]
