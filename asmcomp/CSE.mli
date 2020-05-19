(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*             Xavier Leroy, projet Gallium, INRIA Rocquencourt           *)
(*                                                                        *)
(*   Copyright 2014 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

class cse :
  object
    method class_of_operation : Mach.operation -> CSEgen.op_class
    method fundecl : Mach.fundecl -> Mach.fundecl
    method is_cheap_operation : Mach.operation -> bool
  end

val fundecl : Mach.fundecl -> Mach.fundecl
