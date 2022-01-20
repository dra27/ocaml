(* TEST
   flags = "-dshape"
   * expect
*)

module type S = sig
  type t
  val x : t
end
[%%expect{|
{
 "S"[module type] -> <.2>;
 }
module type S = sig type t val x : t end
|}]

module Falias (X : S) = X
[%%expect{|
{
<<<<<<< HEAD
 "Falias"[module] -> Abs<.4>(X/277, X/277<.3>);
||||||| parent of be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
 "Falias"[module] -> Abs<.4>(X/282, X/282<.3>);
=======
 "Falias"[module] -> Abs<.4>(X/279, X/279<.3>);
>>>>>>> be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
 }
module Falias : functor (X : S) -> sig type t = X.t val x : t end
|}]

module Finclude (X : S) = struct
  include X
end
[%%expect{|
{
 "Finclude"[module] ->
     Abs<.6>
<<<<<<< HEAD
        (X/281,
||||||| parent of be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
        (X/286,
=======
        (X/283,
>>>>>>> be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
         {
<<<<<<< HEAD
          "t"[type] -> X/281<.5> . "t"[type];
          "x"[value] -> X/281<.5> . "x"[value];
||||||| parent of be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
          "t"[type] -> X/286<.5> . "t"[type];
          "x"[value] -> X/286<.5> . "x"[value];
=======
          "t"[type] -> X/283<.5> . "t"[type];
          "x"[value] -> X/283<.5> . "x"[value];
>>>>>>> be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
          });
 }
module Finclude : functor (X : S) -> sig type t = X.t val x : t end
|}]

module Fredef (X : S) = struct
  type t = X.t
  let x = X.x
end
[%%expect{|
{
 "Fredef"[module] ->
<<<<<<< HEAD
     Abs<.10>(X/288, {
||||||| parent of be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
     Abs<.10>(X/293, {
=======
     Abs<.10>(X/290, {
>>>>>>> be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
                      "t"[type] -> <.8>;
                      "x"[value] -> <.9>;
                      });
 }
module Fredef : functor (X : S) -> sig type t = X.t val x : X.t end
|}]

module Fignore (_ : S) = struct
  type t = Fresh
  let x = Fresh
end
[%%expect{|
{
 "Fignore"[module] ->
     Abs<.14>(()/1, {
                     "t"[type] -> <.11>;
                     "x"[value] -> <.13>;
                     });
 }
module Fignore : S -> sig type t = Fresh val x : t end
|}]

module Arg : S = struct
  type t = T
  let x = T
end
[%%expect{|
{
 "Arg"[module] -> {<.18>
                   "t"[type] -> <.15>;
                   "x"[value] -> <.17>;
                   };
 }
module Arg : S
|}]

include Falias(Arg)
[%%expect{|
{
 "t"[type] -> <.15>;
 "x"[value] -> <.17>;
 }
type t = Arg.t
val x : t = <abstr>
|}]

include Finclude(Arg)
[%%expect{|
{
 "t"[type] -> <.15>;
 "x"[value] -> <.17>;
 }
type t = Arg.t
val x : t = <abstr>
|}]

include Fredef(Arg)
[%%expect{|
{
 "t"[type] -> <.8>;
 "x"[value] -> <.9>;
 }
type t = Arg.t
val x : Arg.t = <abstr>
|}]

include Fignore(Arg)
[%%expect{|
{
 "t"[type] -> <.11>;
 "x"[value] -> <.13>;
 }
type t = Fignore(Arg).t = Fresh
val x : t = Fresh
|}]

include Falias(struct type t = int let x = 0 end)
[%%expect{|
{
 "t"[type] -> <.19>;
 "x"[value] -> <.20>;
 }
type t = int
val x : t = 0
|}]

include Finclude(struct type t = int let x = 0 end)
[%%expect{|
{
 "t"[type] -> <.21>;
 "x"[value] -> <.22>;
 }
type t = int
val x : t = 0
|}]

include Fredef(struct type t = int let x = 0 end)
[%%expect{|
{
 "t"[type] -> <.8>;
 "x"[value] -> <.9>;
 }
type t = int
val x : int = 0
|}]

include Fignore(struct type t = int let x = 0 end)
[%%expect{|
{
 "t"[type] -> <.11>;
 "x"[value] -> <.13>;
 }
type t = Fresh
val x : t = Fresh
|}]

module Fgen () = struct
  type t = Fresher
  let x = Fresher
end
[%%expect{|
{
 "Fgen"[module] -> Abs<.30>(()/1, {
                                   "t"[type] -> <.27>;
                                   "x"[value] -> <.29>;
                                   });
 }
module Fgen : functor () -> sig type t = Fresher val x : t end
|}]

include Fgen ()
[%%expect{|
{
 "t"[type] -> <.27>;
 "x"[value] -> <.29>;
 }
type t = Fresher
val x : t = Fresher
|}]

(***************************************************************************)
(* Make sure we restrict shapes even when constraints imply [Tcoerce_none] *)
(***************************************************************************)

module type Small = sig
  type t
end
[%%expect{|
{
 "Small"[module type] -> <.32>;
 }
module type Small = sig type t end
|}]

module type Big = sig
  type t
  type u
end
[%%expect{|
{
 "Big"[module type] -> <.35>;
 }
module type Big = sig type t type u end
|}]

module type B2S = functor (X : Big) -> Small with type t = X.t
[%%expect{|
{
 "B2S"[module type] -> <.38>;
 }
module type B2S = functor (X : Big) -> sig type t = X.t end
|}]

module Big_to_small1 : B2S = functor (X : Big) -> X
[%%expect{|
{
 "Big_to_small1"[module] ->
<<<<<<< HEAD
     Abs<.40>(X/383, {<.39>
                      "t"[type] -> X/383<.39> . "t"[type];
||||||| parent of be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
     Abs<.40>(X/388, {<.39>
                      "t"[type] -> X/388<.39> . "t"[type];
=======
     Abs<.40>(X/385, {<.39>
                      "t"[type] -> X/385<.39> . "t"[type];
>>>>>>> be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
                      });
 }
module Big_to_small1 : B2S
|}]

module Big_to_small2 : B2S = functor (X : Big) -> struct include X end
[%%expect{|
{
 "Big_to_small2"[module] ->
<<<<<<< HEAD
     Abs<.42>(X/386, {
                      "t"[type] -> X/386<.41> . "t"[type];
||||||| parent of be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
     Abs<.42>(X/391, {
                      "t"[type] -> X/391<.41> . "t"[type];
=======
     Abs<.42>(X/388, {
                      "t"[type] -> X/388<.41> . "t"[type];
>>>>>>> be15c3a3c3 (Remove `Stream`, `Genlex`, `Pervasives` & the legacy `bigarray` library (PR#10896))
                      });
 }
module Big_to_small2 : B2S
|}]
