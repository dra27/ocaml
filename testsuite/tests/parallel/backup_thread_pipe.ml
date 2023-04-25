(* TEST
<<<<<<< HEAD
* skip
reason = "OCaml 5 only"
** hasunix
include unix
*** bytecode
*** native
||||||| parent of 18bd88faf2 (New script language for ocamltest (PR#12185))
* hasunix
include unix
** bytecode
** native
=======
 include unix;
 hasunix;
 {
   bytecode;
 }{
   native;
 }
>>>>>>> 18bd88faf2 (New script language for ocamltest (PR#12185))
*)


let producer oc = output_string oc "passed\n"; close_out oc

let consumer ic = print_endline @@ input_line ic; close_in ic

let main () =
  let (in_fd, out_fd) = Unix.pipe() in
  let ipipe = Unix.in_channel_of_descr in_fd in
  let opipe = Unix.out_channel_of_descr out_fd in
  let prod = Domain.spawn (fun () -> Unix.sleep 3; Gc.full_major(); producer opipe) in
  let cons = Domain.spawn (fun () -> consumer ipipe) in
  Domain.join prod;
  Domain.join cons

let _ = Unix.handle_unix_error main (); exit 0
