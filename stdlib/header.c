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

#include <errno.h>

#ifdef _WIN32

#define STRICT
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

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

static void exec_file(wchar_t *file, wchar_t *cmdline)
{
  LPWSTR truename = (LPWSTR)malloc(PATH_MAX * sizeof(WCHAR));
  STARTUPINFO stinfo;
  PROCESS_INFORMATION procinfo;
  DWORD retcode;

  if (truename && SearchPath(NULL, file, L".exe", PATH_MAX, truename, NULL)) {
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
    }
  }

  free(truename);
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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <limits.h>
#include <sys/types.h>
#include <sys/stat.h>

/* O_BINARY is defined in Gnulib, but is not POSIX */
#ifndef O_BINARY
#define O_BINARY 0
#endif

typedef int file_descriptor;

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

static void exec_file(const char *file, char * const argv[])
{
  execvp(file, argv);
}

#endif /* defined(_WIN32) */

#define CAML_INTERNALS
#include "caml/exec.h"

static uint32_t read_size(const char *ptr)
{
  const unsigned char *p = (const unsigned char *)ptr;
  return ((uint32_t) p[0] << 24) | ((uint32_t) p[1] << 16) |
         ((uint32_t) p[2] << 8) | p[3];
}

static char * read_runtime_path(file_descriptor fd, uint32_t *rntm_strlen)
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
  *rntm_strlen = 0;
  for (int i = 0; i < num_sections; i++) {
    if (read(fd, buffer, 8) < 8) return NULL;
    if (buffer[0] == 'R' && buffer[1] == 'N' &&
        buffer[2] == 'T' && buffer[3] == 'M') {
      *rntm_strlen = read_size(buffer + 4);
      ofs += *rntm_strlen;
    } else if (*rntm_strlen > 0)
      ofs += read_size(buffer + 4);
  }
  if (*rntm_strlen == 0) return NULL;
  if (*rntm_strlen >= PATH_MAX) return NULL;
  if (lseek(fd, -ofs, SEEK_END) == -1) return NULL;
  if ((runtime_path = (char *)malloc(*rntm_strlen + 1)) == NULL) return NULL;
  if (read(fd, runtime_path, *rntm_strlen) != *rntm_strlen) return NULL;
  runtime_path[*rntm_strlen] = 0;
  return runtime_path;
}

#ifdef _WIN32

NORETURN void __cdecl wmainCRTStartup(void)
{
  LPWSTR truename;
  uint32_t rntm_strlen = 0;
  char *runtime_path;
  wchar_t *wruntime_path;
  HANDLE h;

  hProcessHeap = GetProcessHeap();

  truename = (LPWSTR)malloc(PATH_MAX * sizeof(WCHAR));

  if (truename == NULL || GetModuleFileName(NULL, truename, PATH_MAX) == 0)
    exit_with_error(L"Out of memory", NULL, NULL);

  h = CreateFile(truename, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE,
                 NULL, OPEN_EXISTING, 0, NULL);
  if (h == INVALID_HANDLE_VALUE ||
      (runtime_path = read_runtime_path(h, &rntm_strlen)) == NULL ||
      (wruntime_path =
         (wchar_t *)malloc((rntm_strlen + 1) * sizeof(wchar_t))) == NULL ||
      !MultiByteToWideChar(CP, 0, runtime_path, rntm_strlen + 1,
                           wruntime_path, rntm_strlen + 1))
    exit_with_error(NULL, truename,
                    L" not found or is not a bytecode executable file");
  CloseHandle(h);
  free(runtime_path);
  free(truename);
  exec_file(wruntime_path, GetCommandLine());

  exit_with_error(L"Cannot exec ", wruntime_path, NULL);
}

#else

int main(int argc, char *argv[])
{
  char *truename, *runtime_path;
  uint32_t rntm_strlen = 0;
  int fd;

  truename = searchpath(argv[0]);
  fd = open(truename, O_RDONLY | O_BINARY);
  if (fd == -1 || (runtime_path = read_runtime_path(fd, &rntm_strlen)) == NULL)
    exit_with_error(NULL, truename,
                    " not found or is not a bytecode executable file");
  close(fd);

  argv[0] = truename;
  exec_file(runtime_path, argv);

  exit_with_error("Cannot exec ", runtime_path, NULL);
}

#endif /* defined(_WIN32) */
