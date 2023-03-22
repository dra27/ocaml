/**************************************************************************/
/*                                                                        */
/*                                 OCaml                                  */
/*                                                                        */
/*                 David Allsopp, OCaml Labs, Cambridge.                  */
/*                                                                        */
/*   Copyright 2021 David Allsopp Ltd.                                    */
/*                                                                        */
/*   All rights reserved.  This file is distributed under the terms of    */
/*   the GNU Lesser General Public License version 2.1, with the          */
/*   special exception on linking described in the file LICENSE.          */
/*                                                                        */
/**************************************************************************/

/* Runtime Builder's Swiss Army Knife. This utility performs functions
   previously delegated to classic Unix utilities but which ultimately seem to
   cause more hassle for maintenance than the initial simplicity suggests.

   This tool is a memorial to the many hours and PRs spent chasing down strange
   locale issues, stray CR characters and fighting yet another incompatible
   implementation of sed or awk. */

/* Borrow the Unicode *_os definitions and T() macro from misc.h */
#define CAML_INTERNALS
#include "caml/misc.h"

#include <stdio.h>
#include <string.h>
#include <ctype.h>

#ifdef _WIN32
#define strncmp_os wcsncmp
#define toupper_os towupper
#define printf_os wprintf
#define sscanf_os sscanf_s
#else
#define strncmp_os strncmp
/* NOTE: See CAVEATS section in https://man.netbsd.org/ctype.3 */
/* and NOTE section in https://man7.org/linux/man-pages/man3/toupper.3.html */
#define toupper_os(x) toupper((unsigned char)x)
#define printf_os printf
#define sscanf_os sscanf
#endif

/* Operations
   - encode-C-literal. Used for the OCAML_STDLIB_DIR macro in
     runtime/build_config.h to ensure the LIBDIR make variable is correctly
     represented as a C string literal.

     On Unix, `sak encode-C-literal /usr/local/lib` returns `"/usr/local/lib"`

     On Windows, `sak encode-C-literal "C:\OCaml🐫\lib"` returns
     `L"C:\\OCaml\xd83d\xdc2b\\lib"`
   - add-stdlib-prefix. Used in stdlib/StdlibModules to convert the list of
     basenames given in STDLIB_MODULE_BASENAMES to the actual file basenames
     in STDLIB_MODULES.

     For example, `sak add-stdlib-prefix stdlib camlinternalAtomic Sys` returns
     ` stdlib camlinternalAtomic stdlib__Sys`
   - extract-primitives. Used when constructing runtime/primitives.tbl in place
     of sed.
 */

void usage(void)
{
  printf(
    "OCaml Build System Swiss Army Knife\n"
    "Usage: sak command\n"
    "Commands:\n"
    " * encode-C-literal path - encodes path as a C string literal\n"
    " * add-stdlib-prefix name1 ... - prefix standard library module names\n"
    " * extract-primitives - print primitive names read from C piped to stdin\n"
  );
}

/* Converts the supplied path (UTF-8 on Unix and UCS-2ish on Windows) to a valid
   C string literal. On Windows, this is always a wchar_t* (L"..."). */
void encode_C_literal(char_os *path)
{
  char_os c;

#ifdef _WIN32
  putchar('L');
#endif
  putchar('"');

  while ((c = *path++) != 0) {
    /* Escape \, " and \n */
    if (c == '\\') {
      printf("\\\\");
    } else if (c == '"') {
      printf("\\\"");
    } else if (c == '\n') {
      printf("\\n");
#ifndef _WIN32
    /* On Unix, nothing else needs escaping */
    } else {
      putchar(c);
#else
    /* On Windows, allow 7-bit printable characters to be displayed literally
       and escape everything else (using the older \x notation for increased
       compatibility, rather than the newer \U. */
    } else if (c < 0x80 && iswprint(c)) {
      putwchar(c);
    } else {
      printf("\\x%04x", c);
#endif
    }
  }

  putchar('"');
}

/* Print the given array of module names to stdout. "stdlib" and names beginning
   "camlinternal" are printed unaltered. All other names are prefixed "stdlib__"
   with the original name capitalised (i.e. "foo" prints "stdlib__Foo"). */
void add_stdlib_prefix(int count, char_os **names)
{
  int i;
  char_os *name;

  for (i = 0; i < count; i++) {
    name = *names++;

    /* "stdlib" and camlinternal* do not get changed. All other names get
       capitalised and prefixed "stdlib__". */
    if (strcmp_os(T("stdlib"), name) == 0
     || strncmp_os(T("camlinternal"), name, 12) == 0) {
      printf_os(T(" %s"), name);
    } else {
      /* name is a null-terminated string, so an empty string simply has the
         null-terminator "capitalised". */
      *name = toupper_os(*name);
      printf_os(T(" stdlib__%s"), name);
    }
  }
}

void extract_primitives(void)
{
  char buf[256];
  char primitive[101];
  char *line;
  while ((line = fgets(buf, 256, stdin)) != NULL) {
    if (sscanf_os(line, "CAMLprim value %100[^ (\n]%*[ (\n]", primitive) == 1) {
      printf("P(%s)\n", primitive);
    } else if (sscanf_os(line, "CAMLprim_int64_%*1[12](%100[^)])",
                         primitive) == 1) {
      printf("P(caml_int64_%1$s)\n"
             "P(caml_int64_%1$s_native)\n", primitive);
    }
  }
}

int main_os(int argc, char_os **argv)
{
  if (argc == 3 && !strcmp_os(argv[1], T("encode-C-literal"))) {
    encode_C_literal(argv[2]);
  } else if (argc > 1 && !strcmp_os(argv[1], T("add-stdlib-prefix"))) {
    add_stdlib_prefix(argc - 2, &argv[2]);
  } else if (argc == 2 && !strcmp_os(argv[1], T("extract-primitives"))) {
    extract_primitives();
  } else {
    usage();
    return 1;
  }

  return 0;
}
