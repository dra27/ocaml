#**************************************************************************
#*                                                                        *
#*                                 OCaml                                  *
#*                                                                        *
#*            Xavier Leroy, projet Cristal, INRIA Rocquencourt            *
#*                                                                        *
#*   Copyright 1999 Institut National de Recherche en Informatique et     *
#*     en Automatique.                                                    *
#*                                                                        *
#*   All rights reserved.  This file is distributed under the terms of    *
#*   the GNU Lesser General Public License version 2.1, with the          *
#*   special exception on linking described in the file LICENSE.          *
#*                                                                        *
#**************************************************************************

ROOTDIR = ..
include $(ROOTDIR)/Makefile.common

DESTDIR ?=
INSTALL_DIR=$(DESTDIR)$(MANDIR)/man$(PROGRAMS_MAN_SECTION)

MAN_PAGES := $(wildcard *.m)

define install_manpage
install::
	$(INSTALL_DATA) $(1) $(INSTALL_DIR)/$(1:%.m=%).$(PROGRAMS_MAN_SECTION)
endef

define link_manpage
install::
	echo '.so man$(PROGRAMS_MAN_SECTION)/$(1).$(PROGRAMS_MAN_SECTION)' \
    > $(INSTALL_DIR)/$(1).opt.$(PROGRAMS_MAN_SECTION)
endef

install::
	$(MKDIR) "$(INSTALL_MANDIR)/man$(PROGRAMS_MAN_SECTION)"

$(foreach page, $(wildcard *.m), $(eval $(call install_manpage,$(page))))

$(foreach cmd, ocamlc ocamlopt ocamloptp, $(eval $(call link_manpage,$(cmd))))
