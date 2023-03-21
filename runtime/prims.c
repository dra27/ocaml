/**************************************************************************/
/*                                                                        */
/*                                 OCaml                                  */
/*                                                                        */
/*            Xavier Leroy, projet Cristal, INRIA Rocquencourt            */
/*                                                                        */
/*   Copyright 1999 Institut National de Recherche en Informatique et     */
/*     en Automatique.                                                    */
/*                                                                        */
/*   All rights reserved.  This file is distributed under the terms of    */
/*   the GNU Lesser General Public License version 2.1, with the          */
/*   special exception on linking described in the file LICENSE.          */
/*                                                                        */
/**************************************************************************/

#include "caml/config.h"
#include "primitives.h"

typedef intnat value;
typedef value (*c_primitive)(void);

#define PRIMITIVE_DECLARATION(NAME) extern value NAME(void);
CAML_RUNTIME_PRIMITIVES(PRIMITIVE_DECLARATION)

#define PRIMITIVE_SYMBOL(NAME) NAME,
c_primitive caml_builtin_cprim[] = {
  CAML_RUNTIME_PRIMITIVES(PRIMITIVE_SYMBOL)
  0 };

#define PRIMITIVE_NAME(NAME) #NAME,
char * caml_names_of_builtin_cprim[] = {
  CAML_RUNTIME_PRIMITIVES(PRIMITIVE_NAME)
  0 };
