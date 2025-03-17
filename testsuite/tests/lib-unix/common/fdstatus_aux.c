/* Check if file descriptors are open or not */

#ifdef _WIN32
#define _CRT_NONSTDC_NO_WARNINGS
#include <io.h>
#else
#include <unistd.h>
#endif

#include <stdio.h>
#include <stdlib.h>
#include <limits.h>
#include <string.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>

void process_fd(const char * s)
{
  long n;
  int fd;
  char * endp;
  struct stat st;
  n = strtol(s, &endp, 0);
  if (*endp != 0 || n < 0 || n > (long) INT_MAX) {
    printf("parsing error\n");
    return;
  }
  fd = (int) n;
  if (fstat(fd, &st) != -1) {
    printf("open\n");
    close(fd);
  } else if (errno == EBADF) {
    printf("closed\n");
  } else {
    printf("error %s\n", strerror(errno));
  }
}

#include <caml/mlvalues.h>
#include <caml/memory.h>
#include <caml/unixsupport.h>

CAMLprim value caml_process_fd(value CAMLnum, value CAMLfd)
{
  CAMLparam2(CAMLnum, CAMLfd);
  printf("#%d: ", Int_val(CAMLnum));
  process_fd(String_val(CAMLfd));
  CAMLreturn(Val_unit);
}

CAMLprim value caml_fd_of_filedescr(value v)
{
  CAMLparam1(v);

#ifdef _WIN32
  int fd = caml_win32_CRT_fd_of_filedescr(v);
#else
  int fd = Int_val(v);
#endif

  CAMLreturn(Val_int(fd));
}
