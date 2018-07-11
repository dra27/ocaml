(* TEST
   * setup-ocamlopt.byte-build-env
   ** ocamlopt.byte
      flags = "-c -dcmm -dno-unique-ids"
   *** check-ocamlopt.byte-output
*)

let optim_int (x : int) (y : int) =
  compare x y <= 0,
  compare x y <  0,
  compare x y >= 0,
  compare x y >  0,
  compare x y =  0,
  compare x y <> 0

let optim_int32 (x : int32) (y : int32) =
  compare x y <= 0,
  compare x y <  0,
  compare x y >= 0,
  compare x y >  0,
  compare x y =  0,
  compare x y <> 0

let optim_int64 (x : int64) (y : int64) =
  compare x y <= 0,
  compare x y <  0,
  compare x y >= 0,
  compare x y >  0,
  compare x y =  0,
  compare x y <> 0

let optim_nativeint (x : nativeint) (y : nativeint) =
  compare x y <= 0,
  compare x y <  0,
  compare x y >= 0,
  compare x y >  0,
  compare x y =  0,
  compare x y <> 0
