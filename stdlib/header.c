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

#define CAML_INTERNALS
#include "caml/exec.h"
#include "caml/s.h"

#include <errno.h>

#ifdef _WIN32

#define STRICT
#define WIN32_LEAN_AND_MEAN

typedef wchar_t char_os;
typedef wchar_t * argv_t;
#define T(x) L ## x
#define Is_separator(c) (c == '\\' || c == '/')
#define Directory_separator_character T('\\')
#define __ITOL(i) L ## #i
#define STRING_OF_INT(i) __ITOL(i)

#include <windows.h>
#include <strsafe.h>

#if WINDOWS_UNICODE
#define CP CP_UTF8
#else
#define CP CP_ACP
#endif

/* mingw-w64 has a limits.h which defines PATH_MAX as an alias for MAX_PATH */
#if !defined(PATH_MAX)
#define PATH_MAX MAX_PATH
#endif

#define lseek(h, offset, origin) SetFilePointer((h), (offset), NULL, (origin))
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

/* Initialised as the first statement of wmainCRTStartup */
static HANDLE hProcessHeap;

/* XXX Not ruled out delaying the use of malloc here - we just need something a
       _bit_ bigger than MAX_PATH to cope with these runtimes */
#define malloc(size) HeapAlloc(hProcessHeap, 0, (size))
#define free(memblock) HeapFree(hProcessHeap, 0, (memblock))

#define safe_copy(s1, s2, n) StringCchCopy(s1, n, s2)

static int exec_file(wchar_t * file, wchar_t * cmdline)
{
  wchar_t truename[MAX_PATH];
  STARTUPINFO stinfo;
  PROCESS_INFORMATION procinfo;
  DWORD retcode;

  if (SearchPath(NULL, file, L".exe", sizeof(truename)/sizeof(wchar_t),
                 truename, NULL)) {
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
      CloseHandle(procinfo.hThread);
      WaitForSingleObject(procinfo.hProcess, INFINITE);
      GetExitCodeProcess(procinfo.hProcess, &retcode);
      CloseHandle(procinfo.hProcess);
      ExitProcess(retcode);
    } else {
      return ENOEXEC;
    }
  } else {
    return ENOENT;
  }
}

#define R_OK 4
static int access(const wchar_t * path, int amode)
{
  return (GetFileAttributes(path) != INVALID_FILE_ATTRIBUTES);
}

static void write_error(const wchar_t * const wstr, HANDLE hOut)
{
  DWORD consoleMode, numwritten, len;
  char str[MAX_PATH];

  if (GetConsoleMode(hOut, &consoleMode) != 0) {
    /* The output stream is a Console */
    WriteConsole(hOut, wstr, wcslen(wstr), &numwritten, NULL);
  } else { /* The output stream is redirected */
    len =
      WideCharToMultiByte(CP, 0, wstr, wcslen(wstr), str, sizeof(str),
                          NULL, NULL);
    WriteFile(hOut, str, len, &numwritten, NULL);
  }
}

_Noreturn static void exit_with_error(const wchar_t * const wstr1,
                                      const wchar_t * const wstr2,
                                      const wchar_t * const wstr3)
{
  HANDLE hOut = GetStdHandle(STD_ERROR_HANDLE);
  if (wstr1) write_error(wstr1, hOut);
  if (wstr2) write_error(wstr2, hOut);
  if (wstr3) write_error(wstr3, hOut);
  write_error(L"\r\n", hOut);
  ExitProcess(2);
}

#else

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

typedef int HANDLE;

typedef char char_os;
typedef char ** argv_t;
#define T(x) x
#define Is_separator(c) (c == '/')
#define Directory_separator_character T('/')
#define STRING_OF_INT(i) #i

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

_Noreturn static void exit_with_error(const char * const str1,
                                      const char * const str2,
                                      const char * const str3)
{
  if (str1) fputs(str1, stderr);
  if (str2) fputs(str2, stderr);
  if (str3) fputs(str3, stderr);
  fputs("\n", stderr);
  exit(2);
}

int exec_file(const char * file, char * const argv[])
{
  return (execvp(file, argv) == -1 ? errno : 0);
}

#endif /* defined(_WIN32) */

static uint32_t read_size(const char * const ptr)
{
  const unsigned char * const p = (const unsigned char * const) ptr;
  return ((uint32_t) p[0] << 24) | ((uint32_t) p[1] << 16) |
         ((uint32_t) p[2] << 8) | p[3];
}

static char * read_runtime_path(HANDLE fd, uint32_t *path_size)
{
  char buffer[TRAILER_SIZE];
  char *result;
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
  if ((result = (char *)malloc(*path_size + 1)) == NULL) return NULL;
  if (read(fd, result, *path_size) != *path_size) return NULL;
  result[*path_size] = 0;

  return result;
}

_Noreturn void search_and_exec_runtime(char_os * rntm, uint32_t rntm_size,
                                       argv_t argv, char_os * argv0_dirname)
{
  const char_os *rntm_end = rntm + (rntm_size - 1);
  char_os *rntm_bindir_end = rntm;

  while (*rntm_bindir_end != 0)
    rntm_bindir_end++;

  if (*rntm != 0) {
    /* Absolute / Absolute_then_search (see bytecomp/bytelink.ml) */
    if (rntm_bindir_end != rntm_end)
      *rntm_bindir_end = Directory_separator_character;
    int status = exec_file(rntm, argv);
    if (rntm_bindir_end == rntm_end || status != ENOENT)
      exit_with_error(T("Cannot exec "), rntm, NULL);
  }

  char_os *root = NULL;
  char_os *root_basename = NULL;
  if (argv0_dirname != NULL) {
    /* Similarly - this could be a static buffer */
    root = (char_os *)malloc((PATH_MAX + 1) * sizeof(char_os));
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
    if (root) {
      safe_copy(root_basename, rntm, (rntm_end - rntm + 1));
      /* XXX Double-check, but if the file is _readable_ then we should proceed
             Note that ocamlrun needs to be able to read itself, so having it
             set as chmod +x is risky (in fact, does it error?)
         XXX Still not totally convinced by that - R_OK/X_OK still tbc */
      if (access(root, R_OK)) {
        if (exec_file(rntm, argv) != 0)
          exit_with_error(T("Cannot exec "), rntm, NULL);
      }
    }
    if (exec_file(rntm, argv) != ENOENT)
      exit_with_error(T("Cannot exec "), rntm, NULL);
  }

  exit_with_error(T("This program requires OCaml ")
                  STRING_OF_INT(OCAML_VERSION_MAJOR) T(".")
                  STRING_OF_INT(OCAML_VERSION_MINOR)
                  T("\nThe interpreter "), (rntm_bindir_end + 1),
                  T("could not be found."));
}

#ifdef _WIN32

_Noreturn void __cdecl wmainCRTStartup(void)
{
  wchar_t truename[MAX_PATH];
  wchar_t dirname[MAX_PATH];
  char * runtime_path;
  uint32_t rntm_size = 0;
  wchar_t * wruntime_path;
  HANDLE h;

  hProcessHeap = GetProcessHeap();

  if (GetModuleFileName(NULL, truename, sizeof(truename)/sizeof(wchar_t)) == 0
      || GetFullPathName(truename, sizeof(truename)/sizeof(wchar_t), dirname,
                         &wruntime_path) >= sizeof(truename)/sizeof(wchar_t))
    exit_with_error(L"Out of memory", NULL, NULL);
  *wruntime_path = 0;

  h = CreateFile(truename, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE,
                 NULL, OPEN_EXISTING, 0, NULL);
  if (h == INVALID_HANDLE_VALUE
      || (runtime_path = read_runtime_path(h, &rntm_size)) == NULL
      || (wruntime_path =
           (wchar_t *)malloc((rntm_size + 1) * sizeof(wchar_t))) == NULL
      || (rntm_size = MultiByteToWideChar(CP, 0, runtime_path, rntm_size + 1,
                                          wruntime_path, rntm_size + 1)) == 0)
    exit_with_error(NULL, truename,
                    L" not found or is not a bytecode executable file");
  CloseHandle(h);
  free(runtime_path);
  search_and_exec_runtime(wruntime_path, rntm_size, GetCommandLine(), dirname);
}

#else

int main(int argc, char ** argv)
{
  char * truename, * runtime_path, * argv0_dirname;
  uint32_t rntm_size = 0;
  int fd;

  truename = searchpath(argv[0]);
  fd = open(truename, O_RDONLY | O_BINARY);
  if (fd == -1 || (runtime_path = read_runtime_path(fd, &rntm_size)) == NULL)
    exit_with_error(NULL, truename,
                    " not found or is not a bytecode executable file");
  close(fd);

#ifdef HAS_LIBGEN_H
  argv0_dirname = dirname(strdup(truename));
  if (*argv0_dirname == '.')
#endif
    argv0_dirname = NULL;

  argv[0] = truename;
  search_and_exec_runtime(runtime_path, rntm_size + 1, argv, argv0_dirname);
}

#endif /* defined(_WIN32) */
