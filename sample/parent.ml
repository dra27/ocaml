let register () =
  let mode = match Sys.backend_type with Native -> "native" | Bytecode -> "bytecode" | Other _ -> "other" in
  Printf.printf "Hello, from dynamically loaded plugin (%s)\n%!" mode
