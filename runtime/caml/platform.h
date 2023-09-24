/**************************************************************************/
/*                                                                        */
/*                                 OCaml                                  */
/*                                                                        */
/*      KC Sivaramakrishnan, Indian Institute of Technology, Madras       */
/*                   Stephen Dolan, University of Cambridge               */
/*                                                                        */
/*   Copyright 2016 Indian Institute of Technology, Madras                */
/*   Copyright 2016 University of Cambridge                               */
/*                                                                        */
/*   All rights reserved.  This file is distributed under the terms of    */
/*   the GNU Lesser General Public License version 2.1, with the          */
/*   special exception on linking described in the file LICENSE.          */
/*                                                                        */
/**************************************************************************/

#ifndef CAML_PLAT_THREADS_H
#define CAML_PLAT_THREADS_H
/* Platform-specific concurrency and memory primitives */

#ifdef CAML_INTERNALS

#include "config.h"

/* Loads and stores with acquire, release and relaxed semantics */

#define atomic_load_acquire(p)                    \
  atomic_load_explicit((p), memory_order_acquire)
#define atomic_load_relaxed(p)                    \
  atomic_load_explicit((p), memory_order_relaxed)
#define atomic_store_release(p, v)                      \
  atomic_store_explicit((p), (v), memory_order_release)
#define atomic_store_relaxed(p, v)                      \
  atomic_store_explicit((p), (v), memory_order_relaxed)

#endif /* CAML_INTERNALS */

#endif /* CAML_PLATFORM_H */
