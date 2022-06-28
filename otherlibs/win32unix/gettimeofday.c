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

double unix_gettimeofday_unboxed(value unit)
{
  FILETIME ft;
  double tm;
  ULARGE_INTEGER utime;
  GetSystemTimeAsFileTime(&ft);
#if defined(_MSC_VER) && _MSC_VER < 1300
  /* This compiler can't cast uint64_t to double! Fortunately, this doesn't
     matter since SYSTEMTIME is only ever 63-bit (maximum value 31-Dec-30827
     23:59:59.999, and it requires some skill to set the clock past 2099!)
   */
  tm = *(int64_t *)&ft - epoch_ft; /* shift to Epoch-relative time */
#else
  utime.LowPart = ft.dwLowDateTime;
  utime.HighPart = ft.dwHighDateTime;
  tm = utime.QuadPart - CAML_NT_EPOCH_100ns_TICKS;
#endif
  return (tm * 1e-7);  /* tm is in 100ns */
}

CAMLprim value unix_gettimeofday(value unit)
{
  return caml_copy_double(unix_gettimeofday_unboxed(unit));
}
