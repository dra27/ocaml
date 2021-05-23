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

let opFIRST_UNIMPLEMENTED_OP = 0
#define OPCODE(name) \
let op ## name = opFIRST_UNIMPLEMENTED_OP \
let opFIRST_UNIMPLEMENTED_OP = opFIRST_UNIMPLEMENTED_OP + 1
#include "instruct.tbl"
#undef OPCODE
