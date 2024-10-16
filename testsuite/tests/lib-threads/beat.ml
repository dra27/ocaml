(* TEST
 include systhreads;
 hassysthreads;
 {
   bytecode;
 }{
   native;
 }
*)

(* Test Thread.delay and its scheduling *)

open Printf

let tick (delay, count) =
  while true do
    let start = Unix.gettimeofday () in
    Thread.delay delay;
    count := !count +. (Unix.gettimeofday () -. start)
  done

let within reading expected tick tolerance =
  let delta = tick *. (1.0 +. tolerance) in
  reading >= expected -. delta && reading <= expected +. delta

let _ =
  let c1 = ref 0.0 and c2 = ref 0.0 in
  let tick1 = 0.333333333 and tick2 = 0.5 in
  let start = Unix.gettimeofday () in
  ignore (Thread.create tick (tick1, c1));
  ignore (Thread.create tick (tick2, c2));
  Thread.delay 3.0;
  let d = Unix.gettimeofday () -. start
  and d1 = !c1 and d2 = !c2 in
  let tolerance = 0.5 in
  if within d1 d tick1 tolerance && within d2 d tick2 tolerance
  then printf "passed\n"
  else printf "FAILED (d = %f, d1 = %f, d2 = %f)\n" d d1 d2
