#!/usr/bin/env bash
#**************************************************************************
#*                                                                        *
#*                                 OCaml                                  *
#*                                                                        *
#*                        David Allsopp, Tarides                          *
#*                                                                        *
#*   Copyright 2023 David Allsopp Ltd.                                    *
#*                                                                        *
#*   All rights reserved.  This file is distributed under the terms of    *
#*   the GNU Lesser General Public License version 2.1, with the          *
#*   special exception on linking described in the file LICENSE.          *
#*                                                                        *
#**************************************************************************

# Synchronise the databases

#pacman -Sy

# Build a package database
declare -A PKGS
while read -r pkg ver ; do
  PKGS[$pkg]="$pkg=$ver"
done < <(pacman -Sl | cut -f2,3 -d ' ')

# Build a cache key of versions
declare -A KEY
for pkg in $({ pactree -lu base; echo mingw-w64-x86_64-gcc; } | sort); do
  # Remove any pins
  pkg="${pkg%=*}"
  KEY[$pkg]="${PKGS[$pkg]}"
done

cd "$GITHUB_WORKSPACE"

pwd

GIT='/c/Program Files/Git/cmd/git.exe'

if [[ -d msys2-installer ]]; then
  "$GIT" -C msys2-installer fetch upstream --tags
else
  "$GIT" clone -o upstream https://github.com/msys2/msys2-installer.git
fi

cd msys2-installer
current="$("$GIT" tag | grep -Ex '[0-9]{4}(-[0-9]{2}){2}' | sort -r | head -n 1)"
echo "Current version is $current"

echo Expected packages
for entry in $(echo "${KEY[@]}" | sort); do
  echo $entry
done

key="$(echo "${KEY[@]}" | sort | md5sum | cut -f1 -d' ')"

echo "Yielding $key"

echo "msys2=$key" >> "$GITHUB_ENV"
