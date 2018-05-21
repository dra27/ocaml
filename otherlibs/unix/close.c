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
#include "unixsupport.h"

#ifdef _WIN32
#include <caml/io.h>

CAMLprim value unix_close(value fd)
{
  if (Descr_kind_val(fd) == KIND_SOCKET) {
    if (closesocket(Socket_val(fd)) != 0) {
      win32_maperr(WSAGetLastError());
      uerror("close", Nothing);
    }
  } else {
    /* If we have an fd then closing it also closes
     * the underlying handle. Also, closing only
     * the handle and not the fd leads to fd leaks. */
    if (CRT_fd_val(fd) != NO_CRT_FD) {
      if (_close(CRT_fd_val(fd)) != 0)
         uerror("close", Nothing);
    } else {
      if (! CloseHandle(Handle_val(fd))) {
        win32_maperr(GetLastError());
        uerror("close", Nothing);
      }
    }
  }
  return Val_unit;
}
#else
#include <caml/signals.h>

CAMLprim value unix_close(value fd)
{
  int ret;
  caml_enter_blocking_section();
  ret = close(Int_val(fd));
  caml_leave_blocking_section();
  if (ret == -1) uerror("close", Nothing);
  return Val_unit;
}
#endif
