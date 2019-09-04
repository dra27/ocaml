#include <stdio.h>
#include <stdlib.h>
#include "caml/alloc.h"
#include "caml/memory.h"

value test(value unit)
{
  CAMLparam1(unit);
  printf("called test\n");
  fflush(stdout);
  CAMLreturn (Val_unit);
}

value Test(value unit)
{
  CAMLparam1(unit);
  printf("called Test\n");
  fflush(stdout);
  CAMLreturn (Val_unit);
}

value mov(value unit)
{
  CAMLparam1(unit);
  printf("called mov\n");
  fflush(stdout);
  CAMLreturn (Val_unit);
}
