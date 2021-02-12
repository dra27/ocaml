#!/usr/bin/env bash
#**************************************************************************
#*                                                                        *
#*                                 OCaml                                  *
#*                                                                        *
#*                 David Allsopp, OCaml Labs, Cambridge.                  *
#*                                                                        *
#*   Copyright 2021 David Allsopp Ltd.                                    *
#*                                                                        *
#*   All rights reserved.  This file is distributed under the terms of    *
#*   the GNU Lesser General Public License version 2.1, with the          *
#*   special exception on linking described in the file LICENSE.          *
#*                                                                        *
#**************************************************************************

set -e

GITHUB_WORKSPACE=$(cygpath -a "$GITHUB_WORKSPACE")

cd "$GITHUB_WORKSPACE"

MAKE='make -j2'
BUILD_DIR=$(cygpath -a "../$BUILD_PREFIX")
CACHE_DIR=$(cygpath -a "$CACHE_ROOT")
BASE_CACHE_DIR="$CACHE_DIR/base"
BUILD_CACHE_DIR="$CACHE_DIR/build"
INSTALL_DIR=$(cygpath -a "$PROGRAMFILES\\$INSTALL_DIR")

function Configure {
  port="$1"

  o='o'
  case "$port" in
    cygwin32) host='';;
    cygwin64) host='';;
    mingw32) host='i686-w64-mingw32';;
    mingw64) host='x86_64-w64-mingw32';;
    msvc32) host='i686-pc-windows'; o='obj';;
    msvc64) host='x86_64-pc-windows'; o='obj';;
    *)
      echo "Unknown port: $port"
      exit 1
  esac

  if [[ -z $host ]]; then
    build=''
  else
    build="--build=$(uname -m)-pc-cygwin"
    host="--host=$host"
  fi

  if [[ -z $2 ]]; then
    dep='disable'
  else
    dep='enable'
  fi

  if [[ -e "$GITHUB_WORKSPACE/flexdll/Makefile" ]]; then
    cd "$BUILD_DIR"
    git submodule update --init
  else
    cd /tmp
    tar -xzf "$BASE_CACHE_DIR/flexdll.tar.gz"
    cd "flexdll-$FLEXDLL_VERSION"
    $MAKE -j MSVC_DETECT=0 CHAINS=${port%32} support
    cp flexdll.h default*.manifest *.$o /usr/bin/
    cp "$BASE_CACHE_DIR/flexlink.exe" /usr/bin/
  fi

  cd /tmp
  tar -xjf "$BASE_CACHE_DIR/parallel.tar.bz2"
  cd parallel-*
  mv src/parallel /usr/bin/parallel

  case "$port" in
    msvc*)
      echo "eval \$($GITHUB_WORKSPACE/tools/msvs-promote-path)" \
        >> ~/.bash_profile;;
    mingw32)
      echo "export PATH=\"\$PATH:/usr/i686-w64-mingw32/sys-root/mingw/bin\"" \
        >> ~/.bash_profile;;
    mingw64)
      echo "export PATH=\"\$PATH:/usr/x86_64-w64-mingw32/sys-root/mingw/bin\"" \
        >> ~/.bash_profile;;
  esac

  cd "$BUILD_DIR"

  do_configure || { \
    rm -f "$BUILD_CACHE_DIR/config.cache"; \
    do_configure; }
}

function do_configure {
  ./configure --cache-file="$BUILD_CACHE_DIR/config.cache" \
              $build $host \
              --$dep-dependency-generation \
              --enable-ocamltest \
              --prefix="$INSTALL_DIR"
}

function Build {
  cd "$BUILD_DIR"

  if [[ -e flexdll/Makefile ]]; then
    $MAKE flexdll
  fi
  # XXX build modes; including pre-depend
  $MAKE world.opt
}

function Test {
  cd "$BUILD_DIR"

  # XXX TODO
  make -C testsuite parallel
}

function Install {
  cd "$BUILD_DIR"

  # XXX TODO
  make install
}

function Hygiene {
  cd "$BUILD_DIR"

  # XXX TODO
}

verb="$1"
shift 1

case "$verb" in
  configure)
    Configure "$@";;
  build)
    Build "$@";;
  test)
    Test "$@";;
  install)
    Install "$@";;
  hygiene)
    Hygiene "$@";;
  *)
    exit "Unknown command: $1"
    exit 1
esac
