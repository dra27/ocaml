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
allopt: marshal_zstd.cmxa
opt.opt: allopt

# XXX COMBAK --disable-shared version
marshal_zstd.cma: zstd_static.$(O) dllcamlzstd$(EXT_DLL) \
                  stdlib_marshal_zstd_support.cmo
	$(V_LINKC)$(BEST_OCAMLC) $(STDLIBFLAGS) -o $@ -a -cclib zstd_static.$(O) \
                           -dllib -lcamlzstd stdlib_marshal_zstd_support.cmo \
                           -linkall

# XXX COMBAK marshal_zstd.cmxs
marshal_zstd.cmxa: zstd_static.$(O) stdlib_marshal_zstd_support.cmx
	$(V_OCAMLOPT)$(BEST_OCAMLOPT) $(STDLIBFLAGS) -o $@ -a -cclib zstd_static.$(O) \
                                stdlib_marshal_zstd_support.cmx -linkall

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
