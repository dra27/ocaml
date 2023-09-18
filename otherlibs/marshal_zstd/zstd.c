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

#define CAML_INTERNALS

#include "caml/intext.h"
#include "caml/memory.h"
#include "caml/mlvalues.h"

#include <zstd.h>

/* Compress the output */

bool COMPRESS(struct caml_output_block **extern_output_first)
{
  ZSTD_CCtx * ctx;
  ZSTD_inBuffer in;
  ZSTD_outBuffer out;
  struct caml_output_block * input, * output, * output_head;
  int rc;

  ctx = ZSTD_createCCtx();
  if (ctx == NULL) return false;
  input = *extern_output_first;
  output_head = caml_stat_alloc_noexc(sizeof(struct caml_output_block));
  if (output_head == NULL) goto oom1;
  output = output_head;
  output->next = NULL;
  in.src = input->data; in.size = input->end - input->data; in.pos = 0;
  out.dst = output->data; out.size = SIZE_EXTERN_OUTPUT_BLOCK; out.pos = 0;
  do {
    if (out.pos == out.size) {
      output->end = output->data + out.pos;
      /* Allocate fresh output block */
      struct caml_output_block * next =
        caml_stat_alloc_noexc(sizeof(struct caml_output_block));
      if (next == NULL) goto oom2;
      output->next = next;
      output = next;
      output->next = NULL;
      out.dst = output->data; out.size = SIZE_EXTERN_OUTPUT_BLOCK; out.pos = 0;
    }
    if (in.pos == in.size && input != NULL) {
      /* Move to next input block and free current input block */
      struct caml_output_block * next = input->next;
      caml_stat_free(input);
      input = next;
      if (input != NULL) {
        in.src = input->data; in.size = input->end - input->data;
      } else {
        in.src = NULL; in.size = 0;
      }
      in.pos = 0;
    }
    rc = ZSTD_compressStream2(ctx, &out, &in,
                              input == NULL ? ZSTD_e_end : ZSTD_e_continue);
  } while (! (input == NULL && rc == 0));
  output->end = output->data + out.pos;
  *extern_output_first = output_head;
  ZSTD_freeCCtx(ctx);
  return true;
oom2:
  /* The old output blocks that remain to be freed */
  *extern_output_first = input;
  /* Free the new output blocks */
  for (output = output_head; output != NULL; ) {
    struct caml_output_block * next = output->next;
    caml_stat_free(output);
    output = next;
  }
oom1:
  ZSTD_freeCCtx(ctx);
  return false;
}

size_t DECOMPRESS(unsigned char * blk,
                  uintnat uncompressed_data_len,
                  const unsigned char * intern_src,
                  uintnat data_len)
{
  return ZSTD_decompress(blk, uncompressed_data_len, intern_src, data_len);
}
