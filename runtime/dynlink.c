/**************************************************************************/
/*                                                                        */
/*                                 OCaml                                  */
/*                                                                        */
/*             Xavier Leroy, projet Cristal, INRIA Rocquencourt           */
/*                                                                        */
/*   Copyright 2000 Institut National de Recherche en Informatique et     */
/*     en Automatique.                                                    */
/*                                                                        */
/*   All rights reserved.  This file is distributed under the terms of    */
/*   the GNU Lesser General Public License version 2.1, with the          */
/*   special exception on linking described in the file LICENSE.          */
/*                                                                        */
/**************************************************************************/

#define CAML_INTERNALS

/* Dynamic loading of C primitives. */

#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <sys/stat.h>
#include "caml/config.h"
#ifdef HAS_UNISTD
#include <unistd.h>
#endif
#include "caml/alloc.h"
#include "caml/dynlink.h"
#include "caml/fail.h"
#include "caml/mlvalues.h"
#include "caml/memory.h"
#include "caml/misc.h"
#include "caml/osdeps.h"
#include "caml/prims.h"
#include "caml/signals.h"
#include "caml/sys.h"

#ifndef NATIVE_CODE

/* The table of primitives */
struct ext_table caml_prim_table;

#ifdef DEBUG
/* The names of primitives (for instrtrace.c) */
struct ext_table caml_prim_name_table;
#endif

/* The table of shared libraries currently opened */
static struct ext_table shared_libs;

/* The search path for shared libraries */
struct ext_table caml_shared_libs_path;

/* Look up the given primitive name in the built-in primitive table,
   then in the opened shared libraries (shared_libs) */
static c_primitive lookup_primitive(char * name)
{
  int i;
  void * res;

  for (i = 0; caml_names_of_builtin_cprim[i] != NULL; i++) {
    if (strcmp(name, caml_names_of_builtin_cprim[i]) == 0)
      return caml_builtin_cprim[i];
  }
  for (i = 0; i < shared_libs.size; i++) {
    res = caml_dlsym(shared_libs.contents[i], name);
    if (res != NULL) return (c_primitive) res;
  }
  return NULL;
}

/* Parse the OCAML_STDLIB_DIR/ld.conf file and add the directories
   listed there to the search path */

#define LD_CONF_NAME T("ld.conf")

Caml_inline char_os * filename_concat(char_os * path1, char_os * path2)
{
  if (Is_dir_separator(path1[strlen_os(path1) - 1]))
    return caml_stat_strconcat_os(2, path1, path2);
  else
    return caml_stat_strconcat_os(3, path1, CAML_DIR_SEP, path2);
}

static void add_ld_conf_entry(char_os * root, char_os * dir)
{
  char_os * entry;
  size_t len = strlen_os(dir);
  /* Implicit paths, "." and ".." are treated relative to ld.conf */
  if ((len == 1 && dir[0] == '.')
      || (len == 2 && dir[0] == '.' && Is_dir_separator(dir[1]))) {
    /* "." or "./" - add the directory containing ld.conf */
    entry = caml_stat_strdup_os(root);
  } else if (len >= 2 && dir[0] == '.' && dir[1] == '.'
             && (len == 2 || Is_dir_separator(dir[2]))) {
    /* ".." or "../..." */
    entry = filename_concat(root, dir);
  } else if (len >= 2 && dir[0] == '.' && Is_dir_separator(dir[1])) {
    /* "./..." */
    entry = filename_concat(root, dir + 2);
  } else {
    /* Absolute or implicit path */
    entry = caml_stat_strdup_os(dir);
  }
  caml_ext_table_add(&caml_shared_libs_path, entry);
}

static void parse_ld_conf(void)
{
  char_os * locations[3] = {
    caml_secure_getenv(T("OCAMLLIB")),
    caml_secure_getenv(T("CAMLLIB")),
    caml_standard_library };
  char_os * ldconfs[3] = {NULL, NULL, NULL};
  char * raw_config;
  char_os * config;
  char_os * p, * q, * r;
#ifdef _WIN32
  #define OPEN_FLAGS _O_BINARY | _O_RDONLY
  struct _stati64 st;
#else
  #define OPEN_FLAGS O_RDONLY
  struct stat st;
#endif
  size_t configsize = 0;
  int ldconf, i, j;

  /* Loop through the possible ld.conf files, ignoring clearly identical
     files. */
  for (i = 0; i < 3; i++) {
    if (locations[i] && strlen_os(locations[i]) > 0) {
      ldconfs[i] =
        caml_stat_strconcat_os(3, locations[i], CAML_DIR_SEP, LD_CONF_NAME);

      if (stat_os(ldconfs[i], &st) != -1) {
        /* Check if the file has obviously been loaded by a previous step */
        for (j = 0; j < i; j++) {
          if (ldconfs[j] && !strcmp_os(ldconfs[j], ldconfs[i]))
            break;
        }

        if (j == i) {
          /* Allocate or grow the buffer, if needed */
          /* XXX The Windows impl. reveals the already-known pointlessness of the memory over-management here! */
          if (configsize == 0) {
            raw_config = caml_stat_alloc(st.st_size + 1);
          } else if (configsize < st.st_size + 1) {
            configsize = st.st_size + 1;
            raw_config = caml_stat_resize(raw_config, configsize);
          }

          if ((ldconf = open_os(ldconfs[i], O_RDONLY, 0)) == -1) {
            caml_fatal_error("cannot read loader config file %s",
                             caml_stat_strdup_of_os(ldconfs[i]));
          }
          if (read(ldconf, raw_config, st.st_size) != st.st_size) {
            caml_fatal_error("error while reading loader config file %s",
                             caml_stat_strdup_of_os(ldconfs[i]));
          }
          close(ldconf);
          raw_config[st.st_size] = 0;
          config = caml_stat_strdup_to_os(raw_config);

          for (p = q = config; *p != 0; p++) {
            if (*p == '\n') {
              *p = 0;
              add_ld_conf_entry(locations[i], q);
              q = p + 1;
            } else if (*p == '\r') {
              r = p;
              /* Allow \r+ */
              while (*(++r) == '\r');
              if (*r == '\n') {
                /* Matched \r+\n */
                *p = 0;
              }
              p = r - 1;
            }
          }
          if (q < p)
            add_ld_conf_entry(locations[i], q);
          caml_stat_free(config);
        }
      }
    }
  }

  for (i = 0; i < 3; i++)
   if (ldconfs[i])
     caml_stat_free(ldconfs[i]);

  if (configsize > 0)
    caml_stat_free(config);

  return;
}
#undef OPEN_FLAGS

/* Open the given shared library and add it to shared_libs.
   Abort on error. */
static void open_shared_lib(char_os * name)
{
  char_os * realname;
  char * u8;
  void * handle;

  realname = caml_search_dll_in_path(&caml_shared_libs_path, name);
  u8 = caml_stat_strdup_of_os(realname);
  caml_gc_message(0x100, "Loading shared library %s\n", u8);
  caml_stat_free(u8);
  caml_enter_blocking_section();
  handle = caml_dlopen(realname, 1, 1);
  caml_leave_blocking_section();
  if (handle == NULL)
    caml_fatal_error
    (
      "cannot load shared library %s\n"
      "Reason: %s",
      caml_stat_strdup_of_os(name),
      caml_dlerror()
    );
  caml_ext_table_add(&shared_libs, handle);
  caml_stat_free(realname);
}

/* Build the table of primitives, given a search path and a list
   of shared libraries (both 0-separated in a char array).
   Abort the runtime system on error. */
void caml_build_primitive_table(char_os * lib_path,
                                char_os * libs,
                                char * req_prims)
{
  char_os * p;
  char * q;

  /* Initialize the search path for dynamic libraries:
     - directories specified on the command line with the -I option
     - directories specified in the CAML_LD_LIBRARY_PATH
     - directories specified in the executable
     - directories specified in OCAMLLIB/ld.conf
     - directories specified in CAMLLIB/ld.conf
     - directories specified in the file <stdlib>/ld.conf */
  caml_decompose_path(&caml_shared_libs_path,
                      caml_secure_getenv(T("CAML_LD_LIBRARY_PATH")));
  if (lib_path != NULL)
    for (p = lib_path; *p != 0; p += strlen_os(p) + 1)
      caml_ext_table_add(&caml_shared_libs_path, caml_stat_strdup_os(p));
  /* Open the shared libraries */
  caml_ext_table_init(&shared_libs, 8);
  if (libs != NULL) {
    parse_ld_conf();
    for (p = libs; *p != 0; p += strlen_os(p) + 1)
      open_shared_lib(p);
  }
  /* Build the primitive table */
  caml_ext_table_init(&caml_prim_table, 0x180);
#ifdef DEBUG
  caml_ext_table_init(&caml_prim_name_table, 0x180);
#endif
  for (q = req_prims; *q != 0; q += strlen(q) + 1) {
    c_primitive prim = lookup_primitive(q);
    if (prim == NULL)
          caml_fatal_error("unknown C primitive `%s'", q);
    caml_ext_table_add(&caml_prim_table, (void *) prim);
#ifdef DEBUG
    caml_ext_table_add(&caml_prim_name_table, caml_stat_strdup(q));
#endif
  }
  /* Clean up */
  caml_ext_table_free(&caml_shared_libs_path, 1);
}

/* Build the table of primitives as a copy of the builtin primitive table.
   Used for executables generated by ocamlc -output-obj. */

void caml_build_primitive_table_builtin(void)
{
  int i;
  caml_ext_table_init(&caml_prim_table, 0x180);
#ifdef DEBUG
  caml_ext_table_init(&caml_prim_name_table, 0x180);
#endif
  for (i = 0; caml_builtin_cprim[i] != 0; i++) {
    caml_ext_table_add(&caml_prim_table, (void *) caml_builtin_cprim[i]);
#ifdef DEBUG
    caml_ext_table_add(&caml_prim_name_table,
                       caml_stat_strdup(caml_names_of_builtin_cprim[i]));
#endif
  }
}

void caml_free_shared_libs(void)
{
  while (shared_libs.size > 0)
    caml_dlclose(shared_libs.contents[--shared_libs.size]);
}

#endif /* NATIVE_CODE */

/** dlopen interface for the bytecode linker **/

#define Handle_val(v) (*((void **) (v)))

CAMLprim value caml_dynlink_open_lib(value mode, value filename)
{
  void * handle;
  value result;
  char_os * p;

  caml_gc_message(0x100, "Opening shared library %s\n",
                  String_val(filename));
  p = caml_stat_strdup_to_os(String_val(filename));
  caml_enter_blocking_section();
  handle = caml_dlopen(p, Int_val(mode), 1);
  caml_leave_blocking_section();
  caml_stat_free(p);
  if (handle == NULL) caml_failwith(caml_dlerror());
  result = caml_alloc_small(1, Abstract_tag);
  Handle_val(result) = handle;
  return result;
}

CAMLprim value caml_dynlink_close_lib(value handle)
{
  caml_dlclose(Handle_val(handle));
  return Val_unit;
}

/*#include <stdio.h>*/
CAMLprim value caml_dynlink_lookup_symbol(value handle, value symbolname)
{
  void * symb;
  value result;
  symb = caml_dlsym(Handle_val(handle), String_val(symbolname));
  /* printf("%s = 0x%lx\n", String_val(symbolname), symb);
     fflush(stdout); */
  if (symb == NULL) return Val_unit /*caml_failwith(caml_dlerror())*/;
  result = caml_alloc_small(1, Abstract_tag);
  Handle_val(result) = symb;
  return result;
}

#ifndef NATIVE_CODE

CAMLprim value caml_dynlink_add_primitive(value handle)
{
  return Val_int(caml_ext_table_add(&caml_prim_table, Handle_val(handle)));
}

CAMLprim value caml_dynlink_get_current_libs(value unit)
{
  CAMLparam0();
  CAMLlocal1(res);
  int i;

  res = caml_alloc_tuple(shared_libs.size);
  for (i = 0; i < shared_libs.size; i++) {
    value v = caml_alloc_small(1, Abstract_tag);
    Handle_val(v) = shared_libs.contents[i];
    Store_field(res, i, v);
  }
  CAMLreturn(res);
}

#else

value caml_dynlink_add_primitive(value handle)
{
  caml_invalid_argument("dynlink_add_primitive");
  return Val_unit; /* not reached */
}

value caml_dynlink_get_current_libs(value unit)
{
  caml_invalid_argument("dynlink_get_current_libs");
  return Val_unit; /* not reached */
}

#endif /* NATIVE_CODE */
