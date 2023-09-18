/**************************************************************************/
/*                                                                        */
/*                                 OCaml                                  */
/*                                                                        */
/*             Xavier Leroy, Collège de France and Inria                  */
/*                                                                        */
/*   Copyright 2023 Institut National de Recherche en Informatique et     */
/*     en Automatique.                                                    */
/*                                                                        */
/*   All rights reserved.  This file is distributed under the terms of    */
/*   the GNU Lesser General Public License version 2.1, with the          */
/*   special exception on linking described in the file LICENSE.          */
/*                                                                        */
/**************************************************************************/

/* Default implementations indicating that ZSTD support is not available for
   the Marshal module. */

#define CAML_INTERNALS

#include "caml/intext.h"

bool caml_zstd_available = false;

static bool default_extern_compress_output(
  struct caml_output_block **extern_output_first)
{
  return false;
}

static size_t default_intern_decompress_input(unsigned char * blk,
                                              uintnat uncompressed_data_len,
                                              const unsigned char * intern_src,
                                              uintnat data_len)
{
  return 0;
}

bool (*caml_extern_compress_output)(struct caml_output_block **) =
  default_extern_compress_output;

size_t (*caml_intern_decompress_input)(unsigned char *,
                                       uintnat,
                                       const unsigned char *,
                                       uintnat) =
  default_intern_decompress_input;
