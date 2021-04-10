/**************************************************************************/
/*                                                                        */
/*                                 OCaml                                  */
/*                                                                        */
/*            Xavier Leroy, projet Cristal, INRIA Rocquencourt            */
/*                                                                        */
/*   Copyright 2001 Institut National de Recherche en Informatique et     */
/*     en Automatique.                                                    */
/*                                                                        */
/*   All rights reserved.  This file is distributed under the terms of    */
/*   the GNU Lesser General Public License version 2.1, with the          */
/*   special exception on linking described in the file LICENSE.          */
/*                                                                        */
/**************************************************************************/

/* Operating system - specific stuff */

#ifndef CAML_OSDEPS_H
#define CAML_OSDEPS_H

#ifdef _WIN32
#include <time.h>

extern unsigned short caml_win32_major;
extern unsigned short caml_win32_minor;
extern unsigned short caml_win32_build;
extern unsigned short caml_win32_revision;
#endif

#ifdef CAML_INTERNALS

#include "misc.h"
#include "memory.h"

#define Io_interrupted (-1)

/* Read at most [n] bytes from file descriptor [fd] into buffer [buf].
   [flags] indicates whether [fd] is a socket
   (bit [CHANNEL_FLAG_FROM_SOCKET] is set in this case, see [io.h]).
   (This distinction matters for Win32, but not for Unix.)
   Return number of bytes read.
   In case of error, raises [Sys_error] or [Sys_blocked_io].
   If interrupted by a signal and no bytes where read, returns
   Io_interrupted without raising. */
extern int caml_read_fd(int fd, int flags, void * buf, int n);

/* Write at most [n] bytes from buffer [buf] onto file descriptor [fd].
   [flags] indicates whether [fd] is a socket
   (bit [CHANNEL_FLAG_FROM_SOCKET] is set in this case, see [io.h]).
   (This distinction matters for Win32, but not for Unix.)
   Return number of bytes written.
   In case of error, raises [Sys_error] or [Sys_blocked_io].
   If interrupted by a signal and no bytes were written, returns
   Io_interrupted without raising. */
extern int caml_write_fd(int fd, int flags, void * buf, int n);

/* Decompose the given path into a list of directories, and add them
   to the given table. */
extern char_os * caml_decompose_path(struct ext_table * tbl, char_os * path);

/* Search the given file in the given list of directories.
   If not found, return a copy of [name]. */
extern char_os * caml_search_in_path(struct ext_table * path,
                                     const char_os * name);

/* Same, but search an executable name in the system path for executables. */
CAMLextern char_os * caml_search_exe_in_path(const char_os * name);

/* Same, but search a shared library in the given path. */
extern char_os * caml_search_dll_in_path(struct ext_table * path,
                                         const char_os * name);

/* Open a shared library and return a handle on it.
   If [for_execution] is true, perform full symbol resolution and
   execute initialization code so that functions from the shared library
   can be called.  If [for_execution] is false, functions from this
   shared library will not be called, but just checked for presence,
   so symbol resolution can be skipped.
   If [global] is true, symbols from the shared library can be used
   to resolve for other libraries to be opened later on.
   Return [NULL] on error. */
extern void * caml_dlopen(char_os * libname, int for_execution, int global);

/* Close a shared library handle */
extern void caml_dlclose(void * handle);

/* Look up the given symbol in the given shared library.
   Return [NULL] if not found, or symbol value if found. */
extern void * caml_dlsym(void * handle, const char * name);

extern void * caml_globalsym(const char * name);

/* Return an error message describing the most recent dynlink failure. */
extern char * caml_dlerror(void);

/* Recover executable name if possible (/proc/sef/exe under Linux,
   GetModuleFileName under Windows).  Return NULL on error,
   string allocated with [caml_stat_alloc] on success. */
extern char_os * caml_executable_name(void);

/* Secure version of [getenv]: returns NULL if the process has special
   privileges (setuid bit, setgid bit, capabilities).
*/
extern char_os *caml_secure_getenv(char_os const *var);

/* If [fd] refers to a terminal or console, return the number of rows
   (lines) that it displays.  Otherwise, or if the number of rows
   cannot be determined, return -1. */
extern int caml_num_rows_fd(int fd);

/* caml_locate_standard_library returns the location of the Standard Library.
   The location returned is absolute, if stdlib_default is a relative path then
   the result is computed relative to the directory portion of exe_name.

   If dirname is not NULL and stdlib_default is a relative path, a copy of the
   directory name part of exe_name is returned. If stdlib_default is an absolute
   path, dirname is never changed.

   Both strings are allocated with [caml_stat_alloc], so should be freed using
   [caml_stat_free].
*/
CAMLextern char_os *caml_locate_standard_library (const char_os *exe_name,
                                                  const char_os *stdlib_default,
                                                  char_os **dirname);

#ifdef _WIN32

extern int caml_win32_rename(const wchar_t *, const wchar_t *);
CAMLextern int caml_win32_unlink(const wchar_t *);

extern void caml_probe_win32_version(void);
extern void caml_setup_win32_terminal(void);
extern void caml_restore_win32_terminal(void);

extern wchar_t *caml_win32_getenv(wchar_t const *);

/* Windows Unicode support */

CAMLextern int caml_win32_multi_byte_to_wide_char(const char* s,
                                                  int slen,
                                                  wchar_t *out,
                                                  int outlen);
CAMLextern int caml_win32_wide_char_to_multi_byte(const wchar_t* s,
                                                  int slen,
                                                  char *out,
                                                  int outlen);

/* Legacy names */
#define win_multi_byte_to_wide_char caml_win32_multi_byte_to_wide_char
#define win_wide_char_to_multi_byte caml_win32_wide_char_to_multi_byte

CAMLextern int caml_win32_isatty(int fd);

CAMLextern void caml_expand_command_line (int *, wchar_t ***);

CAMLextern clock_t caml_win32_clock(void);

#define CAML_DIR_SEP T("\\")
#define Is_separator(c) (c == '\\' || c == '/')

#else

#define CAML_DIR_SEP T("/")
#define Is_separator(c) (c == '/')

#endif /* _WIN32 */

/* Returns the current value of a counter that increments once per nanosecond.
   On systems that support it, this uses a monotonic timesource which ignores
   changes in the system time (so that this counter increases by 1000000 each
   millisecond, even if the system clock was set back by an hour during that
   millisecond). This makes it useful for benchmarking and timeouts, but not
   for telling the time. The units are always nanoseconds, but the achieved
   resolution may be less. The starting point is unspecified. */
extern int64_t caml_time_counter(void);

extern void caml_init_os_params(void);

/* True if:
   - dir equals "."
   - dir equals ".."
   - dir begins "./"
   - dir begins "../"
   The tests for null avoid the need to call strlen_os. */
#define Is_relative_dir(dir) \
  (dir[0] == '.' \
   && (dir[1] == 0 \
       || Is_separator(dir[1]) \
       || (dir[1] == '.' && (dir[2] == 0 || Is_separator(dir[2])))))

#endif /* CAML_INTERNALS */

#ifdef _WIN32

/* [caml_stat_strdup_to_utf16(s)] returns a NUL-terminated copy of [s],
   re-encoded in UTF-16.  The encoding of [s] is assumed to be UTF-8 if
   [caml_windows_unicode_runtime_enabled] is non-zero **and** [s] is valid
   UTF-8, or the current Windows code page otherwise.

   The returned string is allocated with [caml_stat_alloc], so it should be
   freed using [caml_stat_free].

   If allocation fails, this raises Out_of_memory. This function may also raise
   [Sys_error] if [s] is not valid UTF-8.
*/
CAMLextern wchar_t* caml_stat_strdup_to_utf16(const char *s);

/* [caml_stat_strdup_of_utf16(s)] returns a NUL-terminated copy of [s],
   re-encoded in UTF-8 if [caml_windows_unicode_runtime_enabled] is non-zero or
   the current Windows code page otherwise.

   The returned string is allocated with [caml_stat_alloc], so it should be
   freed using [caml_stat_free].

   If allocation fails, this raises Out_of_memory. This function may also raise
   [Sys_error] if [s] is not valid UTF-16.
*/
CAMLextern char* caml_stat_strdup_of_utf16(const wchar_t *s);

/* [caml_stat_char_array_to_utf16(s, size, &out_size)] returns a copy of the
   first [size] bytes of [s] re-encoded in UTF-16. [s] does not have to be NUL-
   terminated and may contain embedded NUL characters. The encoding of [s] is
   assumed to be UTF-8 if [caml_windows_unicode_runtime_enabled] is non-zero
   **and** [s] is valid UTF-8, or the current Windows code page otherwise. If
   [out_size] is not [NULL], then the number of UTF-16 code units in the result
   is recorded in [*out_size].

   [size] must be greater than zero.

   The returned buffer is allocated with [caml_stat_alloc], so it should be
   freed using [caml_stat_free].

   If allocation fails, this raises Out_of_memory. This function may also raise
   [Sys_error] if [s] is not valid UTF-8.
*/
CAMLextern wchar_t *caml_stat_char_array_to_utf16(const char *s, size_t size,
                                                  size_t *out_size);

/* [caml_stat_char_array_of_utf16(s, size, &out_size)] returns a copy of the
   first [size] UTF-16 code units of [s] re-encoded in UTF-8 if
   [caml_windows_unicode_runtime_enabled] is non-zero or the current Windows
   code page otherwise. [s] does not have to be NUL-terminated and may contain
   embedded NUL characters. If [out_size] is not [NULL], then the size of the
   result in bytes recorded in [*out_size].

   [size] must be greater than zero.

   The returned buffer is allocated with [caml_stat_alloc], so it should be
   freed using [caml_stat_free].

   If allocation fails, this raises Out_of_memory. This function may also raise
   [Sys_error] if [s] is not valid UTF-16.
*/
CAMLextern char *caml_stat_char_array_of_utf16(const wchar_t *s, size_t size,
                                               size_t *out_size);

/* [caml_copy_string_of_utf16(s)] returns an OCaml string containing a copy of
   [s] re-encoded in UTF-8 if [caml_windows_unicode_runtime_enabled] is non-zero
   or in the current code page otherwise.
*/
CAMLextern value caml_copy_string_of_utf16(const wchar_t *s);

#endif /* _WIN32 */

#endif /* CAML_OSDEPS_H */
