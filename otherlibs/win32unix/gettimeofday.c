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

#include <caml/mlvalues.h>
#include <caml/alloc.h>
#include <time.h>

#include "unixsupport.h"

/* Unix epoch as a Windows timestamp in hundreds of ns */
#define epoch_ft 116444736000000000.0;

CAMLprim value unix_gettimeofday(value unit)
{
  FILETIME ft;
  double tm;
  uint64_t ft_u64;
  GetSystemTimeAsFileTime(&ft);
  ft_u64 = ((uint64_t)ft.dwHighDateTime << ((uint64_t)32)) | ((uint64_t)ft.dwLowDateTime);
  tm = ft_u64 - epoch_ft; /* shift to Epoch-relative time */
  return copy_double(tm * 1e-7);  /* tm is in 100ns */
}
