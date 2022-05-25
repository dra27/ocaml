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

#ifndef CAML_UNIXSUPPORT_H
#define CAML_UNIXSUPPORT_H

#ifdef HAS_UNISTD
#include <unistd.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

#define Nothing ((value) 0)

extern value caml_unix_error_of_code (int errcode);
extern int caml_unix_code_of_unix_error (value error);

/* Compatibility definitions for the pre-5.0 names of these functions */
#ifndef CAML_BUILDING_UNIX
#define unix_error_of_code caml_unix_error_of_code
#define code_of_unix_error caml_unix_code_of_unix_error
#endif /* CAML_BUILDING_UNIX */

CAMLnoreturn_start
extern void caml_unix_error (int errcode, const char * cmdname, value arg)
CAMLnoreturn_end;

CAMLnoreturn_start
extern void caml_uerror (const char * cmdname, value arg)
CAMLnoreturn_end;

/* Compatibility definitions for the pre-5.0 names of these functions */
#ifndef CAML_BUILDING_UNIX
#define uerror caml_uerror
#define unix_error caml_unix_error
#endif /* CAML_BUILDING_UNIX */

extern void caml_unix_check_path(value path, const char * cmdname);

#define UNIX_BUFFER_SIZE 65536

#define DIR_Val(v) *((DIR **) &Field(v, 0))

extern char ** caml_unix_cstringvect(value arg, char * cmdname);
extern void caml_unix_cstringvect_free(char **);

extern int caml_unix_cloexec_default;
extern int caml_unix_cloexec_p(value cloexec);
extern void caml_unix_set_cloexec(int fd, char * cmdname, value arg);
extern void caml_unix_clear_cloexec(int fd, char * cmdname, value arg);

#ifdef __cplusplus
}
#endif

#define EXECV_CAST

#endif /* CAML_UNIXSUPPORT_H */
