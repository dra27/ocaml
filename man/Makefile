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
SUBDIR_NAME = man
-include $(ROOTDIR)/Makefile.config
include $(ROOTDIR)/Makefile.common

MANPAGES = \
  ocaml ocamlc ocamlcp ocamldebug ocamldep ocamldoc ocamllex ocamlmktop \
  ocamlopt ocamlprof ocamlrun ocamlyacc

ocamlc.opt.link: ocamlc.m
ocamlopt.opt.link: ocamlopt.m
ocamloptp.link: ocamlcp.m

%.link: $(ROOTDIR)/Makefile.config
	echo '.so $(INSTALL_MANDIR_PROGRAMS)/'\
'$(basename $(filter %.m,$^)).$(PROGRAMS_MAN_SECTION)' > $@

define INSTALL_MAN
install::
	$(call INSTALL_ITEM, \
	  $(1).m, man, $(INSTALL_MANDIR_PROGRAMS), $(1).$(PROGRAMS_MAN_SECTION))
endef

$(foreach page, $(MANPAGES), \
  $(eval $(call INSTALL_MAN,$(page))))

.PHONY: install

install:: ocamlc.opt.link ocamlopt.opt.link ocamloptp.link
	$(call INSTALL_ITEM, ocamlc.opt.link, \
	  man, $(INSTALL_MANDIR_PROGRAMS), ocamlc.opt.$(PROGRAMS_MAN_SECTION))
	$(call INSTALL_ITEM, ocamlopt.opt.link, \
	  man, $(INSTALL_MANDIR_PROGRAMS), ocamlopt.opt.$(PROGRAMS_MAN_SECTION))
	$(call INSTALL_ITEM, ocamloptp.link, \
	  man, $(INSTALL_MANDIR_PROGRAMS), ocamloptp.$(PROGRAMS_MAN_SECTION))

.PHONY: clean
clean:
	rm -f *.link
