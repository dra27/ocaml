#!/bin/sh

# Used for the beat.ml test - checks whether nanosleep is available to simplify
# the C stub in timed_delay.c

if grep -q "#define HAS_NANOSLEEP" ${ocamlsrcdir}/runtime/caml/s.h; then
  exit ${TEST_PASS};
fi
exit ${TEST_SKIP}
