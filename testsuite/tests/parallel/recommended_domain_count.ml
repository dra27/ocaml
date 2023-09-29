(* TEST
 modules = "recommended_domain_count_cstubs.c";
 reason = "OCaml 5 only";
 skip;
*)

external get_max_domains : unit -> int = "caml_get_max_domains"

let _ =
  assert (Domain.recommended_domain_count () > 0);
  assert (Domain.recommended_domain_count () <= (get_max_domains ()));
  print_string "passed\n"
