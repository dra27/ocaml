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
#include <build_config.h>

extern const char_os *caml_runtime_standard_library_default;
extern const char_os *caml_runtime_standard_library_effective;
CAMLextern char_os *caml_locate_standard_library (const char_os *exe_name,
                                                  const char_os *stdlib_default,
                                                  char_os **dirname);
int main_os(int argc, char_os **argv)
{
  const char_os *dir;
  puts("shared_libs_path:");
  caml_ext_table_init(&caml_shared_libs_path, 8);
  caml_decompose_path(&caml_shared_libs_path,
                      caml_secure_getenv(T("CAML_LD_LIBRARY_PATH")));
  caml_runtime_standard_library_effective =
    caml_locate_standard_library(argv[0],
                                 caml_runtime_standard_library_default, NULL);
  caml_parse_ld_conf(caml_runtime_standard_library_effective,
                     &caml_shared_libs_path);
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
