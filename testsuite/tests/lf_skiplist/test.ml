(* TEST
<<<<<<< HEAD
   modules = "stubs.c"
   * skip
   reason = "OCaml 5 only"
||||||| parent of 18bd88faf2 (New script language for ocamltest (PR#12185))
   modules = "stubs.c"
=======
 modules = "stubs.c";
>>>>>>> 18bd88faf2 (New script language for ocamltest (PR#12185))
*)

external test_skiplist_serial : unit -> unit = "test_skiplist_serial"

let () = test_skiplist_serial ()

external init_skiplist : unit -> unit = "init_skiplist"
external insert_skiplist : int -> int -> int -> unit = "insert_skiplist"
external find_skiplist : int -> int -> int -> bool = "find_skiplist"
external clean_skiplist : int -> unit = "clean_skiplist"
external cardinal_skiplist : unit -> int = "cardinal_skiplist"

let () =
  let nturns = 128
  and nseq = 4 in
  assert (nturns < 1024); (* See calc_key in stubs.c *)
  init_skiplist ();
  for i=1 to nseq do
    for k = 1 to nturns do
      insert_skiplist k 1 0
    done ;
    assert(cardinal_skiplist () = nturns) ;
    for k = 1 to nturns do
      assert(find_skiplist k 1 0)
    done ;
    assert(cardinal_skiplist () = 0) ;
    clean_skiplist nturns
  done
