/**************************************************************************/
/*                                                                        */
/*                                 OCaml                                  */
/*                                                                        */
/*             Xavier Leroy, projet Cristal, INRIA Rocquencourt           */
/*                                                                        */
/*   Copyright 1996 Institut National de Recherche en Informatique et     */
/*     en Automatique.                                                    */
/*                                                                        */
/*   All rights reserved.  This file is distributed under the terms of    */
/*   the GNU Lesser General Public License version 2.1, with the          */
/*   special exception on linking described in the file LICENSE.          */
/*                                                                        */
/**************************************************************************/

#ifndef CAML_BUILTIN_EXNS_H
#define CAML_BUILTIN_EXNS_H

#ifdef CAML_INTERNALS

/* Built-in exceptions. */

#define CAML_BUILTIN_EXCEPTIONS(EXN) \
  EXN(OUT_OF_MEMORY_EXN, Out_of_memory) \
  EXN(SYS_ERROR_EXN, Sys_error) \
  EXN(FAILURE_EXN, Failure) \
  EXN(INVALID_EXN, Invalid_argument) \
  EXN(END_OF_FILE_EXN, End_of_file) \
  EXN(ZERO_DIVIDE_EXN, Division_by_zero) \
  EXN(NOT_FOUND_EXN, Not_found) \
  EXN(MATCH_FAILURE_EXN, Match_failure) \
  EXN(STACK_OVERFLOW_EXN, Stack_overflow) \
  EXN(SYS_BLOCKED_IO, Sys_blocked_io) \
  EXN(ASSERT_FAILURE_EXN, Assert_failure) \
  EXN(UNDEFINED_RECURSIVE_MODULE_EXN, Undefined_recursive_module)

#endif /* CAML_INTERNALS */

#endif /* CAML_OPCODES_H */
