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
#include <caml/signals.h>
#include "unixsupport.h"

CAMLprim value unix_sleep(value t)
{
  DWORD ct;
  ct = Double_val(t) * 1e3;
  enter_blocking_section();
  Sleep(ct);
  leave_blocking_section();
  return Val_unit;
}
