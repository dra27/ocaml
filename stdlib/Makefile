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

include $(ROOTDIR)/Makefile.config
include $(ROOTDIR)/Makefile.common

BUILD_TO ?= ./
TARGET_BINDIR ?= $(BINDIR)

COMPILER=$(ROOTDIR)/ocamlc
CAMLC=$(CAMLRUN) $(COMPILER)
COMPFLAGS=-strict-sequence -absname -w +a-4-9-41-42-44-45-48 \
          -g -warn-error A -bin-annot -nostdlib \
          -safe-string -strict-formats -I $(BUILD_TO)
ifeq "$(FLAMBDA)" "true"
OPTCOMPFLAGS=-O3
else
OPTCOMPFLAGS=
endif
ifeq "$(FUNCTION_SECTIONS)" "true"
OPTCOMPFLAGS += -function-sections
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
BUILD_OBJS=$(addprefix $(BUILD_TO),$(OBJS))
OTHERS=$(addprefix $(BUILD_TO),$(filter-out camlinternalFormatBasics.cmo stdlib.cmo,$(OBJS)))

PREFIXED_OBJS=$(filter stdlib__%.cmo,$(OBJS))
UNPREFIXED_OBJS=$(PREFIXED_OBJS:stdlib__%.cmo=%)

.PHONY: all
all: $(BUILD_TO)stdlib.cma $(BUILD_TO)std_exit.cmo $(BUILD_TO)camlheader $(BUILD_TO)target_camlheader $(BUILD_TO)camlheader_ur

ifeq "$(RUNTIMED)" "true"
all: $(BUILD_TO)camlheaderd $(BUILD_TO)target_camlheaderd
endif

ifeq "$(RUNTIMEI)" "true"
all: $(BUILD_TO)camlheaderi $(BUILD_TO)target_camlheaderi
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
	$(INSTALL_DATA) target_camlheader "$(INSTALL_LIBDIR)/camlheader"

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
HEADER_PATH = $(BINDIR)/
HEADER_TARGET_PATH = $(TARGET_BINDIR)/
else # Windows
HEADERPROGRAM = headernt
HEADER_PATH =
HEADER_TARGET_PATH =
endif

TARGETHEADERPROGRAM = target_$(HEADERPROGRAM)

# The shebang test in configure.ac will need updating if any runtime is
# introduced with a suffix more than one character long (camlheader_ur doesn't
# matter).
CAMLHEADERS =\
  camlheader target_camlheader camlheader_ur \
  camlheaderd target_camlheaderd \
  camlheaderi target_camlheaderi

# The % in pattern rules must always match something, hence the slightly strange
# patterns and $(subst ...) since `camlheader%:` wouldn't match `camlheader`
ifeq "$(SHEBANGSCRIPTS)" "true"
$(BUILD_TO)camlhead%: $(ROOTDIR)/Makefile.config Makefile
ifeq "$(LONG_SHEBANG)" "true"
	echo '#!/bin/sh' > $@
	echo 'exec "$(BINDIR)/ocamlrun$(subst er,,$*)" "$$0" "$$@"' >> $@
else
	echo '#!$(BINDIR)/ocamlrun$(subst er,,$*)' > $@
endif

# TODO This does not take long shebangs into account (since TARGET_BINDIR is not
#      yet processed by configure)
$(BUILD_TO)target_%: $(ROOTDIR)/Makefile.config Makefile
	echo '#!$(TARGET_BINDIR)/ocamlrun$(subst camlheader,,$*)' > $@

$(BUILD_TO)camlheader_ur: Makefile
	echo '#!' | tr -d '\012' > $@

else # Hashbang scripts not supported

$(addprefix $(BUILD_TO),$(CAMLHEADERS)): $(HEADERPROGRAM).c $(ROOTDIR)/Makefile.config Makefile

# $@.exe is deleted to ensure no Cygwin .exe mangling takes place
$(BUILD_TO)camlhead%: tmphead%.exe
	rm -f $@.exe
	mv $< $@

# Again, pattern weirdness here means that the dot is always present so that
# tmpheader.exe matches.
tmpheader%exe: $(HEADERPROGRAM)%$(O)
	$(call MKEXE_BOOT,$@,$^ $(EXTRALIBS))
# FIXME This is wrong - mingw could invoke strip; MSVC equivalent?
ifneq "$(UNIX_OR_WIN32)" "win32"
	strip $@
endif

$(HEADERPROGRAM)%$(O): \
  OC_CPPFLAGS += -DRUNTIME_NAME='"$(HEADER_PATH)ocamlrun$(subst .,,$*)"'

$(HEADERPROGRAM)%$(O): $(HEADERPROGRAM).c
	$(CC) -c $(OC_CFLAGS) $(OC_CPPFLAGS) $(OUTPUTOBJ)$@ $^

$(BUILD_TO)camlheader_ur: $(BUILD_TO)camlheader
	cp camlheader $@

ifeq "$(UNIX_OR_WIN32)" "unix"
tmptargetcamlheader%exe: $(TARGETHEADERPROGRAM)%$(O)
	$(call MKEXE_BOOT,$@,$^ $(EXTRALIBS))
	strip $@

$(TARGETHEADERPROGRAM)%$(O): $(HEADERPROGRAM).c
	$(CC) -c $(OC_CFLAGS) $(OC_CPPFLAGS) \
	      -DRUNTIME_NAME='"$(HEADER_TARGET_PATH)ocamlrun$(subst .,,$*)"' \
	      $(OUTPUTOBJ)$@ $^

target_%: tmptarget%.exe
	rm -f $@.exe
	mv $< $@
else
target_%: %
	cp $< $@
endif

endif # ifeq "$(SHEBANGSCRIPTS)" "true"

$(BUILD_TO)stdlib.cma: $(BUILD_OBJS)
	$(CAMLC) -a -o $@ $^

$(BUILD_TO)stdlib.cmxa: $(BUILD_OBJS:.cmo=.cmx)
	$(CAMLOPT) -a -o $@ $^

sys.ml: $(ROOTDIR)/VERSION sys.mlp
	sed -e "s|%%VERSION%%|`sed -e 1q $< | tr -d '\r'`|" sys.mlp > $@

.PHONY: clean
clean::
	rm -f sys.ml

clean::
	rm -f $(CAMLHEADERS)

.SUFFIXES: .mli .ml .cmi .cmo .cmx

export AWK

$(BUILD_TO)%.cmi: %.mli
	$(CAMLC) $(COMPFLAGS) $(shell ./Compflags $@) -o $@ -c $<

$(BUILD_TO)stdlib__%.cmi: %.mli
	$(CAMLC) $(COMPFLAGS) $(shell ./Compflags $@) -o $@ -c $<

$(BUILD_TO)%.cmo: %.ml
	$(CAMLC) $(COMPFLAGS) $(shell ./Compflags $@) -o $@ -c $<

$(BUILD_TO)stdlib__%.cmo: %.ml
	$(CAMLC) $(COMPFLAGS) $(shell ./Compflags $@) -o $@ -c $<

%.cmx: %.ml
	$(CAMLOPT) $(COMPFLAGS) $(OPTCOMPFLAGS) $(shell ./Compflags $@) -c $<

stdlib__%.cmx: %.ml
	$(CAMLOPT) $(COMPFLAGS) $(OPTCOMPFLAGS) $(shell ./Compflags $@) \
	           -o $@ -c $<

# Dependencies on the compiler
COMPILER_DEPS=$(filter-out -use-prims $(CAMLRUN), $(CAMLC))
$(BUILD_OBJS) $(BUILD_TO)std_exit.cmo: $(COMPILER_DEPS)
$(BUILD_OBJS:.cmo=.cmi) $(BUILD_TO)std_exit.cmi: $(COMPILER_DEPS)
$(BUILD_OBJS:.cmo=.cmx) std_exit.cmx: $(OPTCOMPILER)

# Dependencies on Stdlib (not tracked by ocamlc -depend)

$(OTHERS) $(BUILD_TO)std_exit.cmo: $(BUILD_TO)stdlib.cmi
$(OTHERS:.cmo=.cmi) $(BUILD_TO)std_exit.cmi: $(BUILD_TO)stdlib.cmi
$(BUILD_OBJS:.cmo=.cmx) $(BUILD_TO)std_exit.cmx: $(BUILD_TO)stdlib.cmi
$(OTHERS:.cmo=.cmx) $(BUILD_TO)std_exit.cmx: $(BUILD_TO)stdlib.cmx

clean::
	rm -f *.cm* *.$(O) *.$(A) *.odoc
	rm -f camlheader*

include .depend

EMPTY :=
SPACE := $(EMPTY) $(EMPTY)

.PHONY: depend
depend:
	$(CAMLDEP) $(DEPFLAGS) $(filter-out stdlib.%,$(wildcard *.mli *.ml)) \
	  > .depend.tmp
	$(CAMLDEP) $(DEPFLAGS) -pp "$(AWK) -f remove_module_aliases.awk" \
	  stdlib.ml stdlib.mli >> .depend.tmp
	sed -Ee \
	  's#(^| )(${subst ${SPACE},|,${UNPREFIXED_OBJS}})[.]#\1stdlib__\2.#g' \
	  .depend.tmp > .depend
	rm -f .depend.tmp
