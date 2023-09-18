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

#define CAML_INTERNALS

#include <caml/intext.h>

bool caml_zstd_available = true;

#define COMPRESS caml_zstd_compress
#define DECOMPRESS caml_zstd_decompress

#include "zstd.c"

bool (*caml_extern_compress_output)(struct caml_output_block **) =
  caml_zstd_compress;

size_t (*caml_intern_decompress_input)(unsigned char *,
                                       uintnat,
                                       const unsigned char *,
                                       uintnat) =
  caml_zstd_decompress;
