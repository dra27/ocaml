#!/usr/bin/env bash
#**************************************************************************
#*                                                                        *
#*                                 OCaml                                  *
#*                                                                        *
#*              Anil Madhavapeddy, OCaml Labs                             *
#*                                                                        *
#*   Copyright 2014 Institut National de Recherche en Informatique et     *
#*     en Automatique.                                                    *
#*                                                                        *
#*   All rights reserved.  This file is distributed under the terms of    *
#*   the GNU Lesser General Public License version 2.1, with the          *
#*   special exception on linking described in the file LICENSE.          *
#*                                                                        *
#**************************************************************************

set -xe

PREFIX=~/local

MAKE="make $MAKE_ARG"
SHELL=dash

MAKE_WARN="$MAKE --warn-undefined-variables"

export PATH=$PREFIX/bin:$PATH

Configure () {
  mkdir -p $PREFIX
  cat<<EOF
------------------------------------------------------------------------
This test builds the OCaml compiler distribution with your pull request
and runs its testsuite.
Failing to build the compiler distribution, or testsuite failures are
critical errors that must be understood and fixed before your pull
request can be merged.
------------------------------------------------------------------------
EOF

  ./configure -C --prefix="$PREFIX" \
              --enable-flambda-invariants \
              --enable-ocamltest \
              --disable-dependency-generation "$@"
}

Build () {
  if [ "$(uname)" = 'Darwin' ]; then
    script -q build.log $MAKE_WARN
  else
    script --return --command "$MAKE_WARN" build.log
  fi
  failed=0
  if grep -Fq ' warning: undefined variable ' build.log; then
    echo Undefined Makefile variables detected
    failed=1
  fi
  rm build.log
  echo Ensuring that all names are prefixed in the runtime
  if ! ./tools/check-symbol-names runtime/*.a otherlibs/*/lib*.a ; then
    failed=1
  fi
  if ((failed)); then
    exit 1
  fi
}

Test () {
  echo Running the testsuite
  if [ $# -gt 0 ]; then
    list="$(mktemp)"
    echo "$*" | tr ' ' '\n' | sed -e 's|^|tests/|' > $list
    $MAKE -C testsuite one LIST="$list"
  else
    $MAKE -C testsuite parallel
  fi
  cd ..
}

API_Docs () {
  echo Ensuring that all library documentation compiles
  $MAKE -C api_docgen html pdf texi
}

Install () {
  $MAKE install
}

Checks () {
  if fgrep 'SUPPORTS_SHARED_LIBRARIES=true' Makefile.config &>/dev/null ; then
    echo Check the code examples in the manual
    $MAKE manual-pregen
  fi
  # check_all_arches checks tries to compile all backends in place,
  # we would need to redo (small parts of) world.opt afterwards to
  # use the compiler again
  $MAKE check_all_arches
  # Ensure that .gitignore is up-to-date - this will fail if any untreacked or
  # altered files exist.
  test -z "$(git status --porcelain)"
  # check that the 'clean' target also works
  $MAKE clean
  $MAKE -C manual clean
  $MAKE -C manual distclean
  # check that the `distclean` target definitely cleans the tree
  $MAKE distclean
  # config.cache should never be removed the build system
  rm -f config.cache
  # Check the working tree is clean
  test -z "$(git status --porcelain)"
  # Check that there are no ignored files
  test -z "$(git ls-files --others -i --exclude-standard)"
}

BuildManual () {
  $MAKE -C manual/src/html_processing duniverse
  $MAKE -C manual manual
  $MAKE -C manual web
}

# ReportBuildStatus accepts an exit code as a parameter (defaults to 1) and also
# instructs GitHub Actions to set build-status to 'failed' on non-zero exit or
# 'success' otherwise.
ReportBuildStatus () {
  CODE=${1:-1}
  if ((CODE)); then
    STATUS='failed'
  else
    STATUS='success'
  fi
  echo "build-status=$STATUS" >>"$GITHUB_OUTPUT"
  exit $CODE
}

BasicCompiler () {
  trap ReportBuildStatus ERR

  ./configure -C --disable-dependency-generation \
                 --disable-debug-runtime \
                 --disable-instrumented-runtime

  # Need a runtime
  make -j coldstart
  # And generated files (ocamllex compiles ocamlyacc)
  make -j ocamllex

  ReportBuildStatus 0
}

case $1 in
configure) Configure "${@:2}";;
build) Build;;
test) Test "${@:2}";;
api-docs) API_Docs;;
install) Install;;
manual) BuildManual;;
other-checks) Checks;;
basic-compiler) BasicCompiler;;
*) echo "Unknown CI instruction: $1"
   exit 1;;
esac
