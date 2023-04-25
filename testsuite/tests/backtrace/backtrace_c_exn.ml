<<<<<<< HEAD
(* TEST
   modules = "backtrace_c_exn_.c"
   flags = "-g"
   ocamlrunparam += ",b=1"
   * skip
   reason = "OCaml 5 only"
||||||| parent of 18bd88faf2 (New script language for ocamltest (PR#12185))
(* TEST
   modules = "backtrace_c_exn_.c"
   flags = "-g"
   ocamlrunparam += ",b=1"
=======
(* TEST_BELOW
(* Blank lines added here to preserve locations. *)


>>>>>>> 18bd88faf2 (New script language for ocamltest (PR#12185))
*)

(* https://github.com/ocaml-multicore/ocaml-multicore/issues/498 *)
external stubbed_raise : unit -> unit = "caml_498_raise"

let raise_exn () = failwith "exn"

let () = Callback.register "test_raise_exn" raise_exn

let () =
  try
    stubbed_raise ()
  with
  | exn ->
    Printexc.to_string exn |> print_endline;
    Printexc.print_backtrace stdout

(* TEST
 modules = "backtrace_c_exn_.c";
 flags = "-g";
 ocamlrunparam += ",b=1";
*)
