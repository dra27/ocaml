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

set -e

function compute_package_key
{
  # Build a package database
  declare -gA PKGS
  while read -r pkg ver ; do
    PKGS[$pkg]="$pkg=$ver"
  done < <(pacman -Sl | cut -f2,3 -d ' ')

  # Build a cache key of versions
  declare -gA KEY
  for pkg in $({ pactree -lu base; echo mingw-w64-x86_64-gcc; } | sort); do
    # Remove any pins
    pkg="${pkg%=*}"
    KEY[$pkg]="${PKGS[$pkg]}"
  done

  echo Expected packages
  for entry in $(echo "${KEY[@]}" | sort); do
    echo $entry
  done

  key="$(echo "${KEY[@]}" | sort | md5sum | cut -f1 -d' ')"
}

compute_package_key
original_key="$key"

# If the tarball doesn't exist, this is a fresh installation and has already
# been updated
if [[ -e "$GITHUB_WORKSPACE/msys2/msys2.tar" ]]; then
  # Synchronise the databases
  pacman -Sy
  compute_package_key
fi
new_key="$key"

echo "msys2-cache=$new_key" >> "$GITHUB_OUTPUT"

if [[ $new_key != $original_key ]]; then
  echo -e '[\e[1;34mINFO\e[0m] Package updates required'
  exit 1
else
  echo -e '[\e[1;34mINFO\e[0m] No package updates'
fi
