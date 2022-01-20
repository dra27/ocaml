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
 ("Make", module) -> Abs<.3>(I/277, {
                                     });
||||||| parent of eae9fc5c5e (Merge pull request PR#10825 from gasche/shape-strong-call-by-need)
 ("Make", module) -> Abs<.3>(I/282, {
                                     });
=======
 "Make"[module] -> Abs<.3>(I/282, {
                                   });
>>>>>>> eae9fc5c5e (Merge pull request PR#10825 from gasche/shape-strong-call-by-need)
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
