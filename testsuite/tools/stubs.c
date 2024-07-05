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

#ifdef _WIN32
/*
 * Windows Vista functions enabled
 */
#undef _WIN32_WINNT
#define _WIN32_WINNT 0x0600
#endif

#include <caml/mlvalues.h>
#include <caml/memory.h>
#include <caml/alloc.h>
#include <caml/fail.h>
#include <caml/osdeps.h>
#include <unixsupport.h>
#include <caml/bigarray.h>
#include <caml/io.h>

#ifdef _WIN32
#include <windows.h>
#endif

CAMLprim value caml_unix_realpath (value p)
{
  CAMLparam1 (p);
  value rp;
#ifdef _WIN32
  HANDLE h;
  wchar_t *wp;
  wchar_t *wr;
  DWORD wr_len;

  caml_unix_check_path (p, "realpath");
  wp = caml_stat_strdup_to_utf16 (String_val (p));
  h = CreateFile (wp, 0,
                  FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL,
                  OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, NULL);
  caml_stat_free (wp);

  if (h == INVALID_HANDLE_VALUE)
  {
    win32_maperr (GetLastError ());
    uerror ("realpath", p);
  }

  wr_len = GetFinalPathNameByHandle (h, NULL, 0, VOLUME_NAME_DOS);
  if (wr_len == 0)
  {
    win32_maperr (GetLastError ());
    CloseHandle (h);
    uerror ("realpath", p);
  }

  wr = caml_stat_alloc ((wr_len + 1) * sizeof (wchar_t));
  wr_len = GetFinalPathNameByHandle (h, wr, wr_len, VOLUME_NAME_DOS);

  if (wr_len == 0)
  {
    win32_maperr (GetLastError ());
    CloseHandle (h);
    caml_stat_free (wr);
    uerror ("realpath", p);
  }

  rp = caml_copy_string_of_utf16 (wr);
  CloseHandle (h);
  caml_stat_free (wr);
#else
  char *r;

  caml_unix_check_path (p, "realpath");
  r = realpath (String_val (p), NULL);
  if (r == NULL) { uerror ("realpath", p); }
  rp = caml_copy_string (r);
  free (r);
#endif
  CAMLreturn (rp);
}

value caml_ml_input_bigarray(value vchannel, value vbuf,
                             value vpos, value vlen)
{
  CAMLparam4(vchannel, vbuf, vpos, vlen);
  struct channel * channel = Channel(vchannel);
  intnat pos = Long_val(vpos);
  intnat len = Long_val(vlen);
  intnat n;

  Lock(channel);
  n = caml_getblock(channel, (char *)Caml_ba_data_val(vbuf) + pos, len);
  Unlock(channel);

  CAMLreturn (Val_long(n));
}

value caml_in_prefix_test_no_caml_executable_name(value unit)
{
  char_os *name = caml_executable_name();
  if (name)
    caml_stat_free(name);
  return Val_bool(name == NULL);
}
