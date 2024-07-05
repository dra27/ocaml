/**************************************************************************/
/*                                                                        */
/*                                 OCaml                                  */
/*                                                                        */
/*                 David Allsopp, University of Cambridge                 */
/*                                                                        */
/*   Copyright 2026 David Allsopp Ltd.                                    */
/*                                                                        */
/*   All rights reserved.  This file is distributed under the terms of    */
/*   the GNU Lesser General Public License version 2.1, with the          */
/*   special exception on linking described in the file LICENSE.          */
/*                                                                        */
/**************************************************************************/

/* Small stub used by test_ld_conf.ml to checkout the C runtime processing of
   CAML_LD_LIBRARY_PATH and ld.conf */

#include <stdio.h>

#define CAML_INTERNALS
#include <caml/callback.h>
#include <caml/dynlink.h>
#include <caml/misc.h>
#include <caml/osdeps.h>

int main_os(int argc, char_os **argv)
{
  const char_os *dir;
  puts("shared_libs_path:");
  caml_ext_table_init(&caml_shared_libs_path, 8);
  caml_decompose_path(&caml_shared_libs_path,
                      caml_secure_getenv(T("CAML_LD_LIBRARY_PATH")));
  caml_parse_ld_conf();
  for (int i = 0; i < caml_shared_libs_path.size; i++) {
    dir = caml_shared_libs_path.contents[i];
    if (dir[0] == 0)
#ifdef _WIN32
      /* See caml_search_in_path in win32.c */
      continue;
#else
      dir = ".";
#endif
    printf("  %s\n", caml_stat_strdup_of_os(dir));
  }
  return 0;
}
