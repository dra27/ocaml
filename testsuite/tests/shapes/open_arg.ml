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
 "Make"[module] -> Abs<.3>(I/294, {
||||||| parent of bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
 "Make"[module] -> Abs<.3>(I/299, {
=======
 "Make"[module] -> Abs<.3>(I/280, {
>>>>>>> bc72d318d2 (Merge pull request PR#11382 from Octachron/topdir_fix)
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
