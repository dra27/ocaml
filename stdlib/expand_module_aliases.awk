#**************************************************************************
#*                                                                        *
#*                                 OCaml                                  *
#*                                                                        *
#*                 Jeremie Dimino, Jane Street Europe                     *
#*                                                                        *
#*   Copyright 2017 Jane Street Group LLC                                 *
#*                                                                        *
#*   All rights reserved.  This file is distributed under the terms of    *
#*   the GNU Lesser General Public License version 2.1, with the          *
#*   special exception on linking described in the file LICENSE.          *
#*                                                                        *
#**************************************************************************

# This script used to add the Stdlib__ prefixes to the module aliases in
# stdlib.ml and stdlib.mli. It temporarily remains because it got co-opted to
# perform a transformation on labelled module documentation comments. When that
# function is removed, the filtering out of @canonical can be trivially done
# with `-pp 'grep -F -v @canonical'`
NR == 1 { printf ("# 1 \"%s\"\n", FILENAME) }
/@canonical/ {if (ocamldoc=="true") next}
{ if (FILENAME ~ /Labels/ &&
      sub(/@since [^(]* \(/, "@since "))
    sub(/ in [^)]*\)/, "");
  print
}
