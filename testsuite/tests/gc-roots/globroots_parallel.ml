(* TEST
<<<<<<< HEAD
   flags += " -w a "
   modules = "globrootsprim.c globroots.ml"
   * skip
   reason = "OCaml 5 only"
||||||| parent of 18bd88faf2 (New script language for ocamltest (PR#12185))
   flags += " -w a "
   modules = "globrootsprim.c globroots.ml"
=======
 flags += " -w a ";
 modules = "globrootsprim.c globroots.ml";
>>>>>>> 18bd88faf2 (New script language for ocamltest (PR#12185))
*)

open Globroots

let test_size =
  try int_of_string (Sys.getenv "OCAML_TEST_SIZE")
  with Not_found | Failure _ -> 0

let num_domains =
  match test_size with
  | 3 -> 8
  | 2 -> 4
  | _ -> print_string "ok\n"; exit 0

let n = 125

let _ =
  let domains = Array.init (num_domains - 1) (fun _ ->
    Domain.spawn(fun () ->
      let module TestClassic = Test(Classic) () in
      let module TestGenerational = Test(Generational) () in
      TestClassic.test n;
      TestGenerational.test n)) in
  young2old (); Gc.full_major ();
  assert (static2young (1, 1) Gc.full_major == 0x42);
  TestClassic.test n;
  TestGenerational.test n;
  Array.iter Domain.join domains;
  print_string "ok\n"
