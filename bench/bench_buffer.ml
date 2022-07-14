(* Boring benchmark code *)
let benchmark_std n =
  let buf = Buffer.create 1 in
  for _ = 1 to n do
    Buffer.reset buf;
    for _ = 1 to 1050 do
      Buffer.add_char buf 'a';
    done;
  done

let benchmark_std_nospill n =
  let buf = Buffer.create 1 in
  for _ = 1 to n do
    Buffer.reset buf;
    for _ = 1 to 1050 do
      Buffer.add_char_std_nospill buf 'a';
    done;
  done

let benchmark_std_string n =
  let buf = Buffer.create 1 in
  for _ = 1 to n do
    Buffer.reset buf;
    for _ = 1 to 1050 do
      Buffer.add_string buf "aaaa";
    done;
  done

let benchmark_std_string_nospill n =
  let buf = Buffer.create 1 in
  for _ = 1 to n do
    Buffer.reset buf;
    for _ = 1 to 1050 do
      Buffer.add_string_std_nospill buf "aaaa";
    done;
  done

let impls = [
  (* standard code, the latter tuned manually to avoid spilling *)
  "std", benchmark_std;
  "std_nospill", benchmark_std_nospill;

  "std_add_string", benchmark_std_string;
  "std_add_string_nospill", benchmark_std_string_nospill
]

let () =
  Printf.eprintf "usage: %s <niter> [%s]\n%!"
    Sys.argv.(0)
    (String.concat " | " (List.map fst impls));
  let niter = int_of_string Sys.argv.(1) in
  let impl = List.assoc Sys.argv.(2) impls in
  ignore (impl niter)
