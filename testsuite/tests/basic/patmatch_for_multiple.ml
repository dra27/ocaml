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
(let (*match*/289 = 3 *match*/290 = 2 *match*/291 = 1)
  (catch
    (catch
      (catch (if (!= *match*/290 3) (exit 3) (exit 1)) with (3)
        (if (!= *match*/289 1) (exit 2) (exit 1)))
     with (2) 0)
   with (1) 1))
(let (*match*/289 = 3 *match*/290 = 2 *match*/291 = 1)
  (catch (if (!= *match*/290 3) (if (!= *match*/289 1) 0 (exit 1)) (exit 1))
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
(let (*match*/294 = 3 *match*/295 = 2 *match*/296 = 1)
  (catch
    (catch
      (catch
        (if (!= *match*/295 3) (exit 6)
          (let (x/298 =a (makeblock 0 *match*/294 *match*/295 *match*/296))
            (exit 4 x/298)))
       with (6)
        (if (!= *match*/294 1) (exit 5)
          (let (x/297 =a (makeblock 0 *match*/294 *match*/295 *match*/296))
            (exit 4 x/297))))
     with (5) 0)
   with (4 x/292) (seq (ignore x/292) 1)))
(let (*match*/294 = 3 *match*/295 = 2 *match*/296 = 1)
  (catch
    (if (!= *match*/295 3)
      (if (!= *match*/294 1) 0
        (exit 4 (makeblock 0 *match*/294 *match*/295 *match*/296)))
      (exit 4 (makeblock 0 *match*/294 *match*/295 *match*/296)))
   with (4 x/292) (seq (ignore x/292) 1)))
- : bool = false
|}];;

(* Regression test for #3780 *)
let _ = fun a b ->
  match a, b with
  | ((true, _) as _g)
  | ((false, _) as _g) -> ()
[%%expect{|
(function a/299[int] b/300 : int 0)
(function a/299[int] b/300 : int 0)
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
(function a/303[int] b/304 (let (p/305 =a (makeblock 0 a/303 b/304)) p/305))
(function a/303[int] b/304 (makeblock 0 a/303 b/304))
- : bool -> 'a -> bool * 'a = <fun>
|}]

let _ = fun a b -> match a, b with
| ((true, _) as p)
| ((false, _) as p) -> p
(* inside, trivial *)
[%%expect{|
(function a/307[int] b/308 (let (p/309 =a (makeblock 0 a/307 b/308)) p/309))
(function a/307[int] b/308 (makeblock 0 a/307 b/308))
- : bool -> 'a -> bool * 'a = <fun>
|}];;

let _ = fun a b -> match a, b with
| (true as x, _) as p -> x, p
| (false as x, _) as p -> x, p
(* outside, simple *)
[%%expect {|
(function a/313[int] b/314
  (let (x/315 =a[int] a/313 p/316 =a (makeblock 0 a/313 b/314))
    (makeblock 0 (int,*) x/315 p/316)))
(function a/313[int] b/314
  (makeblock 0 (int,*) a/313 (makeblock 0 a/313 b/314)))
- : bool -> 'a -> bool * (bool * 'a) = <fun>
|}]

let _ = fun a b -> match a, b with
| ((true as x, _) as p)
| ((false as x, _) as p) -> x, p
(* inside, simple *)
[%%expect {|
(function a/319[int] b/320
  (let (x/321 =a[int] a/319 p/322 =a (makeblock 0 a/319 b/320))
    (makeblock 0 (int,*) x/321 p/322)))
(function a/319[int] b/320
  (makeblock 0 (int,*) a/319 (makeblock 0 a/319 b/320)))
- : bool -> 'a -> bool * (bool * 'a) = <fun>
|}]

let _ = fun a b -> match a, b with
| (true as x, _) as p -> x, p
| (false, x) as p -> x, p
(* outside, complex *)
[%%expect{|
(function a/329[int] b/330[int]
  (if a/329
    (let (x/331 =a[int] a/329 p/332 =a (makeblock 0 a/329 b/330))
      (makeblock 0 (int,*) x/331 p/332))
    (let (x/333 =a b/330 p/334 =a (makeblock 0 a/329 b/330))
      (makeblock 0 (int,*) x/333 p/334))))
(function a/329[int] b/330[int]
  (if a/329 (makeblock 0 (int,*) a/329 (makeblock 0 a/329 b/330))
    (makeblock 0 (int,*) b/330 (makeblock 0 a/329 b/330))))
- : bool -> bool -> bool * (bool * bool) = <fun>
|}]

let _ = fun a b -> match a, b with
| ((true as x, _) as p)
| ((false, x) as p)
  -> x, p
(* inside, complex *)
[%%expect{|
(function a/335[int] b/336[int]
  (catch
    (if a/335
      (let (x/343 =a[int] a/335 p/344 =a (makeblock 0 a/335 b/336))
        (exit 10 x/343 p/344))
      (let (x/341 =a b/336 p/342 =a (makeblock 0 a/335 b/336))
        (exit 10 x/341 p/342)))
   with (10 x/337[int] p/338) (makeblock 0 (int,*) x/337 p/338)))
(function a/335[int] b/336[int]
  (catch
    (if a/335 (exit 10 a/335 (makeblock 0 a/335 b/336))
      (exit 10 b/336 (makeblock 0 a/335 b/336)))
   with (10 x/337[int] p/338) (makeblock 0 (int,*) x/337 p/338)))
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
(function a/345[int] b/346[int]
  (if a/345
    (let (x/347 =a[int] a/345 _p/348 =a (makeblock 0 a/345 b/346))
      (makeblock 0 (int,*) x/347 [0: 1 1]))
    (let (x/349 =a[int] a/345 p/350 =a (makeblock 0 a/345 b/346))
      (makeblock 0 (int,*) x/349 p/350))))
(function a/345[int] b/346[int]
  (if a/345 (makeblock 0 (int,*) a/345 [0: 1 1])
    (makeblock 0 (int,*) a/345 (makeblock 0 a/345 b/346))))
- : bool -> bool -> bool * (bool * bool) = <fun>
|}]

let _ = fun a b -> match a, b with
| ((true as x, _) as p)
| ((false as x, _) as p) -> x, p
(* inside, onecase *)
[%%expect{|
(function a/351[int] b/352
  (let (x/353 =a[int] a/351 p/354 =a (makeblock 0 a/351 b/352))
    (makeblock 0 (int,*) x/353 p/354)))
(function a/351[int] b/352
  (makeblock 0 (int,*) a/351 (makeblock 0 a/351 b/352)))
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
(function a/364[int] b/365
  (catch
    (if a/364 (if b/365 (let (p/366 =a (field_imm 0 b/365)) p/366) (exit 12))
      (exit 12))
   with (12) (let (p/367 =a (makeblock 0 a/364 b/365)) p/367)))
(function a/364[int] b/365
  (catch (if a/364 (if b/365 (field_imm 0 b/365) (exit 12)) (exit 12))
   with (12) (makeblock 0 a/364 b/365)))
- : bool -> bool tuplist -> bool * bool tuplist = <fun>
|}]

let _ = fun a b -> match a, b with
| (true, Cons p)
| ((_, _) as p) -> p
(* inside, tuplist *)
[%%expect{|
(function a/368[int] b/369
  (catch
    (catch
      (if a/368
        (if b/369 (let (p/373 =a (field_imm 0 b/369)) (exit 13 p/373))
          (exit 14))
        (exit 14))
     with (14) (let (p/372 =a (makeblock 0 a/368 b/369)) (exit 13 p/372)))
   with (13 p/370) p/370))
(function a/368[int] b/369
  (catch
    (catch
      (if a/368 (if b/369 (exit 13 (field_imm 0 b/369)) (exit 14)) (exit 14))
     with (14) (exit 13 (makeblock 0 a/368 b/369)))
   with (13 p/370) p/370))
- : bool -> bool tuplist -> bool * bool tuplist = <fun>
|}]
