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

ROOTDIR = ../..
include $(ROOTDIR)/Makefile.common
include $(ROOTDIR)/Makefile.best_binaries

all: marshal_zstd.cma
allopt: marshal_zstd.cmxa marshal_zstd.cmxs
opt.opt: allopt

# XXX COMBAK --disable-shared version
marshal_zstd.cma: libzstd_static.$(A) dllcamlzstd$(EXT_DLL) \
                  stdlib_marshal_zstd_support.cmo
	$(V_LINKC)$(BEST_OCAMLC) $(STDLIBFLAGS) -o $@ -a -cclib -lzstd_static \
                           -dllib -lcamlzstd stdlib_marshal_zstd_support.cmo \
                           -linkall

# XXX hrmph - link order requiring the _shared version
marshal_zstd.cmxa: libzstd_shared.$(A) stdlib_marshal_zstd_support.cmx
	$(V_OCAMLOPT)$(BEST_OCAMLOPT) $(STDLIBFLAGS) -o $@ -a -cclib -lzstd_shared \
                                stdlib_marshal_zstd_support.cmx -linkall

# XXX Plumb this in properly (installation, etc.) - link with .o instead of .a?
marshal_zstd.cmxs: libzstd_shared.$(A) stdlib_marshal_zstd_support.cmx
	$(V_OCAMLOPT)$(BEST_OCAMLOPT) $(STDLIBFLAGS) -o $@ -shared \
                                -cclib -L. -cclib -lzstd_shared \
                                stdlib_marshal_zstd_support.cmx -linkall

libzstd_%.$(A): zstd_%.$(O)
	$(call MKLIB,$@,$^)

dllcamlzstd$(EXT_DLL): zstd_shared.$(O)
	$(V_MKDLL)$(MKDLL) -o $@ $^ $(ZSTD_LIBS)

%.$(O): %.c
	$(V_CC)$(CC) -c $(OC_CFLAGS) $(CFLAGS) $(OC_CPPFLAGS) $(CPPFLAGS) \
    $(SHAREDLIB_CFLAGS) $(OUTPUTOBJ)$@ $<

INSTALL_LIBDIR_LIBNAME = $(INSTALL_LIBDIR)/marshal_zstd

install::
	$(MKDIR) "$(INSTALL_LIBDIR_LIBNAME)"
	$(INSTALL_DATA) marshal_zstd.cma zstd_static.$(O) "$(INSTALL_LIBDIR_LIBNAME)"
	$(INSTALL_PROG) dllcamlzstd$(EXT_DLL) "$(INSTALL_STUBLIBDIR)"

installopt::
	$(INSTALL_DATA) marshal_zstd.cmxa marshal_zstd.$(A) "$(INSTALL_LIBDIR_LIBNAME)"

partialclean:
	rm -f *.cm*

clean:: partialclean
	rm -f *.dll *.so *.a *.lib *.o *.obj
	rm -rf $(DEPDIR)

%.cmi: %.mli
	$(V_OCAMLC)$(BEST_OCAMLC) $(STDLIBFLAGS) -c $(COMPFLAGS) $<

%.cmo: %.ml
	$(V_OCAMLC)$(BEST_OCAMLC) $(STDLIBFLAGS) -c $(COMPFLAGS) $<

%.cmx: %.ml
	$(V_OCAMLOPT)$(BEST_OCAMLOPT) $(STDLIBFLAGS) -c $(COMPFLAGS) $(OPTCOMPFLAGS) $<

.PHONY: distclean
distclean:: clean

.PHONY: depend
depend:
	$(OCAMLRUN) $(ROOTDIR)/boot/ocamlc -depend -slash *.mli *.ml > .depend

include .depend
