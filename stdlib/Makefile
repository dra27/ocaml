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

-include $(ROOTDIR)/Makefile.config
-include $(ROOTDIR)/Makefile.common

COMPILER=$(ROOTDIR)/ocamlc
CAMLC=$(CAMLRUN) $(COMPILER)
COMPFLAGS=-strict-sequence -absname -w +a-4-9-41-42-44-45-48 \
          -g -warn-error A -bin-annot -nostdlib \
          -safe-string -strict-formats
ifeq "$(FLAMBDA)" "true"
OPTCOMPFLAGS += -O3
endif
OPTCOMPILER=$(ROOTDIR)/ocamlopt
CAMLOPT=$(CAMLRUN) $(OPTCOMPILER)
CAMLDEP=$(BOOT_OCAMLC) -depend
DEPFLAGS=-slash

OC_CPPFLAGS += -I$(ROOTDIR)/runtime

# Object file prefix
P=stdlib__

include StdlibModules

OBJS=$(addsuffix .cmo,$(STDLIB_MODULES))
OTHERS=$(filter-out camlinternalFormatBasics.cmo stdlib.cmo,$(OBJS))

PREFIXED_OBJS=$(filter stdlib__%.cmo,$(OBJS))
UNPREFIXED_OBJS=$(PREFIXED_OBJS:stdlib__%.cmo=%)

.PHONY: all
all: stdlib.cma std_exit.cmo $(HEADER_NAME) target_$(HEADER_NAME) camlheader_ur

ifeq "$(RUNTIMED)" "true"
all: target_camlheaderd
endif

ifeq "$(RUNTIMEI)" "true"
all: target_camlheaderi
endif

.PHONY: allopt opt.opt # allopt and opt.opt are synonyms
allopt: stdlib.cmxa std_exit.cmx
opt.opt: allopt

LEGACY_OBJS=$(patsubst stdlib__%,"$(INSTALL_LIBDIR)/%", \
                                  $(filter stdlib__%,$(OBJS)))
.PHONY: install
install::
# Transitional: when upgrading from 4.06 -> 4.07, module M is in stdlib__m.cm*,
# while previously it was in m.cm*, which confuses the compiler.
	rm -f $(LEGACY_OBJS)
# Remove "old" pervasives.* and bigarray.* to avoid getting confused with the
# Stdlib versions.
	rm -f "$(INSTALL_LIBDIR)/pervasives.*" "$(INSTALL_LIBDIR)/bigarray.*"
# End transitional
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

ifeq "$(RUNTIMEI)" "true"
install::
	$(INSTALL_DATA) target_camlheaderi "$(INSTALL_LIBDIR)/camlheaderi"
endif

.PHONY: installopt
installopt: installopt-default

.PHONY: installopt-default
installopt-default:
	$(INSTALL_DATA) \
	  stdlib.cmxa stdlib.$(A) std_exit.$(O) *.cmx \
	  "$(INSTALL_LIBDIR)"
	cd "$(INSTALL_LIBDIR)"; $(RANLIB) stdlib.$(A)

ifeq "$(UNIX_OR_WIN32)" "unix"
HEADERPROGRAM = header
else # Windows
HEADERPROGRAM = headernt
endif

ifeq "$(SHEBANGSCRIPTS)" "true"

camlheader_ur: Makefile
	echo '#!' | tr -d '\012' > $@

target_camlheader%: Makefile
	echo '#!/usr/bin/false' > $@

else # Hashbang scripts not supported

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
	$(call MKEXE_BOOT,$@,$^)
# FIXME This is wrong - mingw could invoke strip; MSVC equivalent?
ifneq "$(UNIX_OR_WIN32)" "win32"
	strip $@
endif

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
	rm -f $(HEADER_NAME) target_$(HEADER_NAME)* camlheader_ur

.SUFFIXES: .mli .ml .cmi .cmo .cmx

export AWK

%.cmi: %.mli
	$(CAMLC) $(COMPFLAGS) $(shell ./Compflags $@) -c $<

stdlib__%.cmi: %.mli
	$(CAMLC) $(COMPFLAGS) $(shell ./Compflags $@) -o $@ -c $<

%.cmo: %.ml
	$(CAMLC) $(COMPFLAGS) $(shell ./Compflags $@) -c $<

stdlib__%.cmo: %.ml
	$(CAMLC) $(COMPFLAGS) $(shell ./Compflags $@) -o $@ -c $<

%.cmx: %.ml
	$(CAMLOPT) $(COMPFLAGS) $(OPTCOMPFLAGS) $(shell ./Compflags $@) -c $<

stdlib__%.cmx: %.ml
	$(CAMLOPT) $(COMPFLAGS) $(OPTCOMPFLAGS) $(shell ./Compflags $@) \
	           -o $@ -c $<

# Dependencies on the compiler
COMPILER_DEPS=$(filter-out -use-prims $(CAMLRUN), $(CAMLC))
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
	rm -f camlheader*
	rm -rf flexdll

include .depend

EMPTY :=
SPACE := $(EMPTY) $(EMPTY)

.PHONY: depend
depend:
	$(CAMLDEP) $(DEPFLAGS) $(filter-out stdlib.%,$(wildcard *.mli *.ml)) \
	  > .depend.tmp
	$(CAMLDEP) $(DEPFLAGS) -pp "$(AWK) -f ./remove_module_aliases.awk" \
	  stdlib.ml stdlib.mli >> .depend.tmp
	sed -Ee \
	  's#(^| )(${subst ${SPACE},|,${UNPREFIXED_OBJS}})[.]#\1stdlib__\2.#g' \
	  .depend.tmp > .depend
	rm -f .depend.tmp
