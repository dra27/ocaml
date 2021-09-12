/**************************************************************************/
/*                                                                        */
/*                                 OCaml                                  */
/*                                                                        */
/*                 David Allsopp, OCaml Labs, Cambridge.                  */
/*                                                                        */
/*   Copyright 2021 David Allsopp Ltd.                                    */
/*                                                                        */
/*   All rights reserved.  This file is distributed under the terms of    */
/*   the GNU Lesser General Public License version 2.1, with the          */
/*   special exception on linking described in the file LICENSE.          */
/*                                                                        */
/**************************************************************************/

#include "caml/misc.h"

/* Part of sys.c, but kept in its own compilation unit so that it doesn't get
   linked at all if symbol is overridden by a strong symbol in another unit. */
char_os * caml_standard_library_default = OCAML_STDLIB_DIR;
