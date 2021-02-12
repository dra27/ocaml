#!/usr/bin/env bash

set -e

cd "$GITHUB_WORKSPACE"
cd "../$BUILD_PREFIX-$PORT"
pwd

# COMBAK same thing with the parallleisation PR
MAKE=make
# XXX COMBAK not Cygwin! properly...
if [[ ! -e flexdll/Makefile && $PORT != 'cygwin64' ]]; then
  pushd /cygdrive/c/cache
  tar -xzf flexdll.tar.gz
  cd flexdll-$FLEXDLL_VERSION
  make MSVC_DETECT=0 CHAINS=${PORT%32} support
  mkdir /cygdrive/c/flexdll
  # XXX COMBAK
  cp flexdll.h *.manifest /cygdrive/c/flexdll/
  cp -f *.obj /cygdrive/c/flexdll 2>/dev/null || cp -f *.o /cygdrive/c/flexdll/
  cp /cygdrive/c/cache/flexlink.exe /cygdrive/c/flexdll/
  export PATH="/cygdrive/c/flexdll:$PATH"
  popd
fi

case "$PORT" in
  mingw32)
    HOST=i686-w64-mingw32;;
  mingw64)
    HOST=x86_64-w64-mingw32;;
  cygwin64)
    HOST=x86_64-pc-cygwin;;
  msvc32)
    HOST=i686-pc-windows;;
  msvc64)
    HOST=x86_64-pc-windows;;
esac
eval $(tools/msvs-promote-path)
./configure --build=x86_64-pc-cygwin --host=$HOST --disable-dependency-generation
test -e flexdll/Makefile && make -j flexdll
make -j world.opt
make -C testsuite all
