/**************************************************************************/
/*                                                                        */
/*                                 OCaml                                  */
/*                                                                        */
/*                  Shims for native-only builds                         */
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
   unified callback code but are only meaningful in bytecode compilation.
   These are needed when unified callback support is included in the native runtime. */

#define CAML_INTERNALS

#include "caml/mlvalues.h"
#include "caml/fail.h"

/* These are bytecode functions that only exist in bytecode mode.
   They should never be called in native-only mode. */

value caml_bytecode_interpreter(void* prog, asize_t prog_size, value cont) {
  caml_fatal_error("caml_bytecode_interpreter: should not be called in native-only mode");
  return Val_unit;
}

value caml_thread_code(void* prog, asize_t prog_size) {
  caml_fatal_error("caml_thread_code: should not be called in native-only mode");
  return Val_unit;
}