(* TEST
 readonly_files = "test_functor.ml test_loc_modtype_type_eq.ml \
   test_loc_modtype_type_subst.ml test_loc_type_eq.ml test_loc_type_subst.ml \
   mpr7852.mli";
 setup-ocamlc.byte-build-env;
 {
   module = "test_functor.ml";
   ocamlc.byte;
 }{
   module = "test_loc_type_eq.ml";
   ocamlc_byte_exit_status = "2";
   ocamlc.byte;
 }{
   module = "test_loc_modtype_type_eq.ml";
   ocamlc_byte_exit_status = "2";
   ocamlc.byte;
 }{
   module = "test_loc_type_subst.ml";
   ocamlc_byte_exit_status = "2";
   ocamlc.byte;
 }{
   module = "test_loc_modtype_type_subst.ml";
   ocamlc_byte_exit_status = "2";
   ocamlc.byte;
 }{
   check-ocamlc.byte-output;
 }{
   flags = "-w +32";
   module = "mpr7852.mli";
   ocamlc_byte_exit_status = "0";
   ocamlc.byte;
 }{
   check-ocamlc.byte-output;
 }
*)
