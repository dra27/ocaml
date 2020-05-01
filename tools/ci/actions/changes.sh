#!/bin/sh -e
#**************************************************************************
#*                                                                        *
#*                                 OCaml                                  *
#*                                                                        *
#*                 David Allsopp, OCaml Labs, Cambridge.                  *
#*                                                                        *
#*   Copyright 2020 MetaStack Solutions Ltd.                              *
#*                                                                        *
#*   All rights reserved.  This file is distributed under the terms of    *
#*   the GNU Lesser General Public License version 2.1, with the          *
#*   special exception on linking described in the file LICENSE.          *
#*                                                                        *
#**************************************************************************

#------------------------------------------------------------------------
#This test checks that the Changes file has been modified by the pull
#request. Most contributions should come with a message in the Changes
#file, as described in our contributor documentation:
#
#  https://github.com/ocaml/ocaml/blob/trunk/CONTRIBUTING.md#changelog
#
#Some very minor changes (typo fixes for example) may not need
#a Changes entry. In this case, you may explicitly disable this test by
#adding the code word "No change entry needed" (on a single line) to
#a commit message of the PR, or using the "no-change-entry-needed" label
#on the github pull request.
#------------------------------------------------------------------------

TRAVIS_CUR_HEAD="$1"
TRAVIS_PR_HEAD="$2"
TRAVIS_MERGE_BASE=$(git merge-base "$TRAVIS_CUR_HEAD" "$TRAVIS_PR_HEAD")

CheckNoChangesMessage () {
  if [[ -n $(git log --grep='[Nn]o [Cc]hange.* needed' --max-count=1 \
    "$TRAVIS_MERGE_BASE..$TRAVIS_PR_HEAD") ]]
  then echo pass
  else exit 1
  fi
}

# check that Changes has been modified
git diff "$TRAVIS_MERGE_BASE..$TRAVIS_PR_HEAD" --name-only --exit-code \
  Changes > /dev/null && CheckNoChangesMessage || echo pass
