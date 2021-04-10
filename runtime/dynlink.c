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
#include "caml/intext.h"
#include "caml/startup.h"

#include "build_config.h"

#ifndef NATIVE_CODE

#ifndef O_BINARY
#define O_BINARY 0
#endif

/* The table of primitives */
struct ext_table caml_prim_table;

/* The names of primitives */
struct ext_table caml_prim_name_table;

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

/* Parse the ld.conf file and add the directories
   listed there to the search path */

#define LD_CONF_NAME T("ld.conf")

static void parse_ld_conf(const char_os *location)
{
  char_os * ldconfname;
  char * config, * p, * q, * r;
#ifdef _WIN32
  #define OPEN_FLAGS _O_BINARY | _O_RDONLY
  struct _stati64 st;
#else
  #define OPEN_FLAGS O_RDONLY
  struct stat st;
#endif
  int ldconf, nread;

  ldconfname = caml_stat_strconcat_os(3, location, CAML_DIR_SEP, LD_CONF_NAME);
  if (stat_os(ldconfname, &st) == -1) {
    caml_stat_free(ldconfname);
    return;
  }
  ldconf = open_os(ldconfname, OPEN_FLAGS, 0);
  if (ldconf == -1)
    caml_fatal_error("cannot read loader config file %s",
                         caml_stat_strdup_of_os(ldconfname));
  config = caml_stat_alloc(st.st_size + 1);
  nread = read(ldconf, config, st.st_size);
  if (nread == -1)
    caml_fatal_error
      ("error while reading loader config file %s",
       caml_stat_strdup_of_os(ldconfname));
  config[nread] = 0;
  q = config;
  for (p = config; *p != 0; p++) {
    if (*p == '\n') {
      *p = 0;
      caml_ext_table_add(&caml_shared_libs_path, caml_stat_strdup_to_os(q));
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
    caml_ext_table_add(&caml_shared_libs_path, caml_stat_strdup_to_os(q));
  close(ldconf);
  caml_stat_free(config);
  caml_stat_free(ldconfname);
  return;
}
#undef OPEN_FLAGS

CAMLexport void caml_parse_ld_conf(void)
{
  char_os * env_value;
  char_os * locations[3] = {T(""), T(""), NULL};
  int i, file_count = 0;

  /* Read $OCAMLLIB */
  env_value = caml_secure_getenv(T("OCAMLLIB"));
  if (env_value != NULL && strlen_os(env_value) > 0)
    locations[file_count++] = caml_stat_strdup_os(env_value);
  /* Add $CAMLLIB if set and not equal to $OCAMLLIB */
  env_value = caml_secure_getenv(T("CAMLLIB"));
  if (env_value != NULL && strlen_os(env_value) > 0
      && strcmp_os(env_value, locations[0]))
    locations[file_count++] = caml_stat_strdup_os(env_value);
  /* Add OCAML_STDLIB_DIR if not equal to either */
  if (strcmp_os(OCAML_STDLIB_DIR, locations[0])
      || strcmp_os(OCAML_STDLIB_DIR, locations[1]))
    locations[file_count++] = caml_stat_strdup_os(OCAML_STDLIB_DIR);

  /* Load and parse all the ld.conf files */
  for (i = 0; i < file_count; i++) {
    parse_ld_conf(locations[i]);
    caml_stat_free(locations[i]);
  }

  return;
}

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
  handle = caml_dlopen(realname, 1);
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
     - directories specified in the file <stdlib>/ld.conf

     caml_shared_libs_path and caml_prim_name_table are not freed afterwards:
     they may later be used by caml_dynlink_get_bytecode_sections. */
  caml_decompose_path(&caml_shared_libs_path,
                      caml_secure_getenv(T("CAML_LD_LIBRARY_PATH")));
  if (lib_path != NULL)
    for (p = lib_path; *p != 0; p += strlen_os(p) + 1)
      caml_ext_table_add(&caml_shared_libs_path, caml_stat_strdup_os(p));
  caml_parse_ld_conf();
  /* Open the shared libraries */
  caml_ext_table_init(&shared_libs, 8);
  if (libs != NULL)
    for (p = libs; *p != 0; p += strlen_os(p) + 1)
      open_shared_lib(p);
  /* Build the primitive table */
  caml_ext_table_init(&caml_prim_table, 0x180);
  caml_ext_table_init(&caml_prim_name_table, 0x180);
  if (req_prims != NULL)
    for (q = req_prims; *q != 0; q += strlen(q) + 1) {
      c_primitive prim = lookup_primitive(q);
      if (prim == NULL)
            caml_fatal_error("unknown C primitive `%s'", q);
      caml_ext_table_add(&caml_prim_table, (void *) prim);
      caml_ext_table_add(&caml_prim_name_table, caml_stat_strdup(q));
    }
}

/* Build the table of primitives as a copy of the builtin primitive table.
   Used for executables generated by ocamlc -output-obj. */

void caml_build_primitive_table_builtin(void)
{
  int i;
  caml_build_primitive_table(NULL, NULL, NULL);
  for (i = 0; caml_builtin_cprim[i] != 0; i++) {
    caml_ext_table_add(&caml_prim_table, (void *) caml_builtin_cprim[i]);
    caml_ext_table_add(&caml_prim_name_table,
                       caml_stat_strdup(caml_names_of_builtin_cprim[i]));
  }
}

void caml_free_shared_libs(void)
{
  while (shared_libs.size > 0)
    caml_dlclose(shared_libs.contents[--shared_libs.size]);
}

CAMLprim value caml_dynlink_get_bytecode_sections(value unit)
{
  CAMLparam1(unit);
  CAMLlocal4(ret, tbl, list, str);
  int i, j;
  ret = caml_alloc(4, 0);

  if (caml_params->section_table != NULL) {
    /* cf. Symtable.bytecode_sections */
    const char* sec_names[] = {"SYMB", "CRCS"};
    tbl = caml_input_value_from_block(caml_params->section_table,
                                      caml_params->section_table_size);
    for (i = 0; i < sizeof(sec_names)/sizeof(sec_names[0]); i++) {
      for (j = 0; j < Wosize_val(tbl); j++) {
        value kv = Field(tbl, j);
        if (!strcmp(sec_names[i], String_val(Field(kv, 0))))
          Store_field(ret, i, Field(kv, 1));
      }
    }
  } else {
    struct exec_trailer trail;
    int fd, err;
    char *sect;
    int32_t len;

    fd = open_os(caml_params->exe_name, O_RDONLY | O_BINARY);
    if (fd < 0)
      caml_failwith("Dynlink: Failed to re-open bytecode executable");

    err = caml_read_trailer(fd, &trail);
    if (err != 0)
      caml_failwith("Dynlink: Failed to re-read bytecode trailer");

    caml_read_section_descriptors(fd, &trail);

    len = caml_seek_optional_section(fd, &trail, "SYMB");
    sect = caml_stat_alloc(len);
    if (read(fd, sect, len) != len)
      caml_failwith("Dynlink: error reading SYMB");
    Store_field(ret, 0,
      caml_input_value_from_block(sect, len));
    caml_stat_free(sect);

    len = caml_seek_optional_section(fd, &trail, "CRCS");
    if (len > 0) {
      sect = caml_stat_alloc(len);
      if (read(fd, sect, len) != len)
        caml_failwith("Dynlink: error reading CRCS");
      Store_field(ret, 1,
        caml_input_value_from_block(sect, len));
      caml_stat_free(sect);
    }

    caml_stat_free(trail.section);
    close(fd);
  }

  list = Val_emptylist;
  for (i = caml_prim_name_table.size - 1; i >= 0; i--) {
    str = caml_copy_string(caml_prim_name_table.contents[i]);
    list = caml_alloc_2(Tag_cons, str, list);
  }
  Store_field(ret, 2, list);

  list = Val_emptylist;
  for (i = caml_shared_libs_path.size - 1; i >= 0; i--) {
    str = caml_copy_string_of_os(caml_shared_libs_path.contents[i]);
    list = caml_alloc_2(Tag_cons, str, list);
  }
  Store_field(ret, 3, list);

  CAMLreturn (ret);
}

#endif /* NATIVE_CODE */

/** dlopen interface for the bytecode linker **/

#define Handle_val(v) (*((void **) (v)))

CAMLprim value caml_dynlink_open_lib(value filename)
{
  void * handle;
  value result;
  char_os * p;

  caml_gc_message(0x100, "Opening shared library %s\n",
                  String_val(filename));
  p = caml_stat_strdup_to_os(String_val(filename));
  caml_enter_blocking_section();
  handle = caml_dlopen(p, 1);
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

value caml_dynlink_get_bytecode_sections(value unit)
{
  caml_invalid_argument("dynlink_get_bytecode_sections");
  return Val_unit; /* not reached */
}

#endif /* NATIVE_CODE */
