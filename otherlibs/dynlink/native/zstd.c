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

/* Linking shims for zstd with natdynlink */

#define CAML_INTERNALS

#include <caml/fail.h>
#include <caml/intext.h>
#include <caml/memory.h>

value caml_dynlink_compression_supported(value vunit)
{
  return Val_false;
}

value caml_dynlink_compressed_marshal_to_channel(value vchan, value v,
                                                 value flags)
{
  caml_invalid_argument("Compression.Marshal.to_channel: unsupported");
}

value caml_dynlink_compressed_marshal_from_channel(value vchan)
{
  CAMLparam1(vchan);
  struct channel * chan = Channel(vchan);
  caml_channel_lock(chan);
  value v = caml_input_val(chan);
  caml_channel_unlock(chan);
  CAMLreturn(v);
}
