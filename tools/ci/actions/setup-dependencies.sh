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

case "$1" in
  Linux)
    installed_packages_command="dpkg-query -W -f '\${Package}\\t\${Version}\\n'"
    sudo='sudo'
    sync_command='apt-get update'
    install_packages_command='sudo apt-get install -y';;
  macOS)
    installed_packages_command='brew list --versions'
    sudo=''
    sync_command=''
    install_packages_command='brew install';;
  Windows)
    installed_packages_command="pacman -Sl | cut -f2,3 -d ' '"
    sudo=''
    sync_command='pacman --noconfirm -Syu'
    check_pacman $packages;;
  *)
    echo -e "[\e[1;31mERROR\e[0m] Runner \"$1\" not recognised!" >&2
    exit 1;;
esac

declare -A INSTALLED
while read -r pkg ver; do
  INSTALLED[$pkg]="$ver"
done < <($installed_packages_command)

NEEDED=($(echo $2 | tr ' ' '\n' | sort))
MISSING=()
for pkg in "${NEEDED[@]}"; do
  if [[ ! -v "INSTALLED[$pkg]" ]]; then
    MISSING+="$pkg"
  fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo -e "[\e[1;34mINFO\e[0m] Will install: ${MISSING[@]}"
  echo "::group::Installing missing dependencies using ${install_packages_command%% *}"
  if [[ -n $sync_command ]]; then
    $sudo $sync_command
  fi
  $sudo $install_packages_command "${MISSING[@]}"
  echo '::endgroup::'
  # Update the installed versions
  while read -r pkg ver; do
    INSTALLED[$pkg]="$ver"
  done < <($installed_packages_command)
fi

echo -e "[\e[1;34mINFO\e[0m] Package versions"
for pkg in "${NEEDED[@]}"; do
  echo "$pkg: ${INSTALLED[$pkg]}"
done
