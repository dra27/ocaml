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
 "Make"[module] -> Abs<.3>(I/277, {
||||||| parent of be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
 "Make"[module] -> Abs<.3>(I/282, {
=======
 "Make"[module] -> Abs<.3>(I/279, {
>>>>>>> be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
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
