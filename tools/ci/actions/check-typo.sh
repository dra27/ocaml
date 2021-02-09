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

# Set to 1 to require all commits individually to pass check-typo
CHECK_ALL_COMMITS=0

. tools/ci/actions/deepen-fetch.sh

# Test to see if any part of the directory name has been marked prune
not_pruned () {
  DIR=$(dirname "$1")
  if [[ $DIR = '.' ]] ; then
    return 0
  else
    case ",$(git check-attr typo.prune "$DIR" | sed -e 's/.*: //')," in
      ,set,)
      return 1
      ;;
      *)

      not_pruned "$DIR"
      return $?
    esac
  fi
}

CheckTypoTree () {
  export OCAML_CT_HEAD=$1
  export OCAML_CT_LS_FILES="git diff-tree --no-commit-id --name-only -r $2 --"
  export OCAML_CT_CAT='git cat-file --textconv'
  export OCAML_CT_PREFIX="$1:"
  GIT_INDEX_FILE=tmp-index git read-tree --reset -i "$1"
  git diff-tree --diff-filter=d --no-commit-id --name-only -r "$2" \
    | (while IFS= read -r path
  do
    if not_pruned "$path" ; then
      echo "Checking $1: $path"
      if ! tools/check-typo "./$path" ; then
        touch failed
      fi
    else
      echo "NOT checking $1: $path (typo.prune)"
    fi
  done)
  rm -f tmp-index
}

export OCAML_CT_GIT_INDEX='tmp-index'
export OCAML_CT_CA_FLAG='--cached'
rm -f failed

COMMIT_RANGE="$MERGE_BASE..$PR_HEAD"
if ((CHECK_ALL_COMMITS)); then
  for commit in $(git rev-list "$COMMIT_RANGE" --reverse); do
    CheckTypoTree "$commit" "$commit"
  done
else
  CheckTypoTree "$FETCH_HEAD" "$COMMIT_RANGE"
fi

if [[ -e failed ]]; then
  exit 1
fi
