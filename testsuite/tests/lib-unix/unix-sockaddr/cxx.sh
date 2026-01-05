#!/bin/sh

set -eu

case "$ccomp_type" in
  cc) outputobj='-o ' ;;
  msvc) outputobj='-Fo' ;;
  *) exit "$TEST_SKIP" ;;
esac

if ${cxx} ${cppflags} ${cflags} \
          -I "${ocamlsrcdir}/runtime" \
          -I "${ocamlsrcdir}/otherlibs/unix" \
          ${outputobj}"${test_build_directory}/sockaddr_cxx_aux.${objext}" \
          -c "${test_source_directory}/sockaddr_cxx_aux.cpp"; then
  exit "$TEST_PASS"
else
  exit "$TEST_FAIL"
fi
