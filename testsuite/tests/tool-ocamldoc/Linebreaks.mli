(* TEST
 ocamldoc with html;
 output = "type_Linebreaks.html";
 reference = "${test_source_directory}/type_Linebreaks.reference";
 check-program-output;
*)

(**
   This file tests the encoding of linebreak inside OCaml code by the
   ocamldoc html backend.

   Two slightly different aspects are tested in this very file.

   - First, inside a "pre" tags, blanks character should not be escaped.
   For instance, the generated html code for this test fragment should not
   contain any <br> tag:
   {[
     let f x =
       let g x =
         let h x = x in
         h x in
       g x
   ]}
   See {{:http://caml.inria.fr/mantis/view.php?id=6341} MPR#6341} for more
   details or the file Linebreaks.html generated by ocamldoc from this file.
   - Second, outside of a "pre"  tags, blank characters in embedded code
   should be escaped, in order to make them render in a "pre"-like fashion.
   A good example should be the files type_{i Modulename}.html generated by
   ocamldoc that should contains the signature of the module [Modulename] in
   a "code" tags.
   For instance with the following type definitions,
*)

type a = A
type 'a b = {field:'a}
type c = C: 'a -> c

type s = ..
type s += B

val x : a

module S: sig module I:sig end end
module type s = sig end

class type d = object end

exception E of {inline:int}


(** type_Linebreaks.html should contain

{[
sig
  type a = A
  type 'a b = { field : 'a; }
  type c = C : 'a -> Linebreaks.c
  type s = ..
  type s += B
  val x : Linebreaks.a
  module S : sig module I : sig  end end
  module type s = sig  end
  class type d = object  end
  exception E of { inline : int; }
end
]}

with <br> tags used for linebreaks.
Another example would be [ let f x =
x] which is rendered with a <br> linebreak inside Linebreaks.html.

See {{:http://caml.inria.fr/mantis/view.php?id=7272}MPR#7272} for more
information.

*)
