(* TEST
<<<<<<< HEAD
   modules = "alloc_async_stubs.c"
||||||| parent of 18bd88faf2 (New script language for ocamltest (PR#12185))
   modules = "alloc_async_stubs.c"
   * skip
   reason = "alloc async changes: https://github.com/ocaml/ocaml/pull/8897"
=======
 modules = "alloc_async_stubs.c";
 reason = "alloc async changes: https://github.com/ocaml/ocaml/pull/8897";
 skip;
>>>>>>> 18bd88faf2 (New script language for ocamltest (PR#12185))
*)

external test : int ref -> unit = "stub"

let f () =
  let r = ref 42 in
  Gc.finalise (fun s -> r := !s) (ref 17);
  Printf.printf "OCaml, before: %d\n%!" !r;
  test r;
  Printf.printf "OCaml, after: %d\n%!" !r;
  ignore (Sys.opaque_identity (ref 100));
  Printf.printf "OCaml, after alloc: %d\n%!" !r;
  ()

let () = (f [@inlined never]) ()
