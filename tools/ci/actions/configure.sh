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

#------------------------------------------------------------------------
#This test checks that if configure.ac has been modified by the pull
#request, then configure has been correctly regenerated.
#------------------------------------------------------------------------

set -e

if [[ $1 = 'pull_request' ]]; then
  CHECK_ALL_COMMITS=1
else
  CHECK_ALL_COMMITS=0
fi

. tools/ci/actions/deepen-fetch.sh

if ((CHECK_ALL_COMMITS)); then
  COLOR='31'
else
  COLOR='33'
fi

CheckTypoTree () {
  git diff-tree --diff-filter=d --no-commit-id --name-only -r "$2" \
    | (while IFS= read -r path
  do
    case "$path" in
      configure|configure.ac|VERSION|tools/ci/travis/travis-ci.sh)
        touch CHECK_CONFIGURE;;
    esac
  done)
  if [[ -e CHECK_CONFIGURE ]] ; then
    rm -f CHECK_CONFIGURE
    git checkout -qB return
    git checkout -q "$1"
    mv configure configure.ref
    make -s configure
    if diff -q configure configure.ref >/dev/null ; then
      echo -e "$1: \e[32mconfigure.ac generates configure\e[0m"
      if ((!CHECK_ALL_COMMITS)); then
        rm -f failed
      fi
    else
      echo -e "$1: \e[${COLOR}mconfigure.ac doesn't generate configure\e[0m"
      touch failed
    fi
    mv configure.ref configure
    git checkout -q return
  fi
}

rm -f failed

for commit in $(git rev-list "$MERGE_BASE..$PR_HEAD" --reverse)
do
  CheckTypoTree "$commit" "$commit"
done

if [[ -e failed ]]; then
  echo 'configure.ac no longer generates configure'
  if ((CHECK_ALL_COMMITS)); then
    echo 'Please rebase the PR, editing the commits identified above and run:'
  else
    echo 'Please fix the branch by committing changes after running:'
  fi
  echo 'make -B configure'
  exit 1
fi
