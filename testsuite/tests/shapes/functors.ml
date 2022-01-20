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
 ("Falias", module) -> Abs<.4>(X/277, X/277<.3>);
||||||| parent of eae9fc5c5e (Merge pull request PR#10825 from gasche/shape-strong-call-by-need)
 ("Falias", module) -> Abs<.4>(X/282, X/282<.3>);
=======
 "Falias"[module] -> Abs<.4>(X/282, X/282<.3>);
>>>>>>> eae9fc5c5e (Merge pull request PR#10825 from gasche/shape-strong-call-by-need)
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
        (X/281,
         {
<<<<<<< HEAD
          ("t", type) -> X/281<.5> . "t"[type];
          ("x", value) -> X/281<.5> . "x"[value];
||||||| parent of eae9fc5c5e (Merge pull request PR#10825 from gasche/shape-strong-call-by-need)
          ("t", type) -> X/286<.5> . "t"[type];
          ("x", value) -> X/286<.5> . "x"[value];
=======
          "t"[type] -> X/286<.5> . "t"[type];
          "x"[value] -> X/286<.5> . "x"[value];
>>>>>>> eae9fc5c5e (Merge pull request PR#10825 from gasche/shape-strong-call-by-need)
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
<<<<<<< HEAD
 ("Fredef", module) ->
     Abs<.10>(X/288, {
                      ("t", type) -> <.8>;
                      ("x", value) -> <.9>;
||||||| parent of eae9fc5c5e (Merge pull request PR#10825 from gasche/shape-strong-call-by-need)
 ("Fredef", module) ->
     Abs<.10>(X/293, {
                      ("t", type) -> <.8>;
                      ("x", value) -> <.9>;
=======
 "Fredef"[module] ->
     Abs<.10>(X/293, {
                      "t"[type] -> <.8>;
                      "x"[value] -> <.9>;
>>>>>>> eae9fc5c5e (Merge pull request PR#10825 from gasche/shape-strong-call-by-need)
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
<<<<<<< HEAD
 ("Big_to_small1", module) ->
     Abs<.40>
        (shape-var/384,
         {<<internal>>
          ("t", type) -> shape-var/384<<internal>> . "t"[type];
          });
||||||| parent of eae9fc5c5e (Merge pull request PR#10825 from gasche/shape-strong-call-by-need)
 ("Big_to_small1", module) ->
     Abs<.40>
        (shape-var/389,
         {<<internal>>
          ("t", type) -> shape-var/389<<internal>> . "t"[type];
          });
=======
 "Big_to_small1"[module] ->
     Abs<.40>(X/388, {<.39>
                      "t"[type] -> X/388<.39> . "t"[type];
                      });
>>>>>>> eae9fc5c5e (Merge pull request PR#10825 from gasche/shape-strong-call-by-need)
 }
module Big_to_small1 : B2S
|}]

module Big_to_small2 : B2S = functor (X : Big) -> struct include X end
[%%expect{|
{
<<<<<<< HEAD
 ("Big_to_small2", module) ->
     Abs<.42>
        (shape-var/390,
         {
          ("t", type) -> (shape-var/390<<internal>> . "t"[type])<.41>;
          });
||||||| parent of eae9fc5c5e (Merge pull request PR#10825 from gasche/shape-strong-call-by-need)
 ("Big_to_small2", module) ->
     Abs<.42>
        (shape-var/395,
         {
          ("t", type) -> (shape-var/395<<internal>> . "t"[type])<.41>;
          });
=======
 "Big_to_small2"[module] ->
     Abs<.42>(X/391, {
                      "t"[type] -> X/391<.41> . "t"[type];
                      });
>>>>>>> eae9fc5c5e (Merge pull request PR#10825 from gasche/shape-strong-call-by-need)
 }
module Big_to_small2 : B2S
|}]
