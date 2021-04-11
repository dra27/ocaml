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

/* The launcher for bytecode executables (if #! is not available) */

/* C11's _Noreturn is deprecated in C23 in favour of attributes */
#if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 202311L
  #define NORETURN [[noreturn]]
#else
  #define NORETURN _Noreturn
#endif

#include <stdbool.h>
#include <errno.h>

#ifdef _WIN32

#define STRICT
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

typedef wchar_t char_os;
typedef wchar_t * argv_t;
#define T(x) L ## x
#define Is_separator(c) (c == '\\' || c == '/')
#define Directory_separator_character T('\\')
#define ITOL(i) L ## #i
#define ITOT(i) ITOL(i)
#define PATH_NAME L"%Path%"

/* The header is written to be able to cope with paths greater than MAX_PATH,
   so undefine it to stop it being used in error. */
#undef MAX_PATH

#if defined(__MINGW32__) && defined(PATH_MAX)
/* mingw-w64 has a limits.h which defines PATH_MAX as an alias for MAX_PATH */
#undef PATH_MAX
#endif

#if WINDOWS_UNICODE
#define CP CP_UTF8
#else
#define CP CP_ACP
#endif

/* The maximum representable path for any API function, after internal expansion
   of \\?\ etc. is 32767 characters. PATH_MAX includes the terminator. */
#define PATH_MAX 0x8000

/* Initialised as the first statement of wmainCRTStartup */
static HANDLE hProcessHeap;

#define malloc(size) HeapAlloc(hProcessHeap, 0, (size))
#define free(memblock) HeapFree(hProcessHeap, 0, (memblock))

#define SEEK_END FILE_END

#define lseek(h, offset, origin) SetFilePointer((h), (offset), NULL, (origin))

typedef HANDLE file_descriptor;

static int read(HANDLE h, LPVOID buffer, DWORD buffer_size)
{
  DWORD nread = 0;
  ReadFile(h, buffer, buffer_size, &nread, NULL);
  return nread;
}

static BOOL WINAPI ctrl_handler(DWORD event)
{
  if (event == CTRL_C_EVENT || event == CTRL_BREAK_EVENT)
    return TRUE;                /* pretend we've handled them */
  else
    return FALSE;
}

#define safe_copy(s1, s2, n) lstrcpy(s1, s2)

static int exec_file(wchar_t *file, wchar_t *cmdline)
{
  LPWSTR truename = (LPWSTR)malloc(PATH_MAX * sizeof(WCHAR));
  STARTUPINFO stinfo;
  PROCESS_INFORMATION procinfo;
  DWORD retcode;

  if (truename == NULL)
    return ENOMEM;

  if (SearchPath(NULL, file, L".exe", PATH_MAX, truename, NULL)) {
    /* Need to ignore ctrl-C and ctrl-break, otherwise we'll die and take the
       underlying OCaml program with us! */
    SetConsoleCtrlHandler(ctrl_handler, TRUE);

    stinfo.cb = sizeof(stinfo);
    stinfo.lpReserved = NULL;
    stinfo.lpDesktop = NULL;
    stinfo.lpTitle = NULL;
    stinfo.dwFlags = 0;
    stinfo.cbReserved2 = 0;
    stinfo.lpReserved2 = NULL;
    if (CreateProcess(truename, cmdline, NULL, NULL, TRUE, 0, NULL, NULL,
                      &stinfo, &procinfo)) {
      free(truename);
      CloseHandle(procinfo.hThread);
      WaitForSingleObject(procinfo.hProcess, INFINITE);
      GetExitCodeProcess(procinfo.hProcess, &retcode);
      CloseHandle(procinfo.hProcess);
      ExitProcess(retcode);
    } else {
      free(truename);
      return ENOEXEC;
    }
  } else {
    return ENOENT;
  }
}

static bool file_exists(const wchar_t *file)
{
  return (GetFileAttributes(file) != INVALID_FILE_ATTRIBUTES);
}

static void write_error(const wchar_t *wstr, HANDLE hOut)
{
  DWORD consoleMode, numwritten, len;
  char *str;

  if (GetConsoleMode(hOut, &consoleMode) != 0) {
    /* The output stream is a Console */
    WriteConsole(hOut, wstr, lstrlen(wstr), &numwritten, NULL);
  } else { /* The output stream is redirected */
    len = WideCharToMultiByte(CP, 0, wstr, -1, NULL, 0, NULL, NULL);
    str = (char *)malloc(len);
    WideCharToMultiByte(CP, 0, wstr, -1, str, len, NULL, NULL);
    /* len includes the terminator */
    WriteFile(hOut, str, len - 1, &numwritten, NULL);
  }
}

NORETURN static void exit_with_error(const wchar_t *wstr1,
                                     const wchar_t *wstr2,
                                     const wchar_t *wstr3)
{
  HANDLE hOut = GetStdHandle(STD_ERROR_HANDLE);
  if (wstr1) write_error(wstr1, hOut);
  if (wstr2) write_error(wstr2, hOut);
  if (wstr3) write_error(wstr3, hOut);
  write_error(L"\r\n", hOut);
  ExitProcess(2);
}

#else

#include "caml/s.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <limits.h>
#ifdef HAS_LIBGEN_H
#include <libgen.h>
#endif
#include <sys/types.h>
#include <sys/stat.h>

/* O_BINARY is defined in Gnulib, but is not POSIX */
#ifndef O_BINARY
#define O_BINARY 0
#endif

typedef int file_descriptor;

typedef char char_os;
typedef char ** argv_t;
#define T(x) x
#define Is_separator(c) (c == '/')
#define Directory_separator_character '/'
#define ITOL(x) #x
#define ITOT(x) ITOL(x)
#define PATH_NAME "$PATH"

#ifdef HAS_STRLCPY
#define safe_copy strlcpy
#else
#define safe_copy(s1, s2, n) strcpy(s1, s2)
#endif

#ifndef __CYGWIN__

/* Normal Unix search path function */

static char * searchpath(char * name)
{
  static char fullname[PATH_MAX + 1];
  char * path;
  struct stat st;

  for (char *p = name; *p != 0; p++) {
    if (*p == '/') return name;
  }
  path = getenv("PATH");
  if (path == NULL) return name;
  while(1) {
    char * p;
    for (p = fullname; *path != 0 && *path != ':'; p++, path++)
      if (p < fullname + PATH_MAX) *p = *path;
    if (p != fullname && p < fullname + PATH_MAX)
      *p++ = '/';
    for (char *q = name; *q != 0; p++, q++)
      if (p < fullname + PATH_MAX) *p = *q;
    *p = 0;
    if (stat(fullname, &st) == 0 && S_ISREG(st.st_mode)) break;
    if (*path == 0) return name;
    path++;
  }
  return fullname;
}

#else

/* Special version for Cygwin32: takes care of the ".exe" implicit suffix */

static int file_ok(char * name)
{
  int fd;
  /* Cannot use stat() here because it adds ".exe" implicitly */
  fd = open(name, O_RDONLY);
  if (fd == -1) return 0;
  close(fd);
  return 1;
}

static char * searchpath(char * name)
{
  char * path, * fullname;

  path = getenv("PATH");
  fullname = malloc(strlen(name) + (path == NULL ? 0 : strlen(path)) + 6);
  /* 6 = "/" plus ".exe" plus final "\0" */
  if (fullname == NULL) return name;
  /* Check for absolute path name */
  for (char *p = name; *p != 0; p++) {
    if (*p == '/' || *p == '\\') {
      if (file_ok(name)) return name;
      strcpy(fullname, name);
      strcat(fullname, ".exe");
      if (file_ok(fullname)) return fullname;
      return name;
    }
  }
  /* Search in path */
  if (path == NULL) return name;
  while(1) {
    char * p;
    for (p = fullname; *path != 0 && *path != ':'; p++, path++) *p = *path;
    if (p != fullname) *p++ = '/';
    strcpy(p, name);
    if (file_ok(fullname)) return fullname;
    strcat(fullname, ".exe");
    if (file_ok(fullname)) return fullname;
    if (*path == 0) break;
    path++;
  }
  return name;
}

#endif

NORETURN static void exit_with_error(const char *str1,
                                     const char *str2,
                                     const char *str3)
{
  if (str1) fputs(str1, stderr);
  if (str2) fputs(str2, stderr);
  if (str3) fputs(str3, stderr);
  fputs("\n", stderr);
  exit(2);
}

static int exec_file(const char *file, char * const argv[])
{
  return (execvp(file, argv) == -1 ? errno : 0);
}

static bool file_exists(const char *file)
{
  struct stat st;
  return (lstat(file, &st) == 0);
}

#endif /* defined(_WIN32) */

#include "caml/version.h"
#define SHORT_VERSION ITOT(OCAML_VERSION_MAJOR) T(".") ITOT(OCAML_VERSION_MINOR)

#define CAML_INTERNALS
#include "caml/exec.h"

static uint32_t read_size(const char *ptr)
{
  const unsigned char *p = (const unsigned char *)ptr;
  return ((uint32_t) p[0] << 24) | ((uint32_t) p[1] << 16) |
         ((uint32_t) p[2] << 8) | p[3];
}

static char * read_runtime_path(file_descriptor fd, uint32_t *path_size)
{
  char buffer[TRAILER_SIZE];
  char *runtime_path;
  int num_sections;
  long ofs;

  if (lseek(fd, -TRAILER_SIZE, SEEK_END) == -1) return NULL;
  if (read(fd, buffer, TRAILER_SIZE) < TRAILER_SIZE) return NULL;
  num_sections = read_size(buffer);
  ofs = TRAILER_SIZE + num_sections * 8;
  if (lseek(fd, -ofs, SEEK_END) == -1) return NULL;
  for (int i = 0; i < num_sections; i++) {
    if (read(fd, buffer, 8) < 8) return NULL;
    if (buffer[0] == 'R' && buffer[1] == 'N' &&
        buffer[2] == 'T' && buffer[3] == 'M') {
      *path_size = read_size(buffer + 4);
      ofs += *path_size;
    } else if (*path_size > 0)
      ofs += read_size(buffer + 4);
  }
  if (*path_size == 0) return NULL;
  if (lseek(fd, -ofs, SEEK_END) == -1) return NULL;
  if ((runtime_path = (char *)malloc(*path_size + 1)) == NULL) return NULL;
  if (read(fd, runtime_path, *path_size) != *path_size) return NULL;
  runtime_path[*path_size] = 0;

  return runtime_path;
}

NORETURN void search_and_exec_runtime(char_os *rntm, uint32_t rntm_bsz,
                                      argv_t argv, char_os *argv0_dirname)
{
  char_os *rntm_end = rntm + (rntm_bsz - 1);
  char_os *rntm_bindir_end = rntm;
  char_os *zinc = NULL;
  char_os *zinc_offset = NULL;
  char_os *current_quintet = NULL;

  while (*rntm_bindir_end != 0)
    rntm_bindir_end++;

  if (*rntm != 0) {
    /* Legacy RNTM: single string with an extra "\0" character. Interpret this
       as "Absolute". In particular, for Windows, where boot/ocamlc will be
       writing "ocamlrun\0" for RNTM, this actually maintains the required
       "Search" behaviour! This can be removed after a bootstrap. */
    if (rntm_bindir_end + 1 == rntm_end)
      rntm_bindir_end++;
    /* Absolute / Absolute_then_search (see bytecomp/bytelink.ml) */
    if (rntm_bindir_end != rntm_end)
      *rntm_bindir_end = Directory_separator_character;
    int status = exec_file(rntm, argv);
    if (rntm_bindir_end == rntm_end || status != ENOENT)
      exit_with_error(T("Cannot exec "), rntm, NULL);
  }

  char_os *root = (char_os *)malloc((PATH_MAX + 1) * sizeof(char_os));
  char_os *root_basename = NULL;
  if (argv0_dirname != NULL) {
    safe_copy(root, argv0_dirname, PATH_MAX + 1);
    root_basename = root;
    while (*root_basename != 0)
      root_basename++;
    if (root_basename > root && !Is_separator(*(root_basename - 1)))
      *root_basename++ = Directory_separator_character;
    /* root if non-NULL now points to the directory name with root_basename
       pointing to the location at which to place filenames */
  }

  rntm = rntm_bindir_end + 1;
  if (rntm < rntm_end) {
    zinc = rntm;
    while (*zinc != 0)
      zinc++;
    if (zinc != rntm_end) {
      rntm_end = zinc;
      zinc++;
      zinc_offset = rntm_end - *zinc;
      zinc++;
    }

    bool searched_all = (root_basename == NULL || zinc == rntm_end);
    current_quintet = zinc;
    do {
      if (zinc_offset) {
        if (*current_quintet == '/') {
          if (searched_all) {
            current_quintet++;
          } else {
            searched_all = true;
            current_quintet = zinc;
          }
          continue;
        }
        *zinc_offset = *current_quintet;
        current_quintet++;
      }
      /* rntm points to the name of the runtime from the RNTM section; root, if
         non-NULL, is the directory containing the current running executable
         (i.e. this program) */
      if (root_basename) {
        safe_copy(root_basename, rntm, (rntm_end - rntm + 1));
        /* If a directory entry with the name of the runtime exists in the same
           directory as the executable, it will be exec'd (even if that results
           in an error) */
        if (file_exists(root)) {
          if (exec_file(root, argv) != 0)
            exit_with_error(T("Cannot exec "), root, NULL);
        }
      }
      if (searched_all && exec_file(rntm, argv) != ENOENT)
        exit_with_error(T("Cannot exec "), rntm, NULL);
    } while (*current_quintet != 0);
  }

  if (zinc != rntm_end) {
    safe_copy(root, rntm, (zinc_offset - rntm + 1));
    char_os *current = root + (zinc_offset - rntm);
    *current++ = '[';
    while (*current_quintet != '/')
      current_quintet--;
    *current_quintet = 0;
    safe_copy(current, zinc, (current_quintet - zinc + 1));
    current += (current_quintet - zinc);
    *current++ = ']';
    safe_copy(current, zinc_offset + 1, (zinc - zinc_offset));
  } else {
    root = rntm_bindir_end + 1;
  }
  exit_with_error(T("This program requires an OCaml ") SHORT_VERSION
                  T(" interpreter\n"), root,
                  T(" not found with the program or in " PATH_NAME));
}

#ifdef _WIN32

NORETURN void __cdecl wmainCRTStartup(void)
{
  LPWSTR truename;
  LPWSTR dirname;
  uint32_t rntm_strlen = 0, rntm_bsz = 0;
  char *runtime_path;
  wchar_t *wruntime_path, *basename;
  HANDLE h;

  hProcessHeap = GetProcessHeap();

  truename = (LPWSTR)malloc(PATH_MAX * sizeof(WCHAR));
  dirname = (LPWSTR)malloc(PATH_MAX * sizeof(WCHAR));

  if (truename == NULL || dirname == NULL
     || GetModuleFileName(NULL, truename, PATH_MAX) == 0
     || GetFullPathName(truename, PATH_MAX, dirname, &basename) >= PATH_MAX)
    exit_with_error(L"Out of memory", NULL, NULL);
  *basename = 0;

  h = CreateFile(truename, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE,
                 NULL, OPEN_EXISTING, 0, NULL);
  if (h == INVALID_HANDLE_VALUE
      || (runtime_path = read_runtime_path(h, &rntm_strlen)) == NULL
      || (wruntime_path =
            (wchar_t *)malloc((rntm_strlen + 1) * sizeof(wchar_t))) == NULL
      || (rntm_bsz = MultiByteToWideChar(CP, 0, runtime_path, rntm_strlen + 1,
                                         wruntime_path, rntm_strlen + 1)) == 0)
    exit_with_error(NULL, truename,
                    L" not found or is not a bytecode executable file");
  CloseHandle(h);
  free(runtime_path);
  free(truename);
  search_and_exec_runtime(wruntime_path, rntm_bsz, GetCommandLine(), dirname);
}

#else

int main(int argc, char *argv[])
{
  char *truename, *runtime_path, *argv0_dirname;
  uint32_t rntm_strlen = 0;
  int fd;

  truename = searchpath(argv[0]);
  fd = open(truename, O_RDONLY | O_BINARY);
  if (fd == -1 || (runtime_path = read_runtime_path(fd, &rntm_strlen)) == NULL)
    exit_with_error(NULL, truename,
                    " not found or is not a bytecode executable file");
  close(fd);

#ifdef HAS_LIBGEN_H
  argv0_dirname = dirname(strdup(truename));
#else
  argv0_dirname = NULL;
#endif

  argv[0] = truename;
  search_and_exec_runtime(runtime_path, rntm_strlen + 1, argv, argv0_dirname);
}

#endif /* defined(_WIN32) */
