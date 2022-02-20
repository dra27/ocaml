(* TEST
   include unix
   modules = "callbackprim.c"
   * libunix
   ** bytecode
   ** native
*)

(**************************************************************************)

external mycallback1 : ('a -> 'b) -> 'a -> 'b = "mycallback1"
external mycallback2 : ('a -> 'b -> 'c) -> 'a -> 'b -> 'c = "mycallback2"
external mycallback3 : ('a -> 'b -> 'c -> 'd) -> 'a -> 'b -> 'c -> 'd
    = "mycallback3"
external mycallback4 :
    ('a -> 'b -> 'c -> 'd -> 'e) -> 'a -> 'b -> 'c -> 'd -> 'e = "mycallback4"

let rec tak (x, y, z as _tuple) =
  if x > y then tak(tak (x-1, y, z), tak (y-1, z, x), tak (z-1, x, y))
           else z

let tak2 x (y, z) = tak (x, y, z)

let tak3 x y z = tak (x, y, z)

let tak4 x y z u = tak (x, y, z + u)

let raise_exit () = (raise Exit : unit)

let trapexit () =
  begin try
    mycallback1 raise_exit ()
  with Exit ->
    ()
  end;
  tak (18, 12, 6)

external mypushroot : 'a -> ('b -> 'c) -> 'b -> 'a = "mypushroot"
external mycamlparam : 'a -> ('b -> 'c) -> 'b -> 'a = "mycamlparam"

let tripwire f =
  let s = String.make 5 'a' in
  f s trapexit ()

(* Test callbacks performed to handle signals *)

let sighandler signo =
(*
  print_string "Got signal, triggering garbage collection...";
  print_newline();
*)
  (* Thoroughly wipe the minor heap *)
  ignore (tak (18, 12, 6))

<<<<<<< HEAD
external raise_sigusr1 : unit -> unit = "raise_sigusr1" [@@noalloc]
external unix_getpid : unit -> int = "unix_getpid" [@@noalloc]
external unix_kill : int -> int -> unit = "unix_kill" [@@noalloc]
||||||| parent of c2679e876e (Merge pull request PR#11033 from xavierleroy/fix-test-signalhandler)
external unix_getpid : unit -> int = "unix_getpid" [@@noalloc]
external unix_kill : int -> int -> unit = "unix_kill" [@@noalloc]
=======
external mykill : int -> int -> unit = "mykill" [@@noalloc]
>>>>>>> c2679e876e (Merge pull request PR#11033 from xavierleroy/fix-test-signalhandler)

let callbacksig () =
<<<<<<< HEAD
  let _pid = unix_getpid() in
||||||| parent of c2679e876e (Merge pull request PR#11033 from xavierleroy/fix-test-signalhandler)
  let pid = unix_getpid() in
=======
  let pid = Unix.getpid () in
>>>>>>> c2679e876e (Merge pull request PR#11033 from xavierleroy/fix-test-signalhandler)
  (* Allocate a block in the minor heap *)
  let s = String.make 5 'b' in
  (* Send a signal to self.  We want s to remain in a register and
<<<<<<< HEAD
     not be spilled on the stack, hence we declare unix_kill
     [@@noalloc]. *)
  (*unix_kill pid Sys.sigusr1;*)
  raise_sigusr1 ();
||||||| parent of c2679e876e (Merge pull request PR#11033 from xavierleroy/fix-test-signalhandler)
     not be spilled on the stack, hence we declare unix_kill
     [@@noalloc]. *)
  unix_kill pid Sys.sigusr1;
=======
     not be spilled on the stack, hence we use [mykill]
     (which is [@@noalloc] and doesn't trigger signal handling)
     instead of [Unix.kill]. *)
  mykill pid Sys.sigusr1;
>>>>>>> c2679e876e (Merge pull request PR#11033 from xavierleroy/fix-test-signalhandler)
  (* Allocate some more so that the signal will be tested *)
  let u = (s, s) in
  fst u

let _ =
  print_int(mycallback1 tak (18, 12, 6)); print_newline();
  print_int(mycallback2 tak2 18 (12, 6)); print_newline();
  print_int(mycallback3 tak3 18 12 6); print_newline();
  print_int(mycallback4 tak4 18 12 3 3); print_newline();
  print_int(trapexit ()); print_newline();
  print_string(tripwire mypushroot); print_newline();
  print_string(tripwire mycamlparam); print_newline();
  Sys.set_signal Sys.sigusr1 (Sys.Signal_handle sighandler);
  print_string(callbacksig ()); print_newline()
