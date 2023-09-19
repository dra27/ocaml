#**************************************************************************
#*                                                                        *
#*                                 OCaml                                  *
#*                                                                        *
#*                        David Allsopp, Tarides                          *
#*                                                                        *
#*   Copyright 2023 David Allsopp Ltd.                                    *
#*                                                                        *
#*   All rights reserved.  This file is distributed under the terms of    *
#*   the GNU Lesser General Public License version 2.1, with the          *
#*   special exception on linking described in the file LICENSE.          *
#*                                                                        *
#**************************************************************************

# Makefile for the Marshal library's zstd support

LIBNAME = marshal_zstd
CLIBNAME = camlzstd
CAMLOBJS = stdlib_marshal_zstd_support.cmo
C_SOURCES = zstdstubs.c
LINKOPTS = $(addprefix -cclib , $(ZSTD_LIBS))
LDOPTS = $(addprefix -ldopt , $(ZSTD_LIBS))

include ../Makefile.otherlibs.common

zstdstubs.b.$(O): zstd.c
zstdstubs.n.$(O): zstd.c
zstdstubs.c: zstd.c

zstd.c: $(ROOTDIR)/runtime/zstd.c
	$(V_GEN)cp $^ $@

clean::
	rm -f zstd.c

.PHONY:
depend: zstd.c
	$(OCAMLRUN) $(ROOTDIR)/boot/ocamlc -depend -slash *.mli *.ml > .depend

include .depend
