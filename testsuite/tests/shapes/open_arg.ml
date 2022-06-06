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
 "Make"[module] -> Abs<.3>(I/274, {
||||||| parent of adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
 "Make"[module] -> Abs<.3>(I/279, {
=======
 "Make"[module] -> Abs<.3>(I/280, {
>>>>>>> adc8419886 (Merge pull request PR#11213 from kayceesrk/refine_callback_semantics)
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
