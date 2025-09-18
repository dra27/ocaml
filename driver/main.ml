let main () =
  exit (Maindriver.main Sys.argv Format.err_formatter)

let () =
  Compmisc.with_standard_handlers main ()
