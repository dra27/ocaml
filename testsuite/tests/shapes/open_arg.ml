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
||||||| parent of a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
 "Make"[module] -> Abs<.3>(I/280, {
=======
 "Make"[module] -> Abs<.3>(I/281, {
>>>>>>> a9eeaff1c3 (Add type equality witness to the standard library (PR#11581))
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
