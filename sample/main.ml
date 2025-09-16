let () =
  Printf.printf "Loading plugin...\n%!";
  Dynlink.loadfile (Dynlink.adapt_filename "plugin.cma");
  Printf.printf "Plugin loaded successfully!\n%!"
