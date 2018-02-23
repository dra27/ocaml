/**************************************************************************/
/*                                                                        */
/*                                 OCaml                                  */
/*                                                                        */
/*             Xavier Leroy, projet Cristal, INRIA Rocquencourt           */
/*                                                                        */
/*   Copyright 2000 Institut National de Recherche en Informatique et     */
/*     en Automatique.                                                    */
/*                                                                        */
/*   All rights reserved.  This file is distributed under the terms of    */
/*   the GNU Lesser General Public License version 2.1, with the          */
/*   special exception on linking described in the file LICENSE.          */
/*                                                                        */
/**************************************************************************/

/* Dynamic loading of C primitives. */

#ifndef CAML_DYNLINK_H
#define CAML_DYNLINK_H

#ifdef CAML_INTERNALS

#include "misc.h"

/* Build the table of primitives, given a search path, a list
   of shared libraries, and a list of primitive names
   (all three 0-separated in char arrays).
   Abort the runtime system on error.
   Calling this frees caml_shared_libs_path (not touching its contents). */
void caml_build_primitive_table(char_os * lib_path,
                                char_os * libs,
                                char * req_prims);

/* The search path for shared libraries */
CAMLdata struct ext_table caml_shared_libs_path;

/* Build the table of primitives as a copy of the builtin primitive table.
   Used for executables generated by ocamlc -output-obj. */
void caml_build_primitive_table_builtin(void);

/* Unload all the previously loaded shared libraries */
void caml_free_shared_libs(void);

#endif /* CAML_INTERNALS */

#endif /* CAML_DYNLINK_H */
