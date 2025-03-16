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

#ifdef _WIN32

#define STRICT
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#if WINDOWS_UNICODE
#define CP CP_UTF8
#else
#define CP CP_ACP
#endif

#ifndef __has_attribute
#define __has_attribute(x) 0
#endif

#if __has_attribute(fallthrough)
  #define fallthrough __attribute__ ((fallthrough))
#else
  #define fallthrough ((void) 0)
#endif

/* mingw-w64 has a limits.h which defines PATH_MAX as an alias for MAX_PATH */
#if !defined(PATH_MAX)
#define PATH_MAX MAX_PATH
#endif

#define SEEK_END FILE_END

/* Initialised as the first statement of wmainCRTStartup */
static HANDLE hProcessHeap;

#define malloc(size) HeapAlloc(hProcessHeap, 0, (size))
#define free(memblock) HeapFree(hProcessHeap, 0, (memblock))

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

static void write_error(const wchar_t *wstr, HANDLE hOut)
{
  DWORD consoleMode, numwritten, len;
  char str[MAX_PATH];

  if (GetConsoleMode(hOut, &consoleMode) != 0) {
    /* The output stream is a Console */
    WriteConsole(hOut, wstr, lstrlen(wstr), &numwritten, NULL);
  } else { /* The output stream is redirected */
    len =
      WideCharToMultiByte(CP, 0, wstr, lstrlen(wstr), str, sizeof(str),
                          NULL, NULL);
    WriteFile(hOut, str, len, &numwritten, NULL);
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
#include <sys/types.h>

/* O_BINARY is defined in Gnulib, but is not POSIX */
#ifndef O_BINARY
#define O_BINARY 0
#endif

typedef int file_descriptor;

/* caml_search_in_system_path uses caml_stat_alloc */
void *caml_stat_alloc(size_t size)
{
  return malloc(size);
}

void caml_stat_free(void *ptr)
{
  free(ptr);
}

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

#endif /* defined(_WIN32) */

#define CAML_INTERNALS
#include "caml/exec.h"

static uint32_t read_size(const char *ptr)
{
  const unsigned char *p = (const unsigned char *)ptr;
  return ((uint32_t) p[0] << 24) | ((uint32_t) p[1] << 16) |
         ((uint32_t) p[2] << 8) | p[3];
}

static char * read_runtime_path(file_descriptor fd)
{
  char buffer[TRAILER_SIZE];
  static char runtime_path[PATH_MAX];
  int num_sections;
  uint32_t path_size;
  long ofs;

  if (lseek(fd, -TRAILER_SIZE, SEEK_END) == -1) return NULL;
  if (read(fd, buffer, TRAILER_SIZE) < TRAILER_SIZE) return NULL;
  num_sections = read_size(buffer);
  ofs = TRAILER_SIZE + num_sections * 8;
  if (lseek(fd, -ofs, SEEK_END) == -1) return NULL;
  path_size = 0;
  for (int i = 0; i < num_sections; i++) {
    if (read(fd, buffer, 8) < 8) return NULL;
    if (buffer[0] == 'R' && buffer[1] == 'N' &&
        buffer[2] == 'T' && buffer[3] == 'M') {
      path_size = read_size(buffer + 4);
      ofs += path_size;
    } else if (path_size > 0)
      ofs += read_size(buffer + 4);
  }
  if (path_size == 0) return NULL;
  if (path_size >= PATH_MAX) return NULL;
  if (lseek(fd, -ofs, SEEK_END) == -1) return NULL;
  if (read(fd, runtime_path, path_size) != path_size) return NULL;
  return runtime_path;
}

#ifdef _WIN32

#undef RtlMoveMemory
void __declspec(dllimport) __stdcall RtlMoveMemory(void *Destination,
                                                   const void *Source,
                                                   size_t Length);

NORETURN void __cdecl wmainCRTStartup(void)
{
  wchar_t truename[MAX_PATH];
  char *runtime_path;
  wchar_t wruntime_path[MAX_PATH];
  HANDLE h;
  STARTUPINFO stinfo;
  PROCESS_INFORMATION procinfo;
  DWORD retcode;

  hProcessHeap = GetProcessHeap();

  if (GetModuleFileName(NULL, truename, sizeof(truename)/sizeof(wchar_t)) == 0)
    exit_with_error(L"Out of memory", NULL, NULL);

  /* Mark the HANDLE as inheritable so ocamlrun can use it */
  SECURITY_ATTRIBUTES sa;
  sa.nLength = sizeof(sa);
  sa.lpSecurityDescriptor = NULL;
  sa.bInheritHandle = TRUE;
  h = CreateFile(truename, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE,
                 &sa, OPEN_EXISTING, 0, NULL);
  if (h == INVALID_HANDLE_VALUE ||
      (runtime_path = read_runtime_path(h)) == NULL ||
      !MultiByteToWideChar(CP, 0, runtime_path, -1, wruntime_path,
                           sizeof(wruntime_path)/sizeof(wchar_t)))
    exit_with_error(NULL, truename,
                    L" not found or is not a bytecode executable file");
  if (SearchPath(NULL, wruntime_path, L".exe", sizeof(truename)/sizeof(wchar_t),
                 truename, NULL)) {
    /* Need to ignore ctrl-C and ctrl-break, otherwise we'll die and take
       the underlying OCaml program with us! */
    SetConsoleCtrlHandler(ctrl_handler, TRUE);

    /* Retrieve the existing STARTUPINFO structure - however this header was
       invoked is morally how we should invoke ocamlrun, but we also need to
       set-up or augment the cbReserved2 / lpReserved2 members in order to pass
       the HANDLE h to ocamlrun as a CRT fd. The cloexec.ml test checks that
       existing fds are passed through successfully. The use of lpReserved2 by
       the CRT can be seen in the Universal CRT sources info exec/spawnv.cpp for
       the code which sets the buffer up and in lowio/ioinit.cpp which reads the
       buffer provided to the process. The semantics of this buffer are
       unchanged since the very beginning of Windows NT.
       It is a relatively well-documented "trick" to be able to pass up to 64KiB
       of information to a new process using lpReserved2, on condition that the
       data respects the CRTs requirements. The CRT processes lpReserved2 if it
       is not NULL and if cbReserved2 is non-zero - it performs no further
       checking beyond that. Applications can therefore embed additional data by
       setting cbReserved2 to the actual size of lpReserved2 and simply ensuring
       that the first 4 bytes pointed to by lpReserved2 are zero.
       Cygwin uses this mechanism when invoking processes to allow the Cygwin
       DLL to pick up the required information about the caller, amongst other
       things to implement fork (it's also used as part of argument passing).
       The code below must therefore cater for three cases:
       1. cbReserved2 == 0 / lpReserved2 == NULL, in which case the structure
          must be created
       2. cbReserved2 > 0 but there are fewer than 3 fds in the structure, in
          which case empty handles must be added so that our HANDLE is fd 3
       3. cbReserved2 > 0 and there are already 3 or more fds in the structure,
          in which case our HANDLE is appended to the end of the structure */
    GetStartupInfo(&stinfo);

    /* This header avoids the CRT to keep its size down - the Windows API
       doesn't have anything sprintf-like, however, the largest fd-number fits
       comfortably within a 16-bit wide character and we know that it will never
       be zero - the number of the fd is therefore passed to ocamlrun as a
       single wide-character string where the code-point represents the fd.
       Nemo nunc te poteste servare. */
    WCHAR fd[2] = {0, 0};

    /* Match the CRTs check - ignore the existing values if either cbReserved2
       is zero _or_ lpReserved2 is NULL */
    if (stinfo.cbReserved2 > 0 && stinfo.lpReserved2 == NULL)
      stinfo.cbReserved2 = 0;

    int existing_count = 0;
    /* Work out the fd number for h */
    if (stinfo.cbReserved2 > 0) {
      existing_count = *(int *)stinfo.lpReserved2;
      fd[0] = existing_count;
      /* If there is a structure present, but it has no fds, discard it. */
      if (existing_count == 0)
        stinfo.cbReserved2 = 0;
    }
    /* Allow for the standard handles */
    if (fd[0] < 3)
      fd[0] = 3;

    WORD buffer_size = sizeof(int) + (fd[0] + 1) * (1 + sizeof(HANDLE));
    LPBYTE buffer = (LPBYTE)malloc(buffer_size);

    /* Store the total number of handles */
    *(int *)buffer = fd[0] + 1;

    /* Copy the existing flags and HANDLEs */
    if (stinfo.cbReserved2 > 0) {
      RtlMoveMemory(buffer + sizeof(int), stinfo.lpReserved2 + sizeof(int),
                    existing_count);
      RtlMoveMemory(buffer + sizeof(int) + fd[0] + 1,
                    stinfo.lpReserved2 + sizeof(int) + existing_count,
                    existing_count * sizeof(HANDLE));
    }

    /* Pointers to the next slot for flags and the next slot for a HANDLE */
    LPBYTE osflags =
      buffer + sizeof(int) + existing_count;
    LPHANDLE oshandles =
      (LPHANDLE)(buffer + sizeof(int) + fd[0] + 1
                 + existing_count * sizeof(HANDLE));

    /* Ensure the standard fds are populated. Unrolled to prevent cl requiring
       the memset intrinsic. */
    switch (existing_count) {
      case 0:
        *osflags++ = 0;
        *oshandles++ = INVALID_HANDLE_VALUE;
        fallthrough;
      case 1:
        *osflags++ = 0;
        *oshandles++ = INVALID_HANDLE_VALUE;
        fallthrough;
      case 2:
        *osflags++ = 0;
        *oshandles++ = INVALID_HANDLE_VALUE;
    }

    /* Add h to the structure */
    *osflags = 1;
    *oshandles = h;

    stinfo.cbReserved2 = buffer_size;
    stinfo.lpReserved2 = buffer;

    SetEnvironmentVariable(L"__OCAML_EXEC_FD", fd);

    if (CreateProcess(truename, GetCommandLine(), NULL, NULL, TRUE, 0,
                      NULL, NULL, &stinfo, &procinfo)) {
      free(buffer);
      CloseHandle(procinfo.hThread);
      WaitForSingleObject(procinfo.hProcess, INFINITE);
      GetExitCodeProcess(procinfo.hProcess, &retcode);
      CloseHandle(procinfo.hProcess);
      ExitProcess(retcode);
    }
  }

  exit_with_error(L"Cannot exec ", wruntime_path, NULL);
}

#else

/* Borrowed from libcamlrun */
char * caml_search_in_system_path(const char *);
char * caml_executable_name(void);

int main(int argc, char *argv[])
{
  char *truename, *runtime_path;
  int fd;

  if (argc < 1)
    exit_with_error("Unable to load bytecode image", NULL, NULL);

  truename = caml_executable_name();
  if (truename == NULL) truename = caml_search_in_system_path(argv[0]);
  if (truename == NULL) truename = argv[0];
  fd = open(truename, O_RDONLY | O_BINARY);
  if (fd == -1 || (runtime_path = read_runtime_path(fd)) == NULL)
    exit_with_error(NULL, truename,
                    " not found or is not a bytecode executable file");

  size_t truename_len = strlen(truename);
  char *value = (char *)malloc(10 + 1 + truename_len + 1);
  snprintf(value, 11, "%u,", fd);
  strcat(value, truename);
#ifdef HAS_SETENV_UNSETENV
  setenv("__OCAML_EXEC_FD", value, 1);
#else
#error "Require a way to set environment variables"
#endif

  execvp(runtime_path, argv);

  exit_with_error("Cannot exec ", runtime_path, NULL);
}

#endif /* defined(_WIN32) */
