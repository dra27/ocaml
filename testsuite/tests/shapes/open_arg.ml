(* TEST
   flags = "-dshape"
   * expect
*)

module type Make = functor (I : sig end) -> sig
  open I
end
;;

[%%expect{|
{
 "Make"[module type] -> <.1>;
 }
module type Make = functor (I : sig end) -> sig end
|}]

module Make (I : sig end) : sig
  open I
end = struct end
;;

[%%expect{|
{
<<<<<<< HEAD
 "Make"[module] -> Abs<.3>(I/275, {
||||||| parent of b6d2214fb7 (Merge pull request PR#11318 from Octachron/topdir_and_expect_test)
 "Make"[module] -> Abs<.3>(I/280, {
=======
 "Make"[module] -> Abs<.3>(I/299, {
>>>>>>> b6d2214fb7 (Merge pull request PR#11318 from Octachron/topdir_and_expect_test)
                                   });
 }
module Make : functor (I : sig end) -> sig end
|}]

module type Make = functor (I : sig end) ->
module type of struct
  open I
end

[%%expect{|
{
 "Make"[module type] -> <.5>;
 }
module type Make = functor (I : sig end) -> sig end
|}]
