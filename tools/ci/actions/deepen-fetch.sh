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

# GitHub Actions doesn't support the ternary operator, so the dance is done here
if [[ $1 = 'pull_request' ]]; then
  shift 1
else
  shift 5
fi

FETCH_HEAD=$(git rev-parse FETCH_HEAD)
UPSTREAM_BRANCH="$1"
UPSTREAM_HEAD="$2"
PR_BRANCH="$3"
PR_HEAD="$4"

# Ensure that enough has been fetched to have all the commits between the
# the two branches.

NEW=0
# Special case: new tags and new branches will have UPSTREAM_HEAD=0\{40}
if [[ -z ${UPSTREAM_HEAD//0/} ]]; then
  echo "$UPSTREAM_BRANCH is new: only testing HEAD"
  UPSTREAM_HEAD="$PR_HEAD~1"
  NEW=1
elif ! git log -1 "$UPSTREAM_HEAD" &> /dev/null ; then
  echo "$UPSTREAM_BRANCH has been force-pushed"
  git fetch origin "$UPSTREAM_HEAD" &> /dev/null
fi

# If we've been sourced, return if the fetch has already been done
if ! git merge-base "$UPSTREAM_HEAD" "$PR_HEAD" &> /dev/null; then
  echo "Determining merge-base of $UPSTREAM_HEAD..$PR_HEAD for $PR_BRANCH"

  DEEPEN=50
  MSG='Deepening'

  while ! git merge-base "$UPSTREAM_HEAD" "$PR_HEAD" &> /dev/null
  do
    echo " - $MSG by $DEEPEN commits"
    git fetch origin --deepen=$DEEPEN "$PR_BRANCH" &> /dev/null
    MSG='Further deepening'
    ((DEEPEN*=2))
  done
fi

MERGE_BASE=$(git merge-base "$UPSTREAM_HEAD" "$PR_HEAD")

if [[ $UPSTREAM_BRANCH != $PR_BRANCH ]]; then
  echo "$PR_BRANCH branched from $UPSTREAM_BRANCH at: $MERGE_BASE"
elif ((!NEW)); then
  echo "$UPSTREAM_BRANCH branched at: $MERGE_BASE"
fi
