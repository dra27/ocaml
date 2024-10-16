(* TEST
 include systhreads;
 hassysthreads;
 readonly_files = "timed_delay.c";
 script = "sh ${test_source_directory}/has-nanosleep.sh";
 script;
 {
   setup-ocamlc.byte-build-env;
   all_modules = "timed_delay.c beat.ml";
   ocamlc.byte;
   output = "${test_build_directory}/program-output";
   stdout = "${output}";
   run;
   check-program-output;
 }{
   setup-ocamlopt.byte-build-env;
   all_modules = "timed_delay.c beat.ml";
   ocamlopt.byte;
   output = "${test_build_directory}/program-output";
   stdout = "${output}";
   run;
   check-program-output;
 }
*)

(* Test Thread.delay and its scheduling *)

external timed_delay : float -> float = "caml_thread_timed_delay"

open Printf

let tick (delay, count) =
  while true do
    count := !count +. timed_delay delay;
  done

let within reading expected tick tolerance =
  let delta = tick *. (1.0 +. tolerance) in
  reading >= expected -. delta && reading <= expected +. delta

let _ =
  let c1 = ref 0.0 and c2 = ref 0.0 in
  let tick1 = 0.333333333 and tick2 = 0.5 in
  ignore (Thread.create tick (tick1, c1));
  ignore (Thread.create tick (tick2, c2));
  let d = timed_delay 3.0 in
  let d1 = !c1 and d2 = !c2 in
  let tolerance = 0.5 in
  if within d1 d tick1 tolerance && within d2 d tick2 tolerance
  then printf "passed\n"
  else printf "FAILED (d = %f, d1 = %f, d2 = %f)\n" d d1 d2
