/**************************************************************************/
/*                                                                        */
/*                                 OCaml                                  */
/*                                                                        */
/*             Xavier Leroy, projet Cristal, INRIA Rocquencourt           */
/*                                                                        */
/*   Copyright 1998 Institut National de Recherche en Informatique et     */
/*     en Automatique.                                                    */
/*                                                                        */
/*   All rights reserved.  This file is distributed under the terms of    */
/*   the GNU Lesser General Public License version 2.1, with the          */
/*   special exception on linking described in the file LICENSE.          */
/*                                                                        */
/**************************************************************************/

/* caml_executable_name lives here as it's shared with ../stdlib/header.c */

#define CAML_INTERNALS
#include "caml/memory.h"

#ifdef __APPLE__
#include <mach-o/dyld.h>
#endif

#include <unistd.h>
#include <string.h>
#include <sys/stat.h>

/* Recover executable name from /proc/self/exe if possible */

char * caml_executable_name(void)
{
#if defined(__linux__)
  int namelen, retcode;
  char * name;
  struct stat st;

  /* lstat("/proc/self/exe") returns st_size == 0 so we cannot use it
     to determine the size of the buffer.  Instead, we guess and adjust. */
  namelen = 256;
  while (1) {
    name = caml_stat_alloc(namelen);
    retcode = readlink("/proc/self/exe", name, namelen);
    if (retcode == -1) { caml_stat_free(name); return NULL; }
    if (retcode < namelen) break;
    caml_stat_free(name);
    if (namelen >= 1024*1024) return NULL; /* avoid runaway and overflow */
    namelen *= 2;
  }
  /* readlink() does not zero-terminate its result.
     There is room for a final zero since retcode < namelen. */
  name[retcode] = 0;
  /* Make sure that the contents of /proc/self/exe is a regular file.
     (Old Linux kernels return an inode number instead.) */
  if (stat(name, &st) == -1 || ! S_ISREG(st.st_mode)) {
    caml_stat_free(name); return NULL;
  }
  return name;

#elif defined(__APPLE__)
  unsigned int namelen;
  char * name;

  namelen = 256;
  name = caml_stat_alloc(namelen);
  if (_NSGetExecutablePath(name, &namelen) == 0) return name;
  caml_stat_free(name);
  /* Buffer is too small, but namelen now contains the size needed */
  name = caml_stat_alloc(namelen);
  if (_NSGetExecutablePath(name, &namelen) == 0) return name;
  caml_stat_free(name);
  return NULL;

#else
  return NULL;

#endif
}
