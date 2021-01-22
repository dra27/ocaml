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

# Makefile for the parser generator.

ROOTDIR = ..

include $(ROOTDIR)/Makefile.config
include $(ROOTDIR)/Makefile.common

# XXX COMBAK When we're cross-compiling, will need a build ocamlyacc for the build system and a host
#     ocamlyacc to install. The easiest thing will be to ensure that boot/ocamlyacc is a runnable thing.
host_OC_CPPFLAGS += -I$(ROOTDIR)/runtime -I$(ROOTDIR)/runtime/host

ifeq "$(host_UNIX_OR_WIN32)" "win32"
WSTR_OBJ = wstr
else
WSTR_OBJ =
endif

ocamlyacc_SOURCES := $(addsuffix .c,\
  $(WSTR_OBJ) closure error lalr lr0 main mkpar output reader skeleton \
  symtab verbose warshall)

ocamlyacc_OBJECTS := $(ocamlyacc_SOURCES:.c=.$(host_O))

generated_files := ocamlyacc$(host_EXE) $(ocamlyacc_OBJECTS)  version.h

all: ocamlyacc$(host_EXE)

# XXX Don't care about EXTRALIBS
ocamlyacc$(host_EXE): $(ocamlyacc_OBJECTS)
	$(host_MKEXE) -o $@ $^ $(EXTRALIBS)

version.h : $(ROOTDIR)/VERSION
	echo "#define OCAML_VERSION \"`sed -e 1q $< | tr -d '\r'`\"" > $@

clean:
	rm -f $(generated_files)

depend:

closure.$(O): defs.h
error.$(O): defs.h
lalr.$(O): defs.h
lr0.$(O): defs.h
main.$(O): defs.h version.h
mkpar.$(O): defs.h
output.$(O): defs.h
reader.$(O): defs.h
skeleton.$(O): defs.h
symtab.$(O): defs.h
verbose.$(O): defs.h
warshall.$(O): defs.h

%.$(O): %.c
	$(host_CC) -c $(host_OC_CFLAGS) $(host_OC_CPPFLAGS) $(host_OUTPUTOBJ)$@ $<
