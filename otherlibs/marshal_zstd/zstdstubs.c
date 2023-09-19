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

#include "caml/intext.h"
#include "caml/memory.h"
#include "caml/mlvalues.h"

#include <zstd.h>

#define caml_zstd_compress caml_dynamic_zstd_compress
#define caml_zstd_decompress caml_dynamic_zstd_decompress
#define CAML_BUILDING_STUBS

#include "zstd.c"

CAMLprim value caml_plumb_marshal_zstd (value unit)
{
  caml_zstd_available = true;
  caml_extern_compress_output = caml_dynamic_zstd_compress;
  caml_intern_decompress_input = caml_dynamic_zstd_decompress;
  return Val_unit;
}
