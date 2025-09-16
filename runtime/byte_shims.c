/**************************************************************************/
/*                                                                        */
/*                                 OCaml                                  */
/*                                                                        */
/*                  Shims for bytecode-only builds                       */
/*                                                                        */
/*   Copyright 2024 Institut National de Recherche en Informatique et    */
/*     en Automatique.                                                    */
/*                                                                        */
/*   All rights reserved.  This file is distributed under the terms of    */
/*   the GNU Lesser General Public License version 2.1, with the          */
/*   special exception on linking described in the file LICENSE.          */
/*                                                                        */
/**************************************************************************/

/* This file provides dummy symbols for functions that are referenced by
   assembly code but are only meaningful in native code compilation.
   These are needed when assembly stubs are included in the bytecode runtime
   for unified callback support. */

#define CAML_INTERNALS

#include "caml/mlvalues.h"
#include "caml/fail.h"

/* These are OCaml functions that only exist in native code.
   They should never be called in bytecode mode. */

value caml_apply2(value, value, value) {
  caml_fatal_error("caml_apply2: should not be called in bytecode mode");
  return Val_unit;
}

value caml_apply3(value, value, value, value) {
  caml_fatal_error("caml_apply3: should not be called in bytecode mode");
  return Val_unit;
}

value caml_program(value) {
  caml_fatal_error("caml_program: should not be called in bytecode mode");
  return Val_unit;
}

value caml_exn_Stack_overflow = Val_unit;

value caml_array_bound_error_asm(void) {
  caml_fatal_error("caml_array_bound_error_asm: should not be called in bytecode mode");
  return Val_unit;
}

void caml_garbage_collection(void) {
  caml_fatal_error("caml_garbage_collection: should not be called in bytecode mode");
}