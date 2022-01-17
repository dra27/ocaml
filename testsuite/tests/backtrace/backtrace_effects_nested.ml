(* TEST
<<<<<<< HEAD
   flags = "-g"
   * skip
   reason = "OCaml 5 only"
||||||| parent of 118f54bd63 (Merge pull request PR#10909 from lthls/multicore-flambda-testsuite-fixes)
   flags = "-g"
=======

flags = "-g"
* bytecode
* no-flambda
** native
* flambda
reference = "${test_source_directory}/backtrace_effects_nested.flambda.reference"
** native

>>>>>>> 118f54bd63 (Merge pull request PR#10909 from lthls/multicore-flambda-testsuite-fixes)
*)

open Effect
open Effect.Deep

type _ eff += E : unit eff
            | Inc : unit eff

let blorp () =
  perform Inc;
  perform E;
  42

let baz () =
    try_with blorp ()
    { effc = fun (type a) (e : a eff) ->
        match e with
        | Inc -> Some (fun (k : (a, _) continuation) ->
            1 + continue k ())
        | _ -> None }

let f () =
  match_with baz ()
  { retc = (fun x -> Printf.printf "%d\n" x);
    exnc = (fun e -> raise e);
    effc = fun (type a) (e : a eff) ->
          match e with
          | E -> Some (fun (k : (a, _) continuation) ->
              Deep.get_callstack k 100 |>
              Printexc.raw_backtrace_to_string |>
              print_string;
              continue k ())
          | _ -> None }

let () = f ()
