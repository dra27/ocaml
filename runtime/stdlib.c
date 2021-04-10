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
#include "build_config.h"

#if defined(OCAML_STDLIB_DIR_REL)
char_os * caml_standard_library_default = OCAML_STDLIB_DIR_REL;
#else
char_os * caml_standard_library_default = OCAML_STDLIB_DIR;
#endif
