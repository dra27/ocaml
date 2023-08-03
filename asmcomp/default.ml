(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*                         David Allsopp, Tarides                         *)
(*                                                                        *)
(*   Copyright 2023 David Allsopp Ltd.                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

module Backend = struct
  module Arch = Arch
  module CSE = CSE
  module Emit = Emit
  module Proc = Proc
  module Reload = Reload
  module Scheduling = Scheduling
  module Selection = Selection
  module Stackframe = Stackframe
end
