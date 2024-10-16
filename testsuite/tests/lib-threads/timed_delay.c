#define CAML_INTERNALS

#include <caml/mlvalues.h>
#include <caml/alloc.h>
#include <caml/signals.h>
#include <caml/fail.h>

#ifdef _WIN32
#include <windows.h>
#else
#include <errno.h>
#include <time.h>
#endif

double caml_unix_gettimeofday_unboxed(value);

CAMLprim value caml_thread_timed_delay(value v_duration)
{
  double duration = Double_val(v_duration);
  double result = 0.0;

  caml_enter_blocking_section();
#ifdef _WIN32
  result = caml_unix_gettimeofday_unboxed(Val_unit);
  Sleep((DWORD)(duration * 1e3));
  result = caml_unix_gettimeofday_unboxed(Val_unit) - result;
#else
  struct timespec t;
  double start_sleep;
  int ret = 0;
  t.tv_sec = (time_t)duration;
  t.tv_nsec = (duration - t.tv_sec) * 1e9;
  do {
    if (ret == -1) {
      /* Process signal from previous call */
      caml_leave_blocking_section();
      caml_enter_blocking_section();
    }
    start_sleep = caml_unix_gettimeofday_unboxed(Val_unit);
    ret = nanosleep(&t, &t);
    result += (caml_unix_gettimeofday_unboxed(Val_unit) - start_sleep);
  } while (ret == -1 && errno == EINTR);
  if (ret == -1)
    caml_failwith("nanosleep stub failed");
#endif
  caml_leave_blocking_section();

  return caml_copy_double(result);
}
