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

CAMLRUN ?= $(ROOTDIR)/boot/ocamlrun

# There are three ways the Standard Library is compiled in bytecode:
# 1. During coldstart
#      - using ../boot/ocamlc which runs on ../boot/ocamlrun
# 2. During coreall (via library),
#      - using ../ocamlc which runs on ../boot/ocamlrun
# 3. During coreboot (via library-cross),
#      - using ../ocamlc which at that point runs on ../runtime/ocamlrun
# If $(USE_BOOT_OCAMLC) is non-empty, we select case 1 and use $(BOOT_OCAMLC).
# Otherwise, we use $(CAMLRUN) ../ocamlc, with $(CAMLRUN) being
# ../boot/ocamlrun by default, but able to overridden by library-cross to
# ../runtime/ocamlrun.
USE_BOOT_OCAMLC ?=

ifeq "$(USE_BOOT_OCAMLC)" ""
CAMLC = $(CAMLRUN) $(ROOTDIR)/ocamlc
else
CAMLC = $(BOOT_OCAMLC)
endif
COMPFLAGS=-strict-sequence -absname -w +a-4-9-41-42-44-45-48 \
          -g -warn-error A -bin-annot -nostdlib \
          -safe-string -strict-formats
ifeq "$(FLAMBDA)" "true"
OPTCOMPFLAGS=-O3
else
OPTCOMPFLAGS=
endif
OPTCOMPILER=$(ROOTDIR)/ocamlopt
CAMLOPT=$(CAMLRUN) $(OPTCOMPILER)
CAMLDEP=$(CAMLRUN) $(ROOTDIR)/boot/ocamlc -depend
DEPFLAGS=-slash

OC_CPPFLAGS += -I$(ROOTDIR)/runtime

# Object file prefix
P=stdlib__

OBJS=camlinternalFormatBasics.cmo stdlib.cmo $(OTHERS)
OTHERS= $(P)pervasives.cmo $(P)seq.cmo $(P)option.cmo $(P)result.cmo \
  $(P)bool.cmo $(P)char.cmo $(P)uchar.cmo $(P)sys.cmo $(P)list.cmo \
  $(P)bytes.cmo $(P)string.cmo $(P)unit.cmo \
  $(P)marshal.cmo $(P)obj.cmo $(P)array.cmo $(P)float.cmo \
  $(P)int.cmo $(P)int32.cmo $(P)int64.cmo $(P)nativeint.cmo \
  $(P)lexing.cmo $(P)parsing.cmo \
  $(P)set.cmo $(P)map.cmo $(P)stack.cmo $(P)queue.cmo \
  camlinternalLazy.cmo $(P)lazy.cmo $(P)stream.cmo \
  $(P)buffer.cmo camlinternalFormat.cmo $(P)printf.cmo \
  $(P)arg.cmo $(P)printexc.cmo $(P)fun.cmo $(P)gc.cmo \
  $(P)digest.cmo $(P)random.cmo $(P)hashtbl.cmo $(P)weak.cmo \
  $(P)format.cmo $(P)scanf.cmo $(P)callback.cmo \
  camlinternalOO.cmo $(P)oo.cmo camlinternalMod.cmo \
  $(P)genlex.cmo $(P)ephemeron.cmo \
  $(P)filename.cmo $(P)complex.cmo \
  $(P)arrayLabels.cmo $(P)listLabels.cmo $(P)bytesLabels.cmo \
  $(P)stringLabels.cmo $(P)moreLabels.cmo $(P)stdLabels.cmo \
  $(P)spacetime.cmo $(P)bigarray.cmo

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

ifeq "$(PROFILING)" "true"
PROFILINGTARGET = prof
else
PROFILINGTARGET = noprof
endif

.PHONY: allopt opt.opt # allopt and opt.opt are synonyms
allopt: stdlib.cmxa std_exit.cmx allopt-$(PROFILINGTARGET)
opt.opt: allopt

.PHONY: allopt-noprof
allopt-noprof:

.PHONY: allopt-prof
allopt-prof: stdlib.p.cmxa std_exit.p.cmx
	rm -f std_exit.p.cmi

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
installopt: installopt-default installopt-$(PROFILINGTARGET)

.PHONY: installopt-default
installopt-default:
	$(INSTALL_DATA) \
	  stdlib.cmxa stdlib.$(A) std_exit.$(O) *.cmx \
	  "$(INSTALL_LIBDIR)"
	cd "$(INSTALL_LIBDIR)"; $(RANLIB) stdlib.$(A)

.PHONY: installopt-noprof
installopt-noprof:

.PHONY: installopt-prof
installopt-prof:
	$(INSTALL_DATA) \
	  stdlib.p.cmxa stdlib.p.$(A) std_exit.p.cmx std_exit.p.$(O) \
	  "$(INSTALL_LIBDIR)"
	cd "$(INSTALL_LIBDIR)"; $(RANLIB) stdlib.p.$(A)

ifeq "$(HASHBANGSCRIPTS)" "true"

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

MANGLING = $(filter true,$(SUFFIXING))
target_$(HEADER_NAME): tmpheader.exe
	@{ printf '$(if $(MANGLING),$(ZINC_RUNTIME_ID_HI),\000)'; \
     cat $^; } > $@

$(HEADER_NAME): runtime.info tmpheader.exe
	@{ cat $^; \
     printf '$(if $(filter true,$(SUFFIXING)),$(ZINC_RUNTIME_ID))'; } > $@

# The mingw-w64 and MSVC versions of tmpheader.exe are linked with special flags
# to reduce their size (considerably). In particular, the entry point is
# overridden, which prevents the linking of crt0.
ifeq "$(TOOLCHAIN)" "mingw"
# mingw-w64: optimise header.o for space and remove all unused sections during
# linking.
header.o: OC_CFLAGS += -Os
ifeq "$(SYSTEM)" "mingw"
  ENTRYPOINT = _wmainCRTStartup
else
  ENTRYPOINT = wmainCRTStartup
endif
# Certainly for GCC, -nostdlib automatically adds -nostartfiles (clang's
# documentation is not explicit on this point, but it would be unusual for clang
# and GCC to differ). --gc-sections removes unreferenced code and data sections.
tmpheader.exe: OC_LDFLAGS += \
  -nostdlib -nostartfiles -Wl,--gc-sections -Wl,-e,$(ENTRYPOINT)
HEADERLIBS = -lkernel32
else ifeq "$(TOOLCHAIN)" "msvc"
# MSVC: Optimise header.obj for space. cl doesn't have an equivalent of
# -nostdlib, however it also doesn't have default libraries in the same way as
# GCC - the equivalent of crt0.o is linked because it provides the entry point
# symbol, rather than by being explicitly added to the linking command line.
# /GS- disables compilation of runtime security checks and /NOCOFFGRPINFO is an
# undocumented linker flag which removes the debug directory from the PE+ image.
header.obj: OC_CFLAGS += /GS- /Os
tmpheader.exe: OC_LDFLAGS += /NOCOFFGRPINFO /subsystem:console
HEADERLIBS = kernel32.lib
else
HEADERLIBS =
endif

.INTERMEDIATE: tmpheader.exe
tmpheader.exe: header.$(O)
	$(call MKEXE_BOOT,$@,$^ $(HEADERLIBS))
# FIXME This is wrong - mingw could invoke strip; MSVC equivalent?
ifneq "$(UNIX_OR_WIN32)" "win32"
	strip $@
endif

header.$(O): header.c
	$(CC) -c $(OC_CFLAGS) $(OC_CPPFLAGS) $(OUTPUTOBJ)$@ $^

stdlib.cma: $(OBJS)
	$(CAMLC) -a -o $@ $^

stdlib.cmxa: $(OBJS:.cmo=.cmx)
	$(CAMLOPT) -a -o $@ $^

stdlib.p.cmxa: $(OBJS:.cmo=.p.cmx)
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

.SUFFIXES: .mli .ml .cmi .cmo .cmx .p.cmx

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

%.p.cmx: %.ml
	$(CAMLOPT) $(COMPFLAGS) $(OPTCOMPFLAGS) $(shell ./Compflags $@) \
	           -p -c -o $@ $<

stdlib__%.p.cmx: %.ml
	$(CAMLOPT) $(COMPFLAGS) $(OPTCOMPFLAGS) $(shell ./Compflags $@) \
	           -p -c -o $@ $<

# Dependencies on the compiler
COMPILER_DEPS=$(filter-out $(CAMLRUN), $(CAMLC))
$(OBJS) std_exit.cmo: $(COMPILER_DEPS)
$(OBJS:.cmo=.cmi) std_exit.cmi: $(COMPILER_DEPS)
$(OBJS:.cmo=.cmx) std_exit.cmx: $(OPTCOMPILER)
$(OBJS:.cmo=.p.cmx) std_exit.p.cmx: $(OPTCOMPILER)

# Dependencies on Stdlib (not tracked by ocamlc -depend)

$(OTHERS) std_exit.cmo: stdlib.cmi
$(OTHERS:.cmo=.cmi) std_exit.cmi: stdlib.cmi
$(OBJS:.cmo=.cmx) std_exit.cmx: stdlib.cmi
$(OBJS:.cmo=.p.cmx) std_exit.p.cmx: stdlib.cmi
$(OTHERS:.cmo=.cmx) std_exit.cmx: stdlib.cmx
$(OTHERS:.cmo=.p.cmx) std_exit.p.cmx: stdlib.cmx

clean::
	rm -f *.cm* *.o *.obj *.a *.lib *.odoc
	rm -f *~
	rm -f camlheader*
	rm -rf flexdll

include .depend

EMPTY :=
SPACE := $(EMPTY) $(EMPTY)

# Note that .p.cmx targets do not depend (for compilation) upon other
# .p.cmx files.  When the compiler imports another compilation unit,
# it looks for the .cmx file (not .p.cmx).
.PHONY: depend
depend:
	$(CAMLDEP) $(DEPFLAGS) $(filter-out stdlib.%,$(wildcard *.mli *.ml)) \
	  > .depend.tmp
	$(CAMLDEP) $(DEPFLAGS) -pp "$(AWK) -f ./remove_module_aliases.awk" \
	  stdlib.ml stdlib.mli >> .depend.tmp
	$(CAMLDEP) $(DEPFLAGS) $(filter-out stdlib.%,$(wildcard *.ml)) \
	  | sed -e 's/\.cmx : /.p.cmx : /g' >>.depend.tmp
	$(CAMLDEP) $(DEPFLAGS) -pp "$(AWK) -f remove_module_aliases.awk" \
	  stdlib.ml \
	  | sed -e 's/\.cmx : /.p.cmx : /g' >> .depend.tmp
	sed -Ee \
	  's#(^| )(${subst ${SPACE},|,${UNPREFIXED_OBJS}})[.]#\1stdlib__\2.#g' \
	  .depend.tmp > .depend
	rm -f .depend.tmp
