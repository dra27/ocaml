/***********************************************************************/
/*                                                                     */
/*                                OCaml                                */
/*                                                                     */
/*  Contributed by Sylvain Le Gall for Lexifi                          */
/*                                                                     */
/*  Copyright 2008 Institut National de Recherche en Informatique et   */
/*  en Automatique.  All rights reserved.  This file is distributed    */
/*  under the terms of the GNU Library General Public License, with    */
/*  the special exception on linking described in file ../../LICENSE.  */
/*                                                                     */
/***********************************************************************/

#ifndef _WINLIST_H
#define _WINLIST_H

/* Basic list function in C. */

/* Singly-linked list data structure.
 * To transform a C struct into a list structure, you must include
 * at first position of your C struct a "LIST lst" and call
 * caml_winlist_init on this data structure.
 *
 * See winworker.c for example.
 */
typedef struct _LIST LIST;
typedef LIST *LPLIST;

struct _LIST {
  LPLIST lpNext;
};

/* Initialize list data structure */
void caml_winlist_init (LPLIST lst);

/* Cleanup list data structure */
void caml_winlist_cleanup (LPLIST lst);

/* Set next element */
void caml_winlist_next_set (LPLIST lst, LPLIST next);

/* Return next element */
LPLIST caml_winlist_next (LPLIST);

#define LIST_NEXT(T, e) ((T)(caml_winlist_next((LPLIST)(e))))

/* Get number of element */
int caml_winlist_length (LPLIST);

/* Concat two list. */
LPLIST caml_winlist_concat (LPLIST, LPLIST);

#endif /* _WINLIST_H */
