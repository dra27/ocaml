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

#define CAML_INTERNALS

#include <errno.h>
#include <string.h>
#include <caml/alloc.h>
#include <caml/sys.h>
#include "unixsupport.h"

CAMLprim value unix_error_message(value err)
{
  char buf[1024];
  int errnum = unix_code_of_unix_error(err);
  return caml_copy_string(caml_strerror(errnum, buf, sizeof(buf)));
}
