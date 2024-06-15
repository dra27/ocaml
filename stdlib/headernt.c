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

#define CAML_INTERNALS

#define STRICT
#define WIN32_LEAN_AND_MEAN

#include <windows.h>
#include "caml/mlvalues.h"
#include "caml/exec.h"

#ifndef __MINGW32__
#pragma comment(linker , "/subsystem:console")
#pragma comment(lib , "kernel32")
#ifdef _UCRT
#pragma comment(lib , "ucrt.lib")
#pragma comment(lib , "vcruntime.lib")
#endif
#endif

static
#if _MSC_VER >= 1200
__forceinline
#else
__inline
#endif
unsigned long read_size(const char * const ptr)
{
  const unsigned char * const p = (const unsigned char * const) ptr;
  return ((unsigned long) p[0] << 24) | ((unsigned long) p[1] << 16) |
         ((unsigned long) p[2] << 8) | p[3];
}

static __inline char ** read_runtime_path(HANDLE h, char ** full_runtime)
{
  char buffer[TRAILER_SIZE];
  static char abs_runtime_path_buf[MAX_PATH];
  static char runtime_path_buf[1024];
  static char *runtimes[4] = {NULL, NULL, NULL, NULL};
  char *abs_runtime_path = abs_runtime_path_buf;
  char *runtime_path = runtime_path_buf;
  DWORD nread;
  int num_sections, path_size, i, j;
  long ofs;

  if (SetFilePointer(h, -TRAILER_SIZE, NULL, FILE_END) == -1) return NULL;
  if (! ReadFile(h, buffer, TRAILER_SIZE, &nread, NULL)) return NULL;
  if (nread != TRAILER_SIZE) return NULL;
  num_sections = read_size(buffer);
  ofs = TRAILER_SIZE + num_sections * 8;
  if (SetFilePointer(h, - ofs, NULL, FILE_END) == -1) return NULL;
  path_size = 0;
  for (i = 0; i < num_sections; i++) {
    if (! ReadFile(h, buffer, 8, &nread, NULL) || nread != 8) return NULL;
    if (buffer[0] == 'R' && buffer[1] == 'N' &&
        buffer[2] == 'T' && buffer[3] == 'M') {
      path_size = read_size(buffer + 4);
      ofs += path_size;
    } else if (path_size > 0)
      ofs += read_size(buffer + 4);
  }
  if (path_size < 2) return NULL;
  if (path_size >= 1024) return NULL;
  if (SetFilePointer(h, -ofs, NULL, FILE_END) == -1) return NULL;
  if (! ReadFile(h, runtime_path, path_size, &nread, NULL)) return NULL;
  if (nread != path_size) return NULL;
  if (*runtime_path != 0) {
    /* RNTM includes includes a full path to the runtime */
    *full_runtime = abs_runtime_path;
    /* Copy the first segment of runtime_path to abs_runtime_path */
    i = 0;
    do {
      *abs_runtime_path++ = *runtime_path++;
    } while (++i < nread && *runtime_path != 0);
    if (i == nread) {
      /* RNTM is just a full path to a runtime - no searching */
      *abs_runtime_path = 0;
      return runtimes;
    }
    runtime_path++;
    j = 1;
    runtimes[0] = runtime_path;
    while (++i < nread && *runtime_path != 0)
      *abs_runtime_path++ = *runtime_path++;
    *abs_runtime_path = 0;
    /* Corrupt RNTM section - there should be a null terminator */
    if (*runtime_path != 0)
      return NULL;
    runtime_path++;
  } else {
    /* --enable-runtime-search=always mode - no directory version */
    runtime_path++;
    i = 1;
    j = 0;
  }
  /* Add the additional runtimes to the list */
  while (j < 3 && i < nread) {
    runtimes[j++] = runtime_path;
    while (++i < nread && *runtime_path != 0) runtime_path++;
    /* Corrupt RNTM section - there should be a null terminator */
    if (*runtime_path != 0)
      return NULL;
    else
      runtime_path++;
  }
  return runtimes;
}

static BOOL WINAPI ctrl_handler(DWORD event)
{
  if (event == CTRL_C_EVENT || event == CTRL_BREAK_EVENT)
    return TRUE;                /* pretend we've handled them */
  else
    return FALSE;
}

#if WINDOWS_UNICODE
#define CP CP_UTF8
#else
#define CP CP_ACP
#endif

static void write_console(HANDLE hOut, WCHAR *wstr)
{
  DWORD consoleMode, numwritten, len;
  static char str[MAX_PATH];

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

static __inline void __declspec(noreturn) exec_runtime(wchar_t *path,
                                                      wchar_t * const cmdline)
{
  STARTUPINFO stinfo;
  PROCESS_INFORMATION procinfo;
  DWORD retcode;

  /* Need to ignore ctrl-C and ctrl-break, otherwise we'll die and take
     the underlying OCaml program with us! */
  SetConsoleCtrlHandler(ctrl_handler, TRUE);

  stinfo.cb = sizeof(stinfo);
  stinfo.lpReserved = NULL;
  stinfo.lpDesktop = NULL;
  stinfo.lpTitle = NULL;
  stinfo.dwFlags = 0;
  stinfo.cbReserved2 = 0;
  stinfo.lpReserved2 = NULL;
  if (!CreateProcess(path, cmdline, NULL, NULL, TRUE, 0, NULL, NULL,
                     &stinfo, &procinfo)) {
    HANDLE errh;
    errh = GetStdHandle(STD_ERROR_HANDLE);
    write_console(errh, L"Cannot exec ");
    write_console(errh, path);
    write_console(errh, L"\r\n");
    ExitProcess(2);
#if _MSC_VER >= 1200
    __assume(0); /* Not reached */
#endif
  }
  CloseHandle(procinfo.hThread);
  WaitForSingleObject(procinfo.hProcess , INFINITE);
  GetExitCodeProcess(procinfo.hProcess , &retcode);
  CloseHandle(procinfo.hProcess);
  ExitProcess(retcode);
#if _MSC_VER >= 1200
    __assume(0); /* Not reached */
#endif
}

static __inline wchar_t *search_runtime(wchar_t * runtime,
         wchar_t *dirname, wchar_t *basename)
{
  wchar_t path_buf[MAX_PATH];
  wchar_t *path = path_buf;
  wchar_t *dontcare;
  if (dirname != NULL) {
    /* Mustn't use CRT (or the lie about the size) */
    wcscpy_s(basename, MAX_PATH, runtime);
    if (GetFileAttributes(dirname) != INVALID_FILE_ATTRIBUTES)
      path = dirname;
    else
      dirname = NULL;
  }

  if (dirname == NULL && SearchPath(NULL, runtime, L".exe", MAX_PATH,
                 path, &dontcare) == 0)
    return NULL;

  return path;
}

#define __ITOL(i) L ## #i
#define _ITOL(i) __ITOL(i)

int wmain(void)
{
  wchar_t truename[MAX_PATH];
  wchar_t truedir_buf[MAX_PATH];
  wchar_t * truedir = truedir_buf;
  wchar_t * truebasename;
  wchar_t * cmdline = GetCommandLine();
  wchar_t *runtime;
  char * full_runtime = NULL;
  char ** runtime_paths;
  wchar_t wruntime_path[MAX_PATH];
  HANDLE h, errh;

  GetModuleFileName(NULL, truename, MAX_PATH);
  h = CreateFile(truename, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE,
                 NULL, OPEN_EXISTING, 0, NULL);
  if (h == INVALID_HANDLE_VALUE ||
      (runtime_paths = read_runtime_path(h, &full_runtime)) == NULL) {
    errh = GetStdHandle(STD_ERROR_HANDLE);
    write_console(errh, truename);
    write_console(errh, L" not found or is not a bytecode executable file\r\n");
    ExitProcess(2);
#if _MSC_VER >= 1200
    __assume(0); /* Not reached */
#endif
  }
  CloseHandle(h);
  if (full_runtime != NULL) {
    wchar_t resolved_runtime[MAX_PATH];
    wchar_t *dummy;
    MultiByteToWideChar(CP, 0, full_runtime, -1, wruntime_path, MAX_PATH);
    SearchPath(L"", wruntime_path, L".exe", MAX_PATH, resolved_runtime, &dummy);
    if (GetFileAttributes(resolved_runtime) != INVALID_FILE_ATTRIBUTES) {
      exec_runtime(resolved_runtime, cmdline);
#if _MSC_VER >= 1200
    __assume(0); /* Not reached */
#endif
    }
  }
  /* XXX More error handling? */
  GetFullPathName(truename, MAX_PATH, truedir, &truebasename);
  if (truebasename == NULL) {
    truedir = NULL;
  } else if (*(truebasename - 1) == '\\') {
    *truebasename = 0;
  } else {
    *truebasename++ = '\\';
    *truebasename = 0;
  }
  while (*runtime_paths != 0) {
    MultiByteToWideChar(CP, 0, *runtime_paths, -1, wruntime_path, MAX_PATH);
    if (*wruntime_path != 0) {
      runtime = search_runtime(wruntime_path, truedir, truebasename);
      if (runtime != NULL)
        exec_runtime(runtime, cmdline);
    }
    runtime_paths++;
  }
  errh = GetStdHandle(STD_ERROR_HANDLE);
  write_console(errh, L"This program requires OCaml "
                      _ITOL(OCAML_VERSION_MAJOR) L"." _ITOL(OCAML_VERSION_MINOR)
                      L"\n");
  write_console(errh, L"The interpreter (");
  if (runtime_paths[0] == NULL) {
    /* XXX Don't repeat the conversion! */
    MultiByteToWideChar(CP, 0, full_runtime, -1, wruntime_path, MAX_PATH);
    write_console(errh, wruntime_path);
  } else {
    /* XXX Don't repeat the conversion! */
    MultiByteToWideChar(CP, 0, runtime_paths[0], -1, wruntime_path, MAX_PATH);
    write_console(errh, wruntime_path);
  }
  write_console(errh, L") was not found");
  if (runtime_paths[0] != NULL) {
    write_console(errh, L"either with ");
    write_console(errh, truename);
    write_console(errh, L" or in PATH\n");
  } else {
    write_console(errh, L"\n");
  }
  ExitProcess(2);
#if _MSC_VER >= 1200
    __assume(0); /* Not reached */
#endif
#ifdef __MINGW32__
    return 0;
#endif
}
