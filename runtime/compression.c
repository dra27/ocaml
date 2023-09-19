/**************************************************************************/
/*                                                                        */
/*                                 OCaml                                  */
/*                                                                        */
/*                        David Allsopp, Tarides                          */
/*                                                                        */
/*   Copyright 2023 David Allsopp Ltd.                                    */
/*                                                                        */
/*   All rights reserved.  This file is distributed under the terms of    */
/*   the GNU Lesser General Public License version 2.1, with the          */
/*   special exception on linking described in the file LICENSE.          */
/*                                                                        */
/**************************************************************************/

/* Hooks for intern and extern for compression */

#define CAML_INTERNALS

#include "caml/intext.h"

bool caml_zstd_available = false;

static size_t default_intern_decompress_input(unsigned char * blk,
                                              uintnat uncompressed_data_len,
                                              const unsigned char * intern_src,
                                              uintnat data_len)
{
  return 0;
}

size_t (*caml_intern_decompress_input)(unsigned char *,
                                       uintnat,
                                       const unsigned char *,
                                       uintnat) =
  default_intern_decompress_input;

static bool default_extern_compress_output(
  struct caml_output_block **extern_output_first)
{
  return false;
}

bool (*caml_extern_compress_output)(struct caml_output_block **) =
  default_extern_compress_output;
