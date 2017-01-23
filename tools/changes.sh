#!/usr/bin/env bash

#**************************************************************************
#*                                                                        *
#*                                 OCaml                                  *
#*                                                                        *
#*           David Allsopp, OCaml Labs, University of Cambridge           *
#*                                                                        *
#*   Copyright 2017 MetaStack Solutions Ltd.                              *
#*                                                                        *
#*   All rights reserved.  This file is distributed under the terms of    *
#*   the GNU Lesser General Public License version 2.1, with the          *
#*   special exception on linking described in the file LICENSE.          *
#*                                                                        *
#**************************************************************************

usage () {
  echo "Incorrect or missing parameters" >&2
  echo >&2
  echo "$0 rename old-name new-name [new-title]" >&2
  echo "    - rename changes.d/old-name to changes.d/new-name and update .gitattributes" >&2
  echo "$0 reset name clone-name clone-title [title]" >&2
  echo "    - like rename, but recreate changes.d/old-name" >&2
  echo "$0 commit name [name2 ...]" >&2
  echo "    - move changes.d/name to changes.d/archive/name and update .gitattributes" >&2
  echo "      and Changes. Requires the changes.d/archive submodule to be initialised" >&2
  echo "      and set-up with push access" >&2
  exit 1
}

: ${CHANGES_ROOT:=changes.d}
: ${CHANGES_FILE:=Changes}
: ${CHANGES_ARCHIVE:=archive}
: ${CHANGES_ARCHIVE_UPSTREAM:=origin}
: ${CHANGES_ARCHIVE_BRANCH:=master}

ROOT=$CHANGES_ROOT
FILE=$CHANGES_FILE
ARCHIVE=$CHANGES_ARCHIVE
ARCHIVE_UPSTREAM=$CHANGES_ARCHIVE_UPSTREAM
ARCHIVE_BRANCH=$CHANGES_ARCHIVE_BRANCH

if [[ -n $COMSPEC ]] ; then
  CRLF='-e s/$/\r/'
  CR='\r'
  CONV_CRLF="sed $CRLF"
else
  CRLF=
  CR=
  CONF_CRLF=cat
fi

# not_valid old-name new-name [prefix]
not_valid () {
  if [[ ! -d $ROOT/$1 ]] ; then
    echo "$ROOT/$1 does not exist or is not a directory!" >&2
    return 0
  elif [[ $2 = */* ]] ; then
    echo "Target should be a basename: $2 contains /s" >&2
    return 0
  elif [[ -d $ROOT/$3$2 ]] ; then
    echo "$ROOT/$3$2 already exists!" >&2
    return 0
  else
    case $(grep "^$1 ocaml-changes-title=" $ROOT/.gitattributes | wc -l) in
      0)
        echo "$1 does not have ocaml-changes-title in $ROOT/.gitattributes" >&2
        return 0
        ;;
      1)
        # One entry can be updated
        ;;
      *)
        echo "$1 seems to have multiple ocaml-changes-title entries in $ROOT/.gitattributes!?" >&2
        return 0
    esac
  fi

  return 1
}

# rename old-name new-name [title] [no-attributes-update]
#   TARGET_TITLE is set to the title value on output
rename () {
  if not_valid $1 $2 ; then
    return 1
  fi
  if [[ $# -eq 3 ]] ; then
    TARGET_TITLE=${3// /+}
  else
    TARGET_TITLE=$(git check-attr ocaml-changes-title $ROOT/$1)
    TARGET_TITLE=${TARGET_TITLE//*: /}
  fi

  mv $ROOT/$1 $ROOT/$2
  if [[ $# -ne 4 ]] ; then
    sed -i -e "s/^$1 ocaml-changes-title=.*/$2 ocaml-changes-title=$TARGET_TITLE/" $CRLF $ROOT/.gitattributes
  fi

  return 0
}

# reset name clone-name clone-title [title]
#   TARGET_TITLE is set to the new title value of name on output
reset () {
  case $(grep '^$' $ROOT/.gitattributes | wc -l) in
    1)
      ;;
    *)
      echo "Expect one blank line in .gitattributes!" >&2
      return 1
  esac

  if rename $1 $2 "$3" no-update ; then
    if [[ $4 != "" ]] ; then
      # Update the ocaml-changes-title attribute of $1
      TARGET_TITLE=${4// /+}
      sed -i -e "s/^\($1 ocaml-changes-title=\).*/\1$TARGET_TITLE/" $CRLF $ROOT/.gitattributes
    fi
    # Add the ocaml-changes-title attribute for $2
    sed -i -e "/^$/i$2 ocaml-changes-title=${3// /+}$CR" $CRLF $ROOT/.gitattributes
    # Recreate the old directory
    mkdir $ROOT/$1
  else
    return 1
  fi

  return 0
}

# archive name
archive () {
  # Move the ocaml-changes-title attribute to the archive .gitattributes file
  grep "^$1 ocaml-changes-title=" $ROOT/.gitattributes | $CONV_CRLF >> $ROOT/$ARCHIVE/.gitattributes
  sed -i -e "/^$1 ocaml-changes-title=/d" $CRLF $ROOT/.gitattributes
  # Snapshot the ocaml-changes-title for the sections
  pushd $ROOT/$1 > /dev/null
  for section in * ; do
    TITLE=$(git check-attr ocaml-changes-title $section)
    TITLE=${TITLE//*: /}
    if ! grep -q "^$section ocaml-changes-title=" .gitattributes 2>/dev/null ; then
      echo "$section ocaml-changes-title=$TITLE" | $CONV_CRLF >> .gitattributes
    fi
  done
  popd > /dev/null
  mv $ROOT/$1 $ROOT/$ARCHIVE/

  return 0
}

if [[ ! -d $ROOT ]] ; then
  echo "Expect to be run in the root of a Git clone - can't find $ROOT?" >&2
  exit 1
fi

case $1 in
  rename)
    case $# in
      3|4)
        rename $2 $3 "$4"
        exit $?
        ;;
      *)
        usage
    esac
    ;;
  reset)
    case $# in
      4|5)
        reset $2 $3 "$4" "$5"
        ;;
      *)
        usage
    esac
    ;;
  commit)
    if [[ $# -lt 2 ]] ; then
      usage
    fi
    shift
    VALID=1
    for version in $@ ; do
      if not_valid $version $version $ARCHIVE/ ; then
        VALID=0
      fi
    done
    if [[ ! -e $ROOT/$ARCHIVE/.git ]] ; then
      echo "The $ROOT/$ARCHIVE submodule needs to be initialised" >&2
      exit 1
    fi
    COMMIT=$(git ls-tree HEAD $ROOT/$ARCHIVE | cut -f1 | cut -f3 -d' ')
    if [[ $(git status --porcelain $ROOT/$ARCHIVE) ]] ; then
      echo "The $ROOT/$ARCHIVE submodule needs updating" >&2
      echo "You probably want to run git submodule update $ROOT/$ARCHIVE" >&2
      VALID=0
    fi
    pushd $ROOT/$ARCHIVE > /dev/null
    MASTER_COMMIT=$(git rev-parse $ARCHIVE_BRANCH)
    if [[ $MASTER_COMMIT != $(git rev-parse $ARCHIVE_UPSTREAM/$ARCHIVE_BRANCH) ]] ; then
      if ! git merge-base --is-ancestor $ARCHIVE_UPSTREAM/$ARCHIVE_BRANCH $ARCHIVE_BRANCH ; then
        echo "$ROOT/$ARCHIVE: $ARCHIVE_UPSTREAM/$ARCHIVE_BRANCH and $ARCHIVE_BRANCH seem to have diverged." >&2
        echo "This needs to be fixed before new commits can be created" >&2
      else
        echo "$ROOT/$ARCHIVE: $ARCHIVE_BRANCH needs pushing to $ARCHIVE_UPSTREAM" >&2
      fi
      VALID=0
    fi
    if [[ $COMMIT != $MASTER_COMMIT ]] ; then
      echo "The submodule commit ${COMMIT:0:6} for $ROOT/$ARCHIVE does not match the $ARCHIVE_BRANCH" >&2
      echo "branch in the repository. This needs to be fixed before new commits can be created" >&2
      exit 1
    fi
    popd > /dev/null
    if ((VALID)) ; then
      for item in $@ ; do
        archive $item
      done
      make FullChanges
      pushd $ROOT/$ARCHIVE > /dev/null
      git add .gitattributes $@
      if git commit ; then
        if git push $ARCHIVE_UPSTREAM ; then
          popd > /dev/null
          (cd $ROOT && git add .gitattributes $@ $ARCHIVE)
          git add $FILE
          if ! git commit ; then
            echo "Final commit aborted, but $ROOT/$ARCHIVE is updated and pushed." >&2
            exit 1
          fi
        else
          echo "Failed to push $ROOT/$ARCHIVE to $ARCHIVE_UPSTREAM. You need to complete the check-in." >&2
          exit 1
        fi
      else
        echo "Git commit in $ROOT/$ARCHIVE failed/aborted. You need to complete the check-in." >&2
        exit 1
      fi
    fi
    ;;
  *)
    usage
esac
