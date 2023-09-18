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

#define COMPRESS caml_zstd_shared_compress
#define DECOMPRESS caml_zstd_shared_decompress

#include "zstd.c"

CAMLprim value caml_plumb_marshal_zstd (value unit)
{
  caml_zstd_available = true;
  caml_extern_compress_output = caml_zstd_shared_compress;
  caml_intern_decompress_input = caml_zstd_shared_decompress;
  return Val_unit;
}
