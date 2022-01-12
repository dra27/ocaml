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
 ("Make", module type) -> <.1>;
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
 ("Make", module) -> Abs<.3>(I/279, {
||||||| parent of 749037f069 (Remove deprecated functions (PR#10867))
 ("Make", module) -> Abs<.3>(I/284, {
=======
 ("Make", module) -> Abs<.3>(I/282, {
>>>>>>> 749037f069 (Remove deprecated functions (PR#10867))
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
 ("Make", module type) -> <.5>;
 }
module type Make = functor (I : sig end) -> sig end
|}]
