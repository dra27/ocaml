/**************************************************************************/
/*                                                                        */
/*                                 OCaml                                  */
/*                                                                        */
/*            David Allsopp, University of Cambridge & Tarides            */
/*                                                                        */
/*   Copyright 2025 David Allsopp Ltd.                                    */
/*                                                                        */
/*   All rights reserved.  This file is distributed under the terms of    */
/*   the GNU Lesser General Public License version 2.1, with the          */
/*   special exception on linking described in the file LICENSE.          */
/*                                                                        */
/**************************************************************************/

#define CAML_INTERNALS

#include <caml/mlvalues.h>
#include <caml/fail.h>
#include "caml/unixsupport.h"

CAMLprim value caml_unix_fdopen(value stream_number)
{
  /* Negative stream numbers are invalid and the standard streams should not be
     retrieved using this function. */
  int fd = Int_val(stream_number);
  if (fd < 3)
    caml_invalid_argument("Unix.fdopen");
  else
    return caml_unix_file_descr_of_fd(fd);
}
