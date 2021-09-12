/**************************************************************************/
/*                                                                        */
/*                                 OCaml                                  */
/*                                                                        */
/*                         The OCaml programmers                          */
/*                                                                        */
/*   Copyright 2020 Institut National de Recherche en Informatique et     */
/*     en Automatique.                                                    */
/*                                                                        */
/*   All rights reserved.  This file is distributed under the terms of    */
/*   the GNU Lesser General Public License version 2.1, with the          */
/*   special exception on linking described in the file LICENSE.          */
/*                                                                        */
/**************************************************************************/

#include <caml/mlvalues.h>
#include <caml/memory.h>
#include <caml/alloc.h>
#include <caml/fail.h>
#define CAML_INTERNALS
#include <caml/osdeps.h>
#include "unixsupport.h"

#if defined(HAS_REALPATH) || defined(_WIN32)

CAMLprim value unix_realpath (value p)
{
  CAMLparam1(p);
  CAMLlocal1(res);
  char_os *resolved;
  char_os *path;

  caml_unix_check_path(p, "realpath");
  path = caml_stat_strdup_to_os(String_val(p));
  resolved = caml_realpath(path);
  caml_stat_free(path);
  if (resolved == NULL)
    uerror("realpath", p);
  res = caml_copy_string_of_os(resolved);
  /* caml_realpath allocates with malloc, not caml_stat_alloc */
  free(resolved);

  CAMLreturn(res);
}

#else

CAMLprim value unix_realpath (value p)
{ caml_invalid_argument("realpath not implemented"); }

#endif
