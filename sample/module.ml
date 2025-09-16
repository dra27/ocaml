let () =
  Parent.register ();
  let mode = match Sys.backend_type with Native -> "native" | Bytecode -> "bytecode" | Other _ -> "other" in
  Stdlib__Printf.fprintf stdout "Plugin-specific call (%s)\n%!" mode
