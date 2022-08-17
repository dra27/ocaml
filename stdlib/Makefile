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

# There are three ways the Standard Library is compiled in bytecode:
# 1. During coldstart
#      - using ../boot/ocamlc which runs on ../boot/ocamlrun
# 2. During coreall (via library),
#      - using ../ocamlc which runs on ../boot/ocamlrun
# 3. During coreboot (via library-cross),
#      - using ../ocamlc which at that point runs on ../runtime/ocamlrun
# If $(USE_BOOT_OCAMLC) is non-empty, we select case 1 and use $(BOOT_OCAMLC).
# Otherwise, we use $(OCAMLRUN) ../ocamlc, with $(OCAMLRUN) being
# ../boot/ocamlrun by default, but able to overridden by library-cross to
# ../runtime/ocamlrun.
USE_BOOT_OCAMLC ?=

ifeq "$(USE_BOOT_OCAMLC)" ""
CAMLC = $(OCAMLRUN) $(ROOTDIR)/ocamlc$(EXE)
else
CAMLC = $(BOOT_OCAMLC)
endif
COMPFLAGS=-strict-sequence -absname -w +a-4-9-41-42-44-45-48-70 \
          -g -warn-error +A -bin-annot -nostdlib -principal \
          -safe-string -strict-formats
ifeq "$(FLAMBDA)" "true"
OPTCOMPFLAGS += -O3
endif
OPTCOMPILER=$(ROOTDIR)/ocamlopt
CAMLOPT=$(OCAMLRUN) $(OPTCOMPILER)
CAMLDEP=$(BOOT_OCAMLC) -depend
DEPFLAGS=-slash

OC_CPPFLAGS += -I$(ROOTDIR)/runtime

include StdlibModules

OBJS=$(addsuffix .cmo,$(STDLIB_MODULES))
NOSTDLIB= camlinternalFormatBasics.cmo camlinternalAtomic.cmo stdlib.cmo
OTHERS=$(filter-out $(NOSTDLIB),$(OBJS))

.PHONY: all
all: stdlib.cma std_exit.cmo bootheader $(HEADER_NAME) target_$(HEADER_NAME) \
     camlheader_ur

ifeq "$(RUNTIMED)" "true"
all: target_camlheaderd
endif

ifeq "$(INSTRUMENTED_RUNTIME)" "true"
all: target_camlheaderi
endif

.PHONY: allopt opt.opt # allopt and opt.opt are synonyms
allopt: stdlib.cmxa std_exit.cmx
opt.opt: allopt

.PHONY: install
# Ensure any pre-4.13 lowercased artefacts are removed on macOS and Windows
install::
	stale="$(filter-out $(notdir $(wildcard stdlib__*.cmi)), \
         $(notdir $(wildcard $(INSTALL_LIBDIR)/stdlib__*.cmi)))"; \
  if test -n "$$stale" ; then \
    echo "$(INSTALL_LIBDIR) contains stale stdlib artefacts"; \
    echo "Please rm $(INSTALL_LIBDIR)/stdlib__*.cm* and re-run make install"; \
    exit 1; \
  fi

install::
	$(INSTALL_DATA) \
	  stdlib.cma std_exit.cmo *.cmi camlheader_ur \
	  "$(INSTALL_LIBDIR)"
ifeq "$(INSTALL_SOURCE_ARTIFACTS)" "true"
	$(INSTALL_DATA) \
	  *.cmt *.cmti *.mli *.ml \
	  "$(INSTALL_LIBDIR)"
endif
	$(INSTALL_DATA) target_$(HEADER_NAME) "$(INSTALL_LIBDIR)/$(HEADER_NAME)"

ifeq "$(RUNTIMED)" "true"
install::
	$(INSTALL_DATA) target_camlheaderd "$(INSTALL_LIBDIR)/camlheaderd"
endif

ifeq "$(INSTRUMENTED_RUNTIME)" "true"
install::
	$(INSTALL_DATA) target_camlheaderi "$(INSTALL_LIBDIR)/camlheaderi"
endif

.PHONY: installopt
installopt: installopt-default

.PHONY: installopt-default
# Ensure any pre-4.13 lowercased artefacts are removed on macOS and Windows
installopt-default::
	stale="$(filter-out $(notdir $(wildcard stdlib__*.cmx)), \
         $(notdir $(wildcard $(INSTALL_LIBDIR)/stdlib__*.cmx)))"; \
  if test -n "$$stale" ; then \
    echo "$(INSTALL_LIBDIR) contains stale stdlib artefacts"; \
    echo "Please rm $(INSTALL_LIBDIR)/stdlib__*.cmx and re-run make install"; \
    exit 1; \
  fi

installopt-default::
	$(INSTALL_DATA) \
	  stdlib.cmxa stdlib.$(A) std_exit.$(O) *.cmx \
	  "$(INSTALL_LIBDIR)"
	cd "$(INSTALL_LIBDIR)"; $(RANLIB) stdlib.$(A)

ifeq "$(UNIX_OR_WIN32)" "unix"
HEADERPROGRAM = header
HEADER_PATH = $(BINDIR)/
else # Windows
HEADERPROGRAM = headernt
HEADER_PATH =
endif

ifeq "$(SHEBANGSCRIPTS)" "true"
bootheader: $(ROOTDIR)/Makefile.config Makefile
ifeq "$(LONG_SHEBANG)" "true"
	echo '#!/bin/sh' > $@
	echo 'exec "$(BINDIR)/ocamlrun" "$$0" "$$@"' >> $@
else
	echo '#!$(BINDIR)/ocamlrun' > $@
endif

camlheader_ur: Makefile
	echo '#!' | tr -d '\012' > $@

target_camlheader%: Makefile
	echo '#!/usr/bin/false' > $@

else # Hashbang scripts not supported

bootheader: $(HEADERPROGRAM).c $(ROOTDIR)/Makefile.config Makefile

# $@.exe is deleted to ensure no Cygwin .exe mangling takes place
bootheader: tmpheader.exe
	rm -f $@.exe
	cp $< $@

camlheader_ur: tmpheader.exe
	rm -f $@.exe
	cp $< $@

target_camlheader%: tmpheader.exe
	rm -f $@.exe
	cp $< $@

endif

target_$(HEADER_NAME): target_runtime.info tmpheader.exe
	@cat $^ > $@

$(HEADER_NAME): runtime.info tmpheader.exe
	@cat $^ > $@

.INTERMEDIATE: tmpheader.exe
tmpheader.exe: $(HEADERPROGRAM).$(O)
	$(call MKEXE_USING_COMPILER,$@,$^)
# FIXME This is wrong - mingw could invoke strip; MSVC equivalent?
ifneq "$(UNIX_OR_WIN32)" "win32"
	strip $@
endif

$(HEADERPROGRAM)%$(O): \
  OC_CPPFLAGS += -DRUNTIME_NAME='"$(HEADER_PATH)ocamlrun$(subst .,,$*)"'

stdlib.cma: $(OBJS)
	$(CAMLC) -a -o $@ $^

stdlib.cmxa: $(OBJS:.cmo=.cmx)
	$(CAMLOPT) -a -o $@ $^

sys.ml: $(ROOTDIR)/VERSION sys.mlp
	sed -e "s|%%VERSION%%|`sed -e 1q $< | tr -d '\r'`|" sys.mlp > $@

.PHONY: clean
clean::
	rm -f sys.ml

.PHONY: distclean
distclean: clean
	rm -f sys.ml runtime.info target_runtime.info

.PHONY: clean
clean::
	rm -f bootheader $(HEADER_NAME) target_$(HEADER_NAME)* camlheader_ur

export AWK

%.cmi: %.mli
	$(CAMLC) $(COMPFLAGS) $(shell ./Compflags $@) -c $<

# The dependency on the .mli file is in .depend (since stdlib__Foo.cmi
# depends on stdlib__foo.mli)
stdlib__%.cmi:
	$(CAMLC) $(COMPFLAGS) $(shell ./Compflags $@) \
	         -o $@ -c $(filter %.mli, $^)

%.cmo: %.ml
	$(CAMLC) $(COMPFLAGS) $(shell ./Compflags $@) -c $<

# The dependency on the .ml file is in .depend (since stdlib__Foo.cmo
# depends on stdlib__foo.ml)
stdlib__%.cmo:
	$(CAMLC) $(COMPFLAGS) $(shell ./Compflags $@) \
	         -o $@ -c $(filter %.ml, $^)

%.cmx: %.ml
	$(CAMLOPT) $(COMPFLAGS) $(OPTCOMPFLAGS) $(shell ./Compflags $@) -c $<

# The dependency on the .ml file is in .depend (since stdlib__Foo.cmx
# depends on stdlib__foo.ml)
stdlib__%.cmx:
	$(CAMLOPT) $(COMPFLAGS) $(OPTCOMPFLAGS) $(shell ./Compflags $@) \
	           -o $@ -c $(filter %.ml, $^)

# Dependencies on the compiler
COMPILER_DEPS=$(filter-out $(OCAMLRUN), $(CAMLC))
$(OBJS) std_exit.cmo: $(COMPILER_DEPS)
$(OBJS:.cmo=.cmi) std_exit.cmi: $(COMPILER_DEPS)
$(OBJS:.cmo=.cmx) std_exit.cmx: $(OPTCOMPILER)

# Dependencies on Stdlib (not tracked by ocamlc -depend)

$(OTHERS) std_exit.cmo: stdlib.cmi
$(OTHERS:.cmo=.cmi) std_exit.cmi: stdlib.cmi
$(OBJS:.cmo=.cmx) std_exit.cmx: stdlib.cmi
$(OTHERS:.cmo=.cmx) std_exit.cmx: stdlib.cmx

clean::
	rm -f *.cm* *.o *.obj *.a *.lib *.odoc
	rm -rf flexdll

include .depend

STDLIB_NAMESPACE_MODULES = $(subst $(SPACE),|,$(STDLIB_PREFIXED_MODULES))

.PHONY: depend
depend:
	$(CAMLDEP) $(DEPFLAGS) $(filter-out stdlib.%,$(wildcard *.mli *.ml)) \
	  > .depend.tmp
	$(CAMLDEP) $(DEPFLAGS) -pp "$(AWK) -f ./remove_module_aliases.awk" \
	  stdlib.ml stdlib.mli >> .depend.tmp
	sed -E \
	-e 's/^(${STDLIB_NAMESPACE_MODULES})(\.[^i]*)(i?) :/\1\2\3 : \1.ml\3/' \
	-e 's#(^| )(${STDLIB_NAMESPACE_MODULES})[.]#\1stdlib__\u\2.#' \
	  .depend.tmp > .depend
	rm -f .depend.tmp
