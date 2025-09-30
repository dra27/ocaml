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

#ifdef _WIN32
#include <io.h>
#endif

value caml_unix_file_descr_of_os(file_descriptor_os h)
{
#ifndef _WIN32
  /* Unix version - same as CRT */

  return Val_int(h);

#else
  /* Windows version: allocate SOCKET/HANDLE as appropriate */

  int _opt, _optlen = sizeof(int);
  /* Trivial call to getsockopt to test if h is a SOCKET: values are unused */
  if (getsockopt((SOCKET)h, SOL_SOCKET, SO_TYPE, (char *)&_opt, &_optlen) == 0)
    return caml_win32_alloc_socket((SOCKET)h);
  else
    return caml_win32_alloc_handle(h);

#endif /* #ifndef _WIN32 */
}

value caml_unix_file_descr_of_fd(int fildes)
{
#ifndef _WIN32
  /* Unix version - represented as an int */

  return Val_int(fildes);

#else
  /* Windows version - open a native HANDLE and allocate as appropriate */

  return caml_unix_file_descr_of_os((HANDLE)_get_osfhandle(fildes));

#endif
}

int caml_unix_fd_of_file_descr(value fd)
{
#ifndef _WIN32
  /* Unix version - represented as an int */

  return Int_val(fd);

#else
  /* Windows version - allocate a CRT fd if necessary */

  return caml_win32_CRT_fd_of_filedescr(fd);

#endif
}

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
