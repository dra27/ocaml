/**************************************************************************/
/*                                                                        */
/*                                 OCaml                                  */
/*                                                                        */
/*             Xavier Leroy, projet Cristal, INRIA Rocquencourt           */
/*                                                                        */
/*   Copyright 1999 Institut National de Recherche en Informatique et     */
/*     en Automatique.                                                    */
/*                                                                        */
/*   All rights reserved.  This file is distributed under the terms of    */
/*   the GNU Lesser General Public License version 2.1, with the          */
/*   special exception on linking described in the file LICENSE.          */
/*                                                                        */
/**************************************************************************/

#define CAML_INTERNALS
#include "caml/builtin_exns.h"
#include "primitives.h"

#define EXN_NAME(c_name, ocaml_name) #ocaml_name;
let builtin_exceptions = [|
  CAML_BUILTIN_EXCEPTIONS(EXN_NAME)
|]

#define PRIMITIVE_NAME(name) #name;
let builtin_primitives = [|
  CAML_RUNTIME_PRIMITIVES(PRIMITIVE_NAME)
|]
