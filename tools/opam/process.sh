#!/bin/sh
#**************************************************************************
#*                                                                        *
#*                                 OCaml                                  *
#*                                                                        *
#*            David Allsopp, University of Cambridge & Tarides            *
#*                                                                        *
#*   Copyright 2025 David Allsopp Ltd.                                    *
#*                                                                        *
#*   All rights reserved.  This file is distributed under the terms of    *
#*   the GNU Lesser General Public License version 2.1, with the          *
#*   special exception on linking described in the file LICENSE.          *
#*                                                                        *
#**************************************************************************

set -e

# XXX Should we trap (portably!) so that on any error with the caching we fall
#     back to building, possibly setting a warning?

if [ x"$2" = 'xinstall' ]; then
  if [ -e 'clone-from' ]; then
    cloned='true'
    clone_source="$(sed -e 's/\\/\\\\/g;s/%/%%/g;s/"/\\"/g' clone-from)"
    clone_mechanism='hard-linking'
    clone_from="$(cat clone-from)"
    source_prefix="$(opam var --switch="$clone_from" prefix | tr -d '\r')"
    case "$clone_from" in
      */*|*\\*) clone_source="local switch $clone_source";;
      *) clone_source="global switch $clone_source";;
    esac
    ( cd "$source_prefix" && sh ./share/ocaml/clone "$3" )
    # XXX This should probably be embedded automatically!
    mkdir -p "$3/share/ocaml"
    ln -f "$source_prefix/share/ocaml/clone" "$3/share/ocaml/clone"
  else
    cloned='false'
    clone_source=''
    clone_mechanism=''
    "$1" "$2"
    # XXX via .install?
    mkdir -p "$3/share/ocaml"
    ln -f "$OPAM_PACKAGE_NAME-clone.sh" "$3/share/ocaml/clone"
  fi
  cat > "$4.config" <<EOF
opam-version: "2.0"
variables {
  cloned: $cloned
  clone-source: "$clone_source"
  clone-mechanism: "$clone_mechanism"
}
EOF
  # XXX Intentionally copied, not linked?
  if [ -e 'build-id' ]; then
    cat build-id > "$3/lib/ocaml/build-id"
  fi
else
  make="$1"
  args="$2"
  relocatable="$3"
  build_id="$4"
  shift 4
  if [ x"$relocatable" = 'xenabled' ]; then
    rm -f opam-switches
    opam switch list --short | tr -d '\r' > opam-switches 2> /dev/null
    located=''
    while IFS= read -r switch; do
      if [ x"$switch" != x"$OPAMSWITCH" ]; then
        switch_lib_dir="$(opam var --switch="$switch" lib | tr -d '\r')"
        switch_build_id="$switch_lib_dir/ocaml/build-id"
        if [ -e "$switch_build_id" ]; then
          echo "build_id = $build_id"
          echo "switch_build_id = $switch_build_id"
          echo "content = $(cat "$switch_build_id")"
          if [ x"$build_id" = x"$(cat "$switch_build_id")" ]; then
            echo "Located $switch"
            located="$switch"
            break
          fi
        fi
      fi
    done < opam-switches
    rm -f opam-switches

    echo "located = $located"
    echo "$build_id" > build-id

    if [ -n "$located" ]; then
      # Cached copy found!
      clone="$(opam var --switch="$located" share | tr -d '\r')/ocaml/clone"
      echo "Checking $clone"
      if [ -e "$clone" ]; then
        echo "$located" > clone-from
        exit 0
      fi
    fi
  fi

  # No cached copy was found, or caching is disabled - build it
  ./configure "$@"
  "$make" $args
  "$make" INSTALL_MODE=clone install
fi
