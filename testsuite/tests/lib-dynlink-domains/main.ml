(* TEST

include dynlink
libraries = ""
readonly_files = "store.ml main.ml Plugin_0.ml Plugin_0_0.ml Plugin_0_0_0.ml Plugin_0_0_0_0.ml Plugin_0_0_0_1.ml Plugin_0_0_0_2.ml Plugin_1.ml Plugin_1_0.ml Plugin_1_0_0.ml Plugin_1_0_0_0.ml Plugin_1_1.ml Plugin_1_2.ml Plugin_1_2_0.ml Plugin_1_2_0_0.ml Plugin_1_2_1.ml Plugin_1_2_2.ml Plugin_1_2_2_0.ml Plugin_1_2_3.ml Plugin_1_2_3_0.ml"

<<<<<<< HEAD
* skip
reason = "OCaml 5 only"
**01 shared-libraries
**02 setup-ocamlc.byte-build-env
**03 ocamlc.byte
module = "store.ml"
**04 ocamlc.byte
module = "Plugin_0.ml"
**05 ocamlc.byte
module = "Plugin_0_0.ml"
**06 ocamlc.byte
module = "Plugin_0_0_0.ml"
**07 ocamlc.byte
module = "Plugin_0_0_0_0.ml"
**08 ocamlc.byte
module = "Plugin_0_0_0_1.ml"
**09 ocamlc.byte
module = "Plugin_0_0_0_2.ml"
**10 ocamlc.byte
module = "Plugin_1.ml"
**11 ocamlc.byte
module = "Plugin_1_0.ml"
**12 ocamlc.byte
module = "Plugin_1_0_0.ml"
**13 ocamlc.byte
module = "Plugin_1_0_0_0.ml"
**14 ocamlc.byte
module = "Plugin_1_1.ml"
**15 ocamlc.byte
module = "Plugin_1_2.ml"
**16 ocamlc.byte
module = "Plugin_1_2_0.ml"
**17 ocamlc.byte
module = "Plugin_1_2_0_0.ml"
**18 ocamlc.byte
module = "Plugin_1_2_1.ml"
**19 ocamlc.byte
module = "Plugin_1_2_2.ml"
**20 ocamlc.byte
module = "Plugin_1_2_2_0.ml"
**21 ocamlc.byte
module = "Plugin_1_2_3.ml"
**22 ocamlc.byte
module = "Plugin_1_2_3_0.ml"
**23 ocamlc.byte
module = "main.ml"
**24 ocamlc.byte
||||||| parent of 8837d9bbf1 (Merge pull request PR#11607 from dra27/disable-dynlink-domains-windows)
*01 shared-libraries
*02 setup-ocamlc.byte-build-env
*03 ocamlc.byte
module = "store.ml"
*04 ocamlc.byte
module = "Plugin_0.ml"
*05 ocamlc.byte
module = "Plugin_0_0.ml"
*06 ocamlc.byte
module = "Plugin_0_0_0.ml"
*07 ocamlc.byte
module = "Plugin_0_0_0_0.ml"
*08 ocamlc.byte
module = "Plugin_0_0_0_1.ml"
*09 ocamlc.byte
module = "Plugin_0_0_0_2.ml"
*10 ocamlc.byte
module = "Plugin_1.ml"
*11 ocamlc.byte
module = "Plugin_1_0.ml"
*12 ocamlc.byte
module = "Plugin_1_0_0.ml"
*13 ocamlc.byte
module = "Plugin_1_0_0_0.ml"
*14 ocamlc.byte
module = "Plugin_1_1.ml"
*15 ocamlc.byte
module = "Plugin_1_2.ml"
*16 ocamlc.byte
module = "Plugin_1_2_0.ml"
*17 ocamlc.byte
module = "Plugin_1_2_0_0.ml"
*18 ocamlc.byte
module = "Plugin_1_2_1.ml"
*19 ocamlc.byte
module = "Plugin_1_2_2.ml"
*20 ocamlc.byte
module = "Plugin_1_2_2_0.ml"
*21 ocamlc.byte
module = "Plugin_1_2_3.ml"
*22 ocamlc.byte
module = "Plugin_1_2_3_0.ml"
*23 ocamlc.byte
module = "main.ml"
*24 ocamlc.byte
=======
*01 not-windows
*02 shared-libraries
*03 setup-ocamlc.byte-build-env
*04 ocamlc.byte
module = "store.ml"
*05 ocamlc.byte
module = "Plugin_0.ml"
*06 ocamlc.byte
module = "Plugin_0_0.ml"
*07 ocamlc.byte
module = "Plugin_0_0_0.ml"
*08 ocamlc.byte
module = "Plugin_0_0_0_0.ml"
*09 ocamlc.byte
module = "Plugin_0_0_0_1.ml"
*10 ocamlc.byte
module = "Plugin_0_0_0_2.ml"
*11 ocamlc.byte
module = "Plugin_1.ml"
*12 ocamlc.byte
module = "Plugin_1_0.ml"
*13 ocamlc.byte
module = "Plugin_1_0_0.ml"
*14 ocamlc.byte
module = "Plugin_1_0_0_0.ml"
*15 ocamlc.byte
module = "Plugin_1_1.ml"
*16 ocamlc.byte
module = "Plugin_1_2.ml"
*17 ocamlc.byte
module = "Plugin_1_2_0.ml"
*18 ocamlc.byte
module = "Plugin_1_2_0_0.ml"
*19 ocamlc.byte
module = "Plugin_1_2_1.ml"
*20 ocamlc.byte
module = "Plugin_1_2_2.ml"
*21 ocamlc.byte
module = "Plugin_1_2_2_0.ml"
*22 ocamlc.byte
module = "Plugin_1_2_3.ml"
*23 ocamlc.byte
module = "Plugin_1_2_3_0.ml"
*24 ocamlc.byte
module = "main.ml"
*25 ocamlc.byte
>>>>>>> 8837d9bbf1 (Merge pull request PR#11607 from dra27/disable-dynlink-domains-windows)
program = "./main.byte.exe"
libraries= "dynlink"
all_modules = "store.cmo main.cmo"
module = ""
<<<<<<< HEAD
**25 run
**26 check-program-output
||||||| parent of 8837d9bbf1 (Merge pull request PR#11607 from dra27/disable-dynlink-domains-windows)
*25 run
*26 check-program-output
=======
*26 run
*27 check-program-output
>>>>>>> 8837d9bbf1 (Merge pull request PR#11607 from dra27/disable-dynlink-domains-windows)

**02 native-dynlink
**03 setup-ocamlopt.byte-build-env
**04 ocamlopt.byte
flags = ""
module = "store.ml"
**05 ocamlopt.byte
flags = "-shared"
program= "Plugin_0.cmxs"
module = ""
all_modules = "Plugin_0.ml"
**06 ocamlopt.byte
flags = "-shared"
program= "Plugin_0_0.cmxs"
module = ""
all_modules = "Plugin_0_0.ml"
**07 ocamlopt.byte
flags = "-shared"
program= "Plugin_0_0_0.cmxs"
module = ""
all_modules = "Plugin_0_0_0.ml"
**08 ocamlopt.byte
flags = "-shared"
program= "Plugin_0_0_0_0.cmxs"
module = ""
all_modules = "Plugin_0_0_0_0.ml"
**09 ocamlopt.byte
flags = "-shared"
program= "Plugin_0_0_0_1.cmxs"
module = ""
all_modules = "Plugin_0_0_0_1.ml"
**10 ocamlopt.byte
flags = "-shared"
program= "Plugin_0_0_0_2.cmxs"
module = ""
all_modules = "Plugin_0_0_0_2.ml"
**11 ocamlopt.byte
flags = "-shared"
program= "Plugin_1.cmxs"
module = ""
all_modules = "Plugin_1.ml"
**12 ocamlopt.byte
flags = "-shared"
program= "Plugin_1_0.cmxs"
module = ""
all_modules = "Plugin_1_0.ml"
**13 ocamlopt.byte
flags = "-shared"
program= "Plugin_1_0_0.cmxs"
module = ""
all_modules = "Plugin_1_0_0.ml"
**14 ocamlopt.byte
flags = "-shared"
program= "Plugin_1_0_0_0.cmxs"
module = ""
all_modules = "Plugin_1_0_0_0.ml"
**15 ocamlopt.byte
flags = "-shared"
program= "Plugin_1_1.cmxs"
module = ""
all_modules = "Plugin_1_1.ml"
**16 ocamlopt.byte
flags = "-shared"
program= "Plugin_1_2.cmxs"
module = ""
all_modules = "Plugin_1_2.ml"
**17 ocamlopt.byte
flags = "-shared"
program= "Plugin_1_2_0.cmxs"
module = ""
all_modules = "Plugin_1_2_0.ml"
**18 ocamlopt.byte
flags = "-shared"
program= "Plugin_1_2_0_0.cmxs"
module = ""
all_modules = "Plugin_1_2_0_0.ml"
**19 ocamlopt.byte
flags = "-shared"
program= "Plugin_1_2_1.cmxs"
module = ""
all_modules = "Plugin_1_2_1.ml"
**20 ocamlopt.byte
flags = "-shared"
program= "Plugin_1_2_2.cmxs"
module = ""
all_modules = "Plugin_1_2_2.ml"
**21 ocamlopt.byte
flags = "-shared"
program= "Plugin_1_2_2_0.cmxs"
module = ""
all_modules = "Plugin_1_2_2_0.ml"
**22 ocamlopt.byte
flags = "-shared"
program= "Plugin_1_2_3.cmxs"
module = ""
all_modules = "Plugin_1_2_3.ml"
**23 ocamlopt.byte
flags = "-shared"
program= "Plugin_1_2_3_0.cmxs"
module = ""
all_modules = "Plugin_1_2_3_0.ml"
**24 ocamlopt.byte
flags = ""
module = "main.ml"
**25 ocamlopt.byte
program = "./main.exe"
libraries="dynlink"
all_modules = "store.cmx main.cmx"
module = ""
**26 run
**27 check-program-output
*)

(*  This module and all plugin modules are generated by a call to test_generator.ml with parameters:
seed=25, width=8, depth=4, nlinks=4, introns=8, childs=2, domains=12.
*)
(* Link plugins *)
let d0 = Domain.spawn (fun () -> Dynlink.loadfile @@ Dynlink.adapt_filename "Plugin_0.cmo")
let sqrt2 =
  let rec find c =
    if Float.abs (c *. c -. 2.) < 1e-3 then c
    else find ((c *. c +. 2.) /. (2. *. c))
  in find 0x1.169495039333ap+1
let wordy = "This" ^ "is" ^ "a" ^ "very" ^ "useful" ^ "code" ^ "fragment: 617." ^ "That's all"
let sqrt2 =
  let rec find c =
    if Float.abs (c *. c -. 2.) < 1e-3 then c
    else find ((c *. c +. 2.) /. (2. *. c))
  in find 0x1.5e02683439a8ap-1
let sqrt2 =
  let rec find c =
    if Float.abs (c *. c -. 2.) < 1e-3 then c
    else find ((c *. c +. 2.) /. (2. *. c))
  in find 0x1.26dadad08db5dp+0
let d1 = Domain.spawn (fun () -> Dynlink.loadfile @@ Dynlink.adapt_filename "Plugin_1.cmo")
let sqrt2 =
  let rec find c =
    if Float.abs (c *. c -. 2.) < 1e-3 then c
    else find ((c *. c +. 2.) /. (2. *. c))
  in find 0x1.22505223b655ap+0
let sqrt2 =
  let rec find c =
    if Float.abs (c *. c -. 2.) < 1e-3 then c
    else find ((c *. c +. 2.) /. (2. *. c))
  in find 0x1.2275ac3e51895p-1
let () = Domain.join d0
let wordy = "This" ^ "is" ^ "a" ^ "very" ^ "useful" ^ "code" ^ "fragment: 352." ^ "That's all"
let sqrt2 =
  let rec find c =
    if Float.abs (c *. c -. 2.) < 1e-3 then c
    else find ((c *. c +. 2.) /. (2. *. c))
  in find 0x1.249bde9d3b93ep+2
let () = Store.add "[]->[]"
let () = Store.add "[]->[]"
let () = Domain.join d1
let add x = Store.add x
let () = Store.add "[]->[]"
let () = Store.add "[]->[]"

(* Print result *)

module String_set = Set.Make(String)
let stored = Atomic.get Store.store
let stored_set = String_set.of_list stored
let () =
  List.iter (Printf.printf "%s\n") (String_set.elements stored_set)
