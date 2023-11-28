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

# $1 = Linux, macOS or Windows (runner.os)
# $2 = space-separated list of required packages

function installed_packages
{
  case "$1" in
    Linux) dpkg-query -W -f '${Package} ${Version}\n';;
    macOS) brew list --versions;;
    Windows) pacman -Sl | cut -f2,3 -d ' ';;
  esac
}

case "$1" in
  Linux)
    sudo='sudo'
    package_manager='apt-get'
    sync_command='update'
    install_command='install -y';;
  macOS)
    sudo=''
    package_manager='brew'
    sync_command=''
    install_command='install';;
  Windows)
    sudo=''
    package_manager='pacman'
    sync_command='--noconfirm -Syu'
    install_command='--noconfirm -S';;
  *)
    echo $'[\e[1;31mERROR\e[0m] Runner "'"$1\" not recognised!" >&2
    exit 1;;
esac

NEEDED=($(echo $2 | tr ' ' '\n' | sort))
MISSING=()
INSTALLED=($(installed_packages "$1" | cut -f1 -d ' '))

for dep in "${NEEDED[@]}"; do
  for pkg in "${INSTALLED[@]}"; do
    if [[ $dep = $pkg ]]; then
      break;
    fi
  done
  if [[ $pkg != $dep ]]; then
    MISSING+=("$dep")
  fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo $'[\e[1;34mINFO\e[0m] Will install: '"${MISSING[@]}"
  echo "::group::Installing missing dependencies using $package_manager"
  if [[ -n $sync_command ]]; then
    $sudo $package_manager $sync_command
  fi
  $sudo $package_manager $install_command "${MISSING[@]}"
  echo '::endgroup::'
fi

echo $'[\e[1;34mINFO\e[0m] Package versions'
while read -r pkg ver; do
  if [[ $pkg = ${NEEDED[0]} ]]; then
    echo "$pkg: $ver"
    NEEDED=("${NEEDED[@]:1}")
  fi
done < <(installed_packages "$1")
