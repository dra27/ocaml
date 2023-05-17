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

# The main Makefile

ROOTDIR = .

# The configure and *clean targets can all be run without running ./configure
# first.
# If no goals were specified (i.e. `make`), add defaultentry (since it requires
# ./configure to be run)
CAN_BE_UNCONFIGURED := $(strip \
  $(filter-out partialclean clean distclean configure, \
	$(if $(MAKECMDGOALS),$(MAKECMDGOALS),defaultentry)))

ifeq "$(CAN_BE_UNCONFIGURED)" ""
-include Makefile.config
-include Makefile.common
else
include Makefile.config
include Makefile.common
endif

.PHONY: defaultentry
ifeq "$(NATIVE_COMPILER)" "true"
defaultentry: world.opt
else
defaultentry: world
endif

MKDIR=mkdir -p

include stdlib/StdlibModules

CAMLC=$(BOOT_OCAMLC) -g -nostdlib -I boot -use-prims runtime/primitives
CAMLOPT=$(CAMLRUN) ./ocamlopt -g -nostdlib -I stdlib -I otherlibs/dynlink
ARCHES=amd64 i386 arm arm64 power s390x riscv
INCLUDES=-I utils -I parsing -I typing -I bytecomp -I file_formats \
        -I lambda -I middle_end -I middle_end/closure \
        -I middle_end/flambda -I middle_end/flambda/base_types \
        -I asmcomp -I asmcomp/debug \
        -I driver -I toplevel

COMPFLAGS=-strict-sequence -principal -absname -w +a-4-9-40-41-42-44-45-48-66 \
	  -warn-error A \
          -bin-annot -safe-string -strict-formats $(INCLUDES)
LINKFLAGS=

ifeq "$(strip $(NATDYNLINKOPTS))" ""
OCAML_NATDYNLINKOPTS=
else
OCAML_NATDYNLINKOPTS = -ccopt "$(NATDYNLINKOPTS)"
endif

YACCFLAGS=-v --strict
CAMLLEX=$(CAMLRUN) boot/ocamllex
CAMLDEP=$(CAMLRUN) boot/ocamlc -depend
DEPFLAGS=-slash
DEPINCLUDES=$(INCLUDES)

OCAMLDOC_OPT=$(WITH_OCAMLDOC:=.opt)
OCAMLTEST_OPT=$(WITH_OCAMLTEST:=.opt)

BYTESTART=driver/main.cmo

OPTSTART=driver/optmain.cmo

TOPLEVELSTART=toplevel/topstart.cmo

OPTTOPLEVELSTART=toplevel/opttopstart.cmo

PERVASIVES=$(STDLIB_MODULES) outcometree topdirs toploop

LIBFILES=stdlib.cma std_exit.cmo *.cmi camlheader

COMPLIBDIR=$(LIBDIR)/compiler-libs

TOPINCLUDES=$(addprefix -I otherlibs/,$(filter-out %threads,$(OTHERLIBRARIES)))
RUNTOP=./runtime/ocamlrun ./ocaml \
  -nostdlib -I stdlib \
  -noinit $(TOPFLAGS) $(TOPINCLUDES)
NATRUNTOP=./ocamlnat$(EXE) \
  -nostdlib -I stdlib \
  -noinit $(TOPFLAGS) $(TOPINCLUDES)
ifeq "$(UNIX_OR_WIN32)" "unix"
EXTRAPATH=
else
EXTRAPATH = PATH="otherlibs/win32unix:$(PATH)"
endif


ifeq "$(BOOTSTRAPPING_FLEXDLL)" "false"
  COLDSTART_DEPS =
  BOOT_FLEXLINK_CMD =
else
  COLDSTART_DEPS = boot/ocamlruns$(EXE)
  BOOT_FLEXLINK_CMD = \
    FLEXLINK_CMD="../boot/ocamlruns$(EXE) ../boot/flexlink.byte$(EXE)"
endif

# targets for the compilerlibs/*.{cma,cmxa} archives
include compilerlibs/Makefile.compilerlibs

# The configuration file

utils/config.ml: utils/config.mlp Makefile.config utils/Makefile
	$(MAKE) -C utils config.ml

.PHONY: reconfigure
reconfigure:
	ac_read_git_config=true ./configure $(CONFIGURE_ARGS)

utils/domainstate.ml: utils/domainstate.ml.c runtime/caml/domain_state.tbl
	$(CPP) -I runtime/caml $< > $@

utils/domainstate.mli: utils/domainstate.mli.c runtime/caml/domain_state.tbl
	$(CPP) -I runtime/caml $< > $@

configure: configure.ac aclocal.m4 VERSION tools/autogen
	tools/autogen

.PHONY: partialclean
partialclean::
	rm -f utils/config.ml utils/domainstate.ml utils/domainstate.mli

.PHONY: beforedepend
beforedepend:: utils/config.ml utils/domainstate.ml utils/domainstate.mli

USE_RUNTIME_PRIMS = -use-prims ../runtime/primitives
USE_STDLIB = -nostdlib -I ../stdlib

FLEXDLL_OBJECTS = \
  flexdll_$(FLEXDLL_CHAIN).$(O) flexdll_initer_$(FLEXDLL_CHAIN).$(O)
FLEXLINK_BUILD_ENV = \
  MSVC_DETECT=0 OCAML_CONFIG_FILE=../Makefile.config \
  CHAINS=$(FLEXDLL_CHAIN) ROOTDIR=..

boot/ocamlruns$(EXE):
	$(MAKE) -C runtime ocamlruns$(EXE)
	cp runtime/ocamlruns$(EXE) boot/ocamlruns$(EXE)

# Start up the system from the distribution compiler
# The process depends on whether FlexDLL is also being bootstrapped.
# Normal procedure:
#   - Build the runtime
#   - Build the standard library using runtime/ocamlrun
# FlexDLL procedure:
#   - Build ocamlruns
#   - Build the standard library using boot/ocamlruns
#   - Build flexlink and FlexDLL support objects
#   - Build the runtime
# runtime/ocamlrun is then installed to boot/ocamlrun and the stdlib artefacts
# are copied to boot/
.PHONY: coldstart
coldstart: $(COLDSTART_DEPS)
ifeq "$(BOOTSTRAPPING_FLEXDLL)" "false"
	$(MAKE) -C runtime all
	$(MAKE) -C stdlib \
	  CAMLRUN='$$(ROOTDIR)/runtime/ocamlrun$(EXE)' \
	  CAMLC='$$(BOOT_OCAMLC) $(USE_RUNTIME_PRIMS)' all
else
	$(MAKE) -C stdlib CAMLRUN='$$(ROOTDIR)/boot/ocamlruns$(EXE)' \
    CAMLC='$$(BOOT_OCAMLC)' all
	$(MAKE) -C $(FLEXDLL_SOURCES) $(FLEXLINK_BUILD_ENV) \
	  CAMLRUN='$$(ROOTDIR)/boot/ocamlruns$(EXE)' NATDYNLINK=false \
	  OCAMLOPT='$(value BOOT_OCAMLC) $(USE_RUNTIME_PRIMS) $(USE_STDLIB)' \
	  flexlink.exe support
	mv $(FLEXDLL_SOURCES)/flexlink.exe boot/flexlink.byte$(EXE)
	cp $(addprefix $(FLEXDLL_SOURCES)/, $(FLEXDLL_OBJECTS)) boot/
	$(MAKE) -C runtime $(BOOT_FLEXLINK_CMD) all
endif # ifeq "$(BOOTSTRAPPING_FLEXDLL)" "false"
	cp runtime/ocamlrun$(EXE) boot/ocamlrun$(EXE)
	cd stdlib; cp $(LIBFILES) ../boot
	cd boot; $(LN) ../runtime/libcamlrun.$(A) .

# Recompile the core system using the bootstrap compiler
.PHONY: coreall
coreall: runtime
	$(MAKE) ocamlc
	$(MAKE) ocamllex ocamltools library

# Build the core system: the minimum needed to make depend and bootstrap
.PHONY: core
core:
	$(MAKE) coldstart
	$(MAKE) coreall

# Check if fixpoint reached
.PHONY: compare
compare:
	@if $(CAMLRUN) tools/cmpbyt boot/ocamlc ocamlc \
         && $(CAMLRUN) tools/cmpbyt boot/ocamllex lex/ocamllex; \
	then echo "Fixpoint reached, bootstrap succeeded."; \
	else \
	  echo "Fixpoint not reached, try one more bootstrapping cycle."; \
	  exit 1; \
	fi

# Promote a compiler

PROMOTE ?= cp

.PHONY: promote-common
promote-common:
	$(PROMOTE) ocamlc boot/ocamlc
	$(PROMOTE) lex/ocamllex boot/ocamllex
	cd stdlib; cp $(LIBFILES) ../boot

# Promote the newly compiled system to the rank of cross compiler
# (Runs on the old runtime, produces code for the new runtime)
.PHONY: promote-cross
promote-cross: promote-common

# Promote the newly compiled system to the rank of bootstrap compiler
# (Runs on the new runtime, produces code for the new runtime)
.PHONY: promote
promote: PROMOTE = $(CAMLRUN) tools/stripdebug
promote: promote-common
	cp runtime/ocamlrun$(EXE) boot/ocamlrun$(EXE)

# Compile the native-code compiler
.PHONY: opt-core
opt-core: runtimeopt
	$(MAKE) ocamlopt
	$(MAKE) libraryopt

.PHONY: opt
opt: checknative
	$(MAKE) runtimeopt
	$(MAKE) ocamlopt
	$(MAKE) libraryopt
	$(MAKE) otherlibrariesopt ocamltoolsopt

# Native-code versions of the tools
.PHONY: opt.opt
opt.opt: checknative
	$(MAKE) checkstack
	$(MAKE) runtime
	$(MAKE) core
	$(MAKE) ocaml
	$(MAKE) opt-core
ifeq "$(BOOTSTRAPPING_FLEXDLL)" "true"
	$(MAKE) flexlink.opt$(EXE)
endif
	$(MAKE) ocamlc.opt
	$(MAKE) otherlibraries $(WITH_DEBUGGER) $(WITH_OCAMLDOC) \
	  $(WITH_OCAMLTEST)
	$(MAKE) ocamlopt.opt
	$(MAKE) otherlibrariesopt
	$(MAKE) ocamllex.opt ocamltoolsopt ocamltoolsopt.opt $(OCAMLDOC_OPT) \
	  $(OCAMLTEST_OPT)
ifeq "$(WITH_OCAMLDOC)-$(STDLIB_MANPAGES)" "ocamldoc-true"
	$(MAKE) manpages
endif

# Core bootstrapping cycle
.PHONY: coreboot
coreboot:
# Promote the new compiler but keep the old runtime
# This compiler runs on boot/ocamlrun and produces bytecode for
# runtime/ocamlrun
	$(MAKE) promote-cross
# Rebuild ocamlc and ocamllex (run on runtime/ocamlrun)
	$(MAKE) partialclean
	$(MAKE) ocamlc ocamllex ocamltools
# Rebuild the library (using runtime/ocamlrun ./ocamlc)
	$(MAKE) library-cross
# Promote the new compiler and the new runtime
	$(MAKE) CAMLRUN=runtime/ocamlrun promote
# Rebuild the core system
	$(MAKE) partialclean
	$(MAKE) core
# Check if fixpoint reached
	$(MAKE) compare

# Recompile the system using the bootstrap compiler

.PHONY: all
all: coreall
	$(MAKE) ocaml
	$(MAKE) otherlibraries $(WITH_DEBUGGER) $(WITH_OCAMLDOC) \
         $(WITH_OCAMLTEST)
ifeq "$(WITH_OCAMLDOC)-$(STDLIB_MANPAGES)" "ocamldoc-true"
	$(MAKE) manpages
endif

# Bootstrap and rebuild the whole system.
# The compilation of ocaml will fail if the runtime has changed.
# Never mind, just do make bootstrap to reach fixpoint again.
.PHONY: bootstrap
bootstrap: coreboot
	$(MAKE) all

# Compile everything the first time

.PHONY: world
world: coldstart
	$(MAKE) all

# Compile also native code compiler and libraries, fast
.PHONY: world.opt
world.opt: checknative
	$(MAKE) coldstart
	$(MAKE) opt.opt

# FlexDLL sources missing error messages
# Different git mechanism displayed depending on whether this source tree came
# from a git clone or a source tarball.

.PHONY: flexdll flexlink flexlink.opt

ifeq "$(BOOTSTRAPPING_FLEXDLL)" "false"
flexdll flexlink flexlink.opt:
	@echo It is no longer necessary to bootstrap FlexDLL with a separate
	@echo make invocation. Simply place the sources for FlexDLL in a
	@echo sub-directory.
	@echo This can either be done by downloading a source tarball from
	@echo \  https://github.com/alainfrisch/flexdll/releases
	@if [ -d .git ]; then \
	  echo or by checking out the flexdll submodule with; \
	  echo \  git submodule update --init; \
	else \
	  echo or by cloning the git repository; \
	  echo \  git clone https://github.com/alainfrisch/flexdll.git; \
	fi
	@echo "Then pass --with-flexdll=<dir> to configure and build as normal."
	@false

else

.PHONY: flexdll
flexdll: flexdll/Makefile
	@echo WARNING! make flexdll is no longer required
	@echo This target will be removed in a future release.

.PHONY: flexlink
flexlink:
	@echo Bootstrapping just flexlink.exe is no longer supported
	@echo Bootstrapping FlexDLL is now enabled with
	@echo ./configure --with-flexdll
	@false

ifeq "$(wildcard ocamlopt.opt)" ""
  FLEXLINK_OCAMLOPT=../runtime/ocamlrun$(EXE) ../ocamlopt
else
  FLEXLINK_OCAMLOPT=../ocamlopt.opt
endif

flexlink.opt$(EXE):
	$(MAKE) -C $(FLEXDLL_SOURCES) $(FLEXLINK_BUILD_ENV) \
    OCAML_FLEXLINK='$(value CAMLRUN) $$(ROOTDIR)/boot/flexlink.byte$(EXE)' \
	  OCAMLOPT="$(FLEXLINK_OCAMLOPT) -nostdlib -I ../stdlib" flexlink.exe
	mv $(FLEXDLL_SOURCES)/flexlink.exe $@

partialclean::
	rm -f flexlink.opt$(EXE)
endif # ifeq "$(BOOTSTRAPPING_FLEXDLL)" "false"

INSTALL_COMPLIBDIR = $(DESTDIR)$(COMPLIBDIR)
INSTALL_FLEXDLLDIR = $(INSTALL_LIBDIR)/flexdll
FLEXDLL_MANIFEST = default$(filter-out _i386,_$(ARCH)).manifest

# Installation
.PHONY: install
install:
	$(MKDIR) "$(INSTALL_BINDIR)"
	$(MKDIR) "$(INSTALL_LIBDIR)"
	$(MKDIR) "$(INSTALL_STUBLIBDIR)"
	$(MKDIR) "$(INSTALL_COMPLIBDIR)"
	$(INSTALL_DATA) \
	  VERSION \
	  "$(INSTALL_LIBDIR)"
	$(MAKE) -C runtime install
	$(INSTALL_PROG) ocaml "$(INSTALL_BINDIR)/ocaml$(EXE)"
ifeq "$(INSTALL_BYTECODE_PROGRAMS)" "true"
	$(INSTALL_PROG) ocamlc "$(INSTALL_BINDIR)/ocamlc.byte$(EXE)"
endif
	$(MAKE) -C stdlib install
ifeq "$(INSTALL_BYTECODE_PROGRAMS)" "true"
	$(INSTALL_PROG) lex/ocamllex "$(INSTALL_BINDIR)/ocamllex.byte$(EXE)"
endif
	$(INSTALL_PROG) yacc/ocamlyacc$(EXE) "$(INSTALL_BINDIR)/ocamlyacc$(EXE)"
	$(INSTALL_DATA) \
	   utils/*.cmi \
	   parsing/*.cmi \
	   typing/*.cmi \
	   bytecomp/*.cmi \
	   file_formats/*.cmi \
	   lambda/*.cmi \
	   driver/*.cmi \
	   toplevel/*.cmi \
	   "$(INSTALL_COMPLIBDIR)"
ifeq "$(INSTALL_SOURCE_ARTIFACTS)" "true"
	$(INSTALL_DATA) \
	   utils/*.cmt utils/*.cmti utils/*.mli \
	   parsing/*.cmt parsing/*.cmti parsing/*.mli \
	   typing/*.cmt typing/*.cmti typing/*.mli \
	   file_formats/*.cmt file_formats/*.cmti file_formats/*.mli \
	   lambda/*.cmt lambda/*.cmti lambda/*.mli \
	   bytecomp/*.cmt bytecomp/*.cmti bytecomp/*.mli \
	   driver/*.cmt driver/*.cmti driver/*.mli \
	   toplevel/*.cmt toplevel/*.cmti toplevel/*.mli \
	   "$(INSTALL_COMPLIBDIR)"
endif
	$(INSTALL_DATA) \
	  compilerlibs/*.cma \
	  "$(INSTALL_COMPLIBDIR)"
	$(INSTALL_DATA) \
	   $(BYTESTART) $(TOPLEVELSTART) \
	   "$(INSTALL_COMPLIBDIR)"
	$(INSTALL_PROG) expunge "$(INSTALL_LIBDIR)/expunge$(EXE)"
	$(INSTALL_DATA) \
	   toplevel/topdirs.cmi \
	   "$(INSTALL_LIBDIR)"
ifeq "$(INSTALL_SOURCE_ARTIFACTS)" "true"
	$(INSTALL_DATA) \
	   toplevel/topdirs.cmt toplevel/topdirs.cmti \
           toplevel/topdirs.mli \
	   "$(INSTALL_LIBDIR)"
endif
	$(MAKE) -C tools install
ifeq "$(UNIX_OR_WIN32)" "unix" # Install manual pages only on Unix
	$(MKDIR) "$(INSTALL_MANDIR)/man$(PROGRAMS_MAN_SECTION)"
	-$(MAKE) -C man install
endif
	for i in $(OTHERLIBRARIES); do \
	  $(MAKE) -C otherlibs/$$i install || exit $$?; \
	done
# Transitional: findlib 1.7.3 is confused if leftover num.cm? files remain
# from an previous installation of OCaml before otherlibs/num was removed.
	rm -f "$(INSTALL_LIBDIR)"/num.cm?
# End transitional
ifneq "$(WITH_OCAMLDOC)" ""
	$(MAKE) -C ocamldoc install
endif
	if test -n "$(WITH_DEBUGGER)"; then \
	  $(MAKE) -C debugger install; \
	fi
ifeq "$(BOOTSTRAPPING_FLEXDLL)" "true"
ifeq "$(TOOLCHAIN)" "msvc"
	$(INSTALL_DATA) $(FLEXDLL_SOURCES)/$(FLEXDLL_MANIFEST) \
    "$(INSTALL_BINDIR)/"
endif
ifeq "$(INSTALL_BYTECODE_PROGRAMS)" "true"
	$(INSTALL_PROG) \
	  boot/flexlink.byte$(EXE) "$(INSTALL_BINDIR)/flexlink.byte$(EXE)"
endif # ifeq "$(INSTALL_BYTECODE_PROGRAMS)" "true"
	$(MKDIR) "$(INSTALL_FLEXDLLDIR)"
	$(INSTALL_DATA) $(addprefix stdlib/flexdll/, $(FLEXDLL_OBJECTS)) \
    "$(INSTALL_FLEXDLLDIR)"
endif # ifeq "$(BOOTSTRAPPING_FLEXDLL)" "true"
	$(INSTALL_DATA) Makefile.config "$(INSTALL_LIBDIR)/Makefile.config"
ifeq "$(INSTALL_BYTECODE_PROGRAMS)" "true"
	if test -f ocamlopt; then $(MAKE) installopt; else \
	   cd "$(INSTALL_BINDIR)"; \
	   $(LN) ocamlc.byte$(EXE) ocamlc$(EXE); \
	   $(LN) ocamllex.byte$(EXE) ocamllex$(EXE); \
	   (test -f flexlink.byte$(EXE) && \
	      $(LN) flexlink.byte$(EXE) flexlink$(EXE)) || true; \
	fi
else
	if test -f ocamlopt; then $(MAKE) installopt; fi
endif

# Installation of the native-code compiler
.PHONY: installopt
installopt:
	$(MAKE) -C runtime installopt
ifeq "$(INSTALL_BYTECODE_PROGRAMS)" "true"
	$(INSTALL_PROG) ocamlopt "$(INSTALL_BINDIR)/ocamlopt.byte$(EXE)"
endif
	$(MAKE) -C stdlib installopt
	$(INSTALL_DATA) \
	    middle_end/*.cmi \
	    "$(INSTALL_COMPLIBDIR)"
	$(INSTALL_DATA) \
	    middle_end/closure/*.cmi \
	    "$(INSTALL_COMPLIBDIR)"
	$(INSTALL_DATA) \
	    middle_end/flambda/*.cmi \
	    "$(INSTALL_COMPLIBDIR)"
	$(INSTALL_DATA) \
	    middle_end/flambda/base_types/*.cmi \
	    "$(INSTALL_COMPLIBDIR)"
	$(INSTALL_DATA) \
	    asmcomp/*.cmi \
	    "$(INSTALL_COMPLIBDIR)"
	$(INSTALL_DATA) \
	    asmcomp/debug/*.cmi \
	    "$(INSTALL_COMPLIBDIR)"
ifeq "$(INSTALL_SOURCE_ARTIFACTS)" "true"
	$(INSTALL_DATA) \
	    middle_end/*.cmt middle_end/*.cmti \
	    middle_end/*.mli \
	    "$(INSTALL_COMPLIBDIR)"
	$(INSTALL_DATA) \
	    middle_end/closure/*.cmt middle_end/closure/*.cmti \
	    middle_end/closure/*.mli \
	    "$(INSTALL_COMPLIBDIR)"
	$(INSTALL_DATA) \
	    middle_end/flambda/*.cmt middle_end/flambda/*.cmti \
	    middle_end/flambda/*.mli \
	    "$(INSTALL_COMPLIBDIR)"
	$(INSTALL_DATA) \
	    middle_end/flambda/base_types/*.cmt \
            middle_end/flambda/base_types/*.cmti \
	    middle_end/flambda/base_types/*.mli \
	    "$(INSTALL_COMPLIBDIR)"
	$(INSTALL_DATA) \
	    asmcomp/*.cmt asmcomp/*.cmti \
	    asmcomp/*.mli \
	    "$(INSTALL_COMPLIBDIR)"
	$(INSTALL_DATA) \
	    asmcomp/debug/*.cmt asmcomp/debug/*.cmti \
	    asmcomp/debug/*.mli \
	    "$(INSTALL_COMPLIBDIR)"
endif
	$(INSTALL_DATA) \
	    $(OPTSTART) \
	    "$(INSTALL_COMPLIBDIR)"
ifneq "$(WITH_OCAMLDOC)" ""
	$(MAKE) -C ocamldoc installopt
endif
	for i in $(OTHERLIBRARIES); do \
	  $(MAKE) -C otherlibs/$$i installopt || exit $$?; \
	done
ifeq "$(INSTALL_BYTECODE_PROGRAMS)" "true"
	if test -f ocamlopt.opt ; then $(MAKE) installoptopt; else \
	   cd "$(INSTALL_BINDIR)"; \
	   $(LN) ocamlc.byte$(EXE) ocamlc$(EXE); \
	   $(LN) ocamlopt.byte$(EXE) ocamlopt$(EXE); \
	   $(LN) ocamllex.byte$(EXE) ocamllex$(EXE); \
	   (test -f flexlink.byte$(EXE) && \
	     $(LN) flexlink.byte$(EXE) flexlink$(EXE)) || true; \
	fi
else
	if test -f ocamlopt.opt ; then $(MAKE) installoptopt; fi
endif
	$(MAKE) -C tools installopt

.PHONY: installoptopt
installoptopt:
	$(INSTALL_PROG) ocamlc.opt "$(INSTALL_BINDIR)/ocamlc.opt$(EXE)"
	$(INSTALL_PROG) ocamlopt.opt "$(INSTALL_BINDIR)/ocamlopt.opt$(EXE)"
	$(INSTALL_PROG) \
	  lex/ocamllex.opt "$(INSTALL_BINDIR)/ocamllex.opt$(EXE)"
	cd "$(INSTALL_BINDIR)"; \
	   $(LN) ocamlc.opt$(EXE) ocamlc$(EXE); \
	   $(LN) ocamlopt.opt$(EXE) ocamlopt$(EXE); \
	   $(LN) ocamllex.opt$(EXE) ocamllex$(EXE)
ifeq "$(BOOTSTRAPPING_FLEXDLL)" "true"
	$(INSTALL_PROG) flexlink.opt$(EXE) "$(INSTALL_BINDIR)"
	cd "$(INSTALL_BINDIR)"; \
	  $(LN) flexlink.opt$(EXE) flexlink$(EXE)
endif
	$(INSTALL_DATA) \
	   utils/*.cmx parsing/*.cmx typing/*.cmx bytecomp/*.cmx \
	   file_formats/*.cmx \
	   lambda/*.cmx \
	   driver/*.cmx asmcomp/*.cmx middle_end/*.cmx \
           middle_end/closure/*.cmx \
           middle_end/flambda/*.cmx \
           middle_end/flambda/base_types/*.cmx \
	   asmcomp/debug/*.cmx \
          "$(INSTALL_COMPLIBDIR)"
	$(INSTALL_DATA) \
	   compilerlibs/*.cmxa compilerlibs/*.$(A) \
	   "$(INSTALL_COMPLIBDIR)"
	$(INSTALL_DATA) \
	   $(BYTESTART:.cmo=.cmx) $(BYTESTART:.cmo=.$(O)) \
	   $(OPTSTART:.cmo=.cmx) $(OPTSTART:.cmo=.$(O)) \
	   "$(INSTALL_COMPLIBDIR)"
	if test -f ocamlnat$(EXE) ; then \
	  $(INSTALL_PROG) \
	    ocamlnat$(EXE) "$(INSTALL_BINDIR)/ocamlnat$(EXE)"; \
	  $(INSTALL_DATA) \
	     toplevel/opttopdirs.cmi \
	     "$(INSTALL_LIBDIR)"; \
	  $(INSTALL_DATA) \
	     $(OPTTOPLEVELSTART:.cmo=.cmx) $(OPTTOPLEVELSTART:.cmo=.$(O)) \
	     "$(INSTALL_COMPLIBDIR)"; \
	fi
	cd "$(INSTALL_COMPLIBDIR)" && \
	   $(RANLIB) ocamlcommon.$(A) ocamlbytecomp.$(A) ocamloptcomp.$(A)

# Installation of the *.ml sources of compiler-libs
.PHONY: install-compiler-sources
install-compiler-sources:
ifeq "$(INSTALL_SOURCE_ARTIFACTS)" "true"
	$(INSTALL_DATA) \
	   utils/*.ml parsing/*.ml typing/*.ml bytecomp/*.ml driver/*.ml \
           file_formats/*.ml \
           lambda/*.ml \
	   toplevel/*.ml middle_end/*.ml middle_end/closure/*.ml \
     middle_end/flambda/*.ml middle_end/flambda/base_types/*.ml \
	   asmcomp/*.ml \
	   asmcmp/debug/*.ml \
	   "$(INSTALL_COMPLIBDIR)"
endif

# Run all tests

.PHONY: tests
tests:
	$(MAKE) -C testsuite all

# Make clean in the test suite

.PHONY: clean
clean::
	$(MAKE) -C testsuite clean

# Build the manual latex files from the etex source files
# (see manual/README.md)
.PHONY: manual-pregen
manual-pregen: opt.opt
	cd manual; $(MAKE) clean && $(MAKE) pregen-etex

# The clean target
clean:: partialclean

# The bytecode compiler

ocamlc: compilerlibs/ocamlcommon.cma compilerlibs/ocamlbytecomp.cma $(BYTESTART)
	$(CAMLC) $(LINKFLAGS) -compat-32 -o $@ $^

partialclean::
	rm -rf ocamlc

# The native-code compiler

ocamlopt: compilerlibs/ocamlcommon.cma compilerlibs/ocamloptcomp.cma \
          $(OPTSTART)
	$(CAMLC) $(LINKFLAGS) -o $@ $^

partialclean::
	rm -f ocamlopt

# The toplevel

ocaml_dependencies := \
  compilerlibs/ocamlcommon.cma \
  compilerlibs/ocamlbytecomp.cma \
  compilerlibs/ocamltoplevel.cma $(TOPLEVELSTART)

.INTERMEDIATE: ocaml.tmp
ocaml.tmp: $(ocaml_dependencies)
	$(CAMLC) $(LINKFLAGS) -linkall -o $@ $^

ocaml: expunge ocaml.tmp
	- $(CAMLRUN) $^ $@ $(PERVASIVES)

partialclean::
	rm -f ocaml

.PHONY: runtop
runtop:
	$(MAKE) coldstart
	$(MAKE) ocamlc
	$(MAKE) otherlibraries
	$(MAKE) ocaml
	@rlwrap --help 2>/dev/null && $(EXTRAPATH) rlwrap $(RUNTOP) ||\
	  $(EXTRAPATH) $(RUNTOP)

.PHONY: natruntop
natruntop:
	$(MAKE) core
	$(MAKE) opt
	$(MAKE) ocamlnat
	@rlwrap --help 2>/dev/null && $(EXTRAPATH) rlwrap $(NATRUNTOP) ||\
	  $(EXTRAPATH) $(NATRUNTOP)

# Native dynlink

otherlibs/dynlink/dynlink.cmxa: otherlibs/dynlink/native/dynlink.ml
	$(MAKE) -C otherlibs/dynlink allopt

# The lexer

parsing/lexer.ml: parsing/lexer.mll
	$(CAMLLEX) $(OCAMLLEX_FLAGS) $<

partialclean::
	rm -f parsing/lexer.ml

beforedepend:: parsing/lexer.ml

# The bytecode compiler compiled with the native-code compiler

ocamlc.opt: compilerlibs/ocamlcommon.cmxa compilerlibs/ocamlbytecomp.cmxa \
            $(BYTESTART:.cmo=.cmx)
	$(CAMLOPT_CMD) $(LINKFLAGS) -o $@ $^ -cclib "$(BYTECCLIBS)"

partialclean::
	rm -f ocamlc.opt

# The native-code compiler compiled with itself

ocamlopt.opt: compilerlibs/ocamlcommon.cmxa compilerlibs/ocamloptcomp.cmxa \
              $(OPTSTART:.cmo=.cmx)
	$(CAMLOPT_CMD) $(LINKFLAGS) -o $@ $^

partialclean::
	rm -f ocamlopt.opt

# The predefined exceptions and primitives

runtime/primitives:
	$(MAKE) -C runtime primitives

lambda/runtimedef.ml: lambda/generate_runtimedef.sh runtime/caml/fail.h \
    runtime/primitives
	$^ > $@

partialclean::
	rm -f lambda/runtimedef.ml

beforedepend:: lambda/runtimedef.ml

# Choose the right machine-dependent files

asmcomp/arch.ml: asmcomp/$(ARCH)/arch.ml
	cd asmcomp; $(LN) $(ARCH)/arch.ml .

asmcomp/proc.ml: asmcomp/$(ARCH)/proc.ml
	cd asmcomp; $(LN) $(ARCH)/proc.ml .

asmcomp/selection.ml: asmcomp/$(ARCH)/selection.ml
	cd asmcomp; $(LN) $(ARCH)/selection.ml .

asmcomp/CSE.ml: asmcomp/$(ARCH)/CSE.ml
	cd asmcomp; $(LN) $(ARCH)/CSE.ml .

asmcomp/reload.ml: asmcomp/$(ARCH)/reload.ml
	cd asmcomp; $(LN) $(ARCH)/reload.ml .

asmcomp/scheduling.ml: asmcomp/$(ARCH)/scheduling.ml
	cd asmcomp; $(LN) $(ARCH)/scheduling.ml .

# Preprocess the code emitters

asmcomp/emit.ml: asmcomp/$(ARCH)/emit.mlp tools/cvt_emit
	echo \# 1 \"$(ARCH)/emit.mlp\" > $@
	$(CAMLRUN) tools/cvt_emit < $< >> $@ \
	|| { rm -f $@; exit 2; }

partialclean::
	rm -f asmcomp/emit.ml

beforedepend:: asmcomp/emit.ml

tools/cvt_emit: tools/cvt_emit.mll
	$(MAKE) -C tools cvt_emit

# The "expunge" utility

expunge: compilerlibs/ocamlcommon.cma compilerlibs/ocamlbytecomp.cma \
         toplevel/expunge.cmo
	$(CAMLC) $(LINKFLAGS) -o $@ $^

partialclean::
	rm -f expunge

# The runtime system for the bytecode compiler

.PHONY: runtime
runtime: stdlib/libcamlrun.$(A)

ifeq "$(BOOTSTRAPPING_FLEXDLL)" "true"
runtime: $(addprefix stdlib/flexdll/, $(FLEXDLL_OBJECTS))
stdlib/flexdll/flexdll%.$(O): $(FLEXDLL_SOURCES)/flexdll%.$(O) | stdlib/flexdll
	cp $< $@
stdlib/flexdll:
	$(MKDIR) $@
endif

.PHONY: makeruntime
makeruntime:
	$(MAKE) -C runtime $(BOOT_FLEXLINK_CMD) all
runtime/libcamlrun.$(A): makeruntime ;
stdlib/libcamlrun.$(A): runtime/libcamlrun.$(A)
	cd stdlib; $(LN) ../runtime/libcamlrun.$(A) .
clean::
	$(MAKE) -C runtime clean
	rm -f stdlib/libcamlrun.a stdlib/libcamlrun.lib

otherlibs_all := bigarray dynlink raw_spacetime_lib \
  str systhreads unix win32unix
subdirs := debugger lex ocamldoc ocamltest runtime stdlib tools \
  $(addprefix otherlibs/, $(otherlibs_all)) \

.PHONY: alldepend
ifeq "$(TOOLCHAIN)" "msvc"
alldepend:
	$(error Dependencies cannot be regenerated using the MSVC ports)
else
alldepend: depend
	for dir in $(subdirs); do \
	  $(MAKE) -C $$dir depend || exit; \
	done
endif

# The runtime system for the native-code compiler

.PHONY: runtimeopt
runtimeopt: stdlib/libasmrun.$(A)

.PHONY: makeruntimeopt
makeruntimeopt:
	$(MAKE) -C runtime $(BOOT_FLEXLINK_CMD) allopt
runtime/libasmrun.$(A): makeruntimeopt ;
stdlib/libasmrun.$(A): runtime/libasmrun.$(A)
	cp $< $@
clean::
	rm -f stdlib/libasmrun.a stdlib/libasmrun.lib

# The standard library

.PHONY: library
library: ocamlc
	$(MAKE) -C stdlib $(BOOT_FLEXLINK_CMD) all

.PHONY: library-cross
library-cross:
	$(MAKE) -C stdlib $(BOOT_FLEXLINK_CMD) CAMLRUN=../runtime/ocamlrun all

.PHONY: libraryopt
libraryopt:
	$(MAKE) -C stdlib $(BOOT_FLEXLINK_CMD) allopt

partialclean::
	$(MAKE) -C stdlib clean

# The lexer and parser generators

.PHONY: ocamllex
ocamllex: ocamlyacc
	$(MAKE) -C lex all

.PHONY: ocamllex.opt
ocamllex.opt: ocamlopt
	$(MAKE) -C lex allopt

partialclean::
	$(MAKE) -C lex clean

.PHONY: ocamlyacc
ocamlyacc:
	$(MAKE) -C yacc $(BOOT_FLEXLINK_CMD) all

clean::
	$(MAKE) -C yacc clean

# The Menhir-generated parser

# In order to avoid a build-time dependency on Menhir,
# we store the result of the parser generator (which
# are OCaml source files) and Menhir's runtime libraries
# (that the parser files rely on) in boot/.

# The rules below do not depend on Menhir being available,
# they just build the parser from boot/.

# See Makefile.menhir for the rules to rebuild the parser and update
# boot/, which require Menhir. The targets in Makefile.menhir
# (also included here for convenience) must be used after any
# modification of parser.mly.
include Makefile.menhir

# To avoid module-name conflicts with compiler-lib users that link
# with their code with their own MenhirLib module (possibly with
# a different Menhir version), we rename MenhirLib into
# CamlinternalMenhirlib -- and replace the module occurrences in the
# generated parser.ml.

parsing/camlinternalMenhirLib.ml: boot/menhir/menhirLib.ml
	cp $< $@
parsing/camlinternalMenhirLib.mli: boot/menhir/menhirLib.mli
	echo '[@@@ocaml.warning "-67"]' > $@
	cat $< >> $@

# Copy parsing/parser.ml from boot/

parsing/parser.ml: boot/menhir/parser.ml parsing/parser.mly \
  tools/check-parser-uptodate-or-warn.sh
	@-tools/check-parser-uptodate-or-warn.sh
	sed "s/MenhirLib/CamlinternalMenhirLib/g" $< > $@
parsing/parser.mli: boot/menhir/parser.mli
	sed "s/MenhirLib/CamlinternalMenhirLib/g" $< > $@

beforedepend:: parsing/camlinternalMenhirLib.ml \
  parsing/camlinternalMenhirLib.mli \
	parsing/parser.ml parsing/parser.mli

partialclean:: partialclean-menhir


# OCamldoc

.PHONY: ocamldoc
ocamldoc: ocamlc ocamlyacc ocamllex otherlibraries
	$(MAKE) -C ocamldoc all

.PHONY: ocamldoc.opt
ocamldoc.opt: ocamlc.opt ocamlyacc ocamllex
	$(MAKE) -C ocamldoc opt.opt

# OCamltest
ocamltest: ocamlc ocamlyacc ocamllex
	$(MAKE) -C ocamltest all

ocamltest.opt: ocamlc.opt ocamlyacc ocamllex
	$(MAKE) -C ocamltest allopt

partialclean::
	$(MAKE) -C ocamltest clean

# Documentation

.PHONY: html_doc
html_doc: ocamldoc
	$(MAKE) -C ocamldoc $@
	@echo "documentation is in ./ocamldoc/stdlib_html/"

.PHONY: manpages
manpages:
	$(MAKE) -C ocamldoc $@

partialclean::
	$(MAKE) -C ocamldoc clean

# The extra libraries

.PHONY: otherlibraries
otherlibraries: ocamltools
	$(MAKE) -C otherlibs all

.PHONY: otherlibrariesopt
otherlibrariesopt:
	$(MAKE) -C otherlibs allopt

partialclean::
	$(MAKE) -C otherlibs partialclean

clean::
	$(MAKE) -C otherlibs clean

# The replay debugger

.PHONY: ocamldebugger
ocamldebugger: ocamlc ocamlyacc ocamllex otherlibraries
	$(MAKE) -C debugger all

partialclean::
	$(MAKE) -C debugger clean

# Check that the native-code compiler is supported
.PHONY: checknative
checknative:
ifeq "$(ARCH)" "none"
checknative:
	$(error The native-code compiler is not supported on this platform)
else
	@
endif

# Check that the stack limit is reasonable (Unix-only)
.PHONY: checkstack
ifeq "$(UNIX_OR_WIN32)" "unix"
checkstack: tools/checkstack$(EXE)
	$<

.INTERMEDIATE: tools/checkstack$(EXE) tools/checkstack.$(O)
tools/checkstack$(EXE): tools/checkstack.$(O)
	$(MAKE) -C tools $(BOOT_FLEXLINK_CMD) checkstack$(EXE)
else
checkstack:
	@
endif

# Lint @since and @deprecated annotations

VERSIONS=$(shell git tag|grep '^[0-9]*.[0-9]*.[0-9]*$$'|grep -v '^[12].')
.PHONY: lintapidiff
lintapidiff:
	$(MAKE) -C tools lintapidiff.opt
	git ls-files -- 'otherlibs/*/*.mli' 'stdlib/*.mli' |\
	    grep -Ev internal\|obj\|spacetime\|stdLabels\|moreLabels |\
	    tools/lintapidiff.opt $(VERSIONS)

# Tools

.PHONY: ocamltools
ocamltools: ocamlc ocamllex compilerlibs/ocamlmiddleend.cma
	$(MAKE) -C tools all

.PHONY: ocamltoolsopt
ocamltoolsopt: ocamlopt
	$(MAKE) -C tools opt

.PHONY: ocamltoolsopt.opt
ocamltoolsopt.opt: ocamlc.opt ocamllex.opt compilerlibs/ocamlmiddleend.cmxa
	$(MAKE) -C tools opt.opt

partialclean::
	$(MAKE) -C tools clean

## Test compilation of backend-specific parts

partialclean::
	rm -f $(ARCH_SPECIFIC)

beforedepend:: $(ARCH_SPECIFIC)

# This rule provides a quick way to check that machine-dependent
# files compiles fine for a foreign architecture (passed as ARCH=xxx).

.PHONY: check_arch
check_arch:
	@echo "========= CHECKING asmcomp/$(ARCH) =============="
	@rm -f $(ARCH_SPECIFIC) asmcomp/emit.ml asmcomp/*.cm*
	@$(MAKE) compilerlibs/ocamloptcomp.cma \
	            >/dev/null
	@rm -f $(ARCH_SPECIFIC) asmcomp/emit.ml asmcomp/*.cm*

.PHONY: check_all_arches
check_all_arches:
ifeq ($(ARCH64),true)
	@STATUS=0; \
	 for i in $(ARCHES); do \
	   $(MAKE) --no-print-directory check_arch ARCH=$$i || STATUS=1; \
	 done; \
	 exit $$STATUS
else
	 @echo "Architecture tests are disabled on 32-bit platforms."
endif

# The native toplevel

# When the native toplevel executable has an extension (e.g. ".exe"),
# provide a phony 'ocamlnat' synonym

ifneq ($(EXE),)
.PHONY: ocamlnat
ocamlnat: ocamlnat$(EXE)
endif

ocamlnat$(EXE): compilerlibs/ocamlcommon.cmxa compilerlibs/ocamloptcomp.cmxa \
    compilerlibs/ocamlbytecomp.cmxa \
    otherlibs/dynlink/dynlink.cmxa \
    compilerlibs/ocamlopttoplevel.cmxa \
    $(OPTTOPLEVELSTART:.cmo=.cmx)
	$(CAMLOPT_CMD) $(LINKFLAGS) -linkall -o $@ $^

partialclean::
	rm -f ocamlnat ocamlnat.exe

toplevel/opttoploop.cmx: otherlibs/dynlink/dynlink.cmxa

# The numeric opcodes

bytecomp/opcodes.ml: runtime/caml/instruct.h tools/make_opcodes
	runtime/ocamlrun tools/make_opcodes -opcodes < $< > $@

bytecomp/opcodes.mli: bytecomp/opcodes.ml
	$(CAMLC) -i $< > $@

tools/make_opcodes: tools/make_opcodes.mll
	$(MAKE) -C tools make_opcodes

partialclean::
	rm -f bytecomp/opcodes.ml
	rm -f bytecomp/opcodes.mli

beforedepend:: bytecomp/opcodes.ml bytecomp/opcodes.mli

ifneq "$(wildcard .git)" ""
include Makefile.dev
endif

# Default rules

.SUFFIXES: .ml .mli .cmo .cmi .cmx

.ml.cmo:
	$(CAMLC) $(COMPFLAGS) -c $<

.mli.cmi:
	$(CAMLC) $(COMPFLAGS) -c $<

.ml.cmx:
	$(CAMLOPT) $(COMPFLAGS) $(OPTCOMPFLAGS) -c $<

partialclean::
	for d in utils parsing typing bytecomp asmcomp middle_end file_formats \
           lambda middle_end/closure middle_end/flambda \
           middle_end/flambda/base_types asmcomp/debug \
           driver toplevel tools; do \
	  rm -f $$d/*.cm[ioxt] $$d/*.cmti $$d/*.annot $$d/*.s $$d/*.asm \
	    $$d/*.o $$d/*.obj $$d/*.so $$d/*.dll; \
	done

.PHONY: depend
depend: beforedepend
	(for d in utils parsing typing bytecomp asmcomp middle_end \
         lambda file_formats middle_end/closure middle_end/flambda \
         middle_end/flambda/base_types asmcomp/debug \
         driver toplevel; \
         do $(CAMLDEP) $(DEPFLAGS) $(DEPINCLUDES) $$d/*.mli $$d/*.ml || exit; \
         done) > .depend

.PHONY: distclean
distclean: clean
	rm -f boot/ocamlrun boot/ocamlrun boot/ocamlrun.exe boot/camlheader \
	boot/ocamlruns boot/ocamlruns.exe \
	boot/flexlink.byte boot/flexlink.byte.exe \
	boot/flexdll_*.o boot/flexdll_*.obj \
	boot/*.cm* boot/libcamlrun.a boot/libcamlrun.lib boot/ocamlc.opt
	rm -f Makefile.config Makefile.common runtime/caml/m.h runtime/caml/s.h
	rm -rf autom4te.cache flexdll-sources
	rm -f config.log config.status libtool
	rm -f tools/eventlog_metadata
	rm -f tools/*.bak
	rm -f ocaml ocamlc
	rm -f testsuite/_log*

include .depend


ifneq "$(strip $(CAN_BE_UNCONFIGURED))" ""
Makefile.config Makefile.common: config.status

config.status:
	@echo "Please refer to the installation instructions:"
	@echo "- In file INSTALL for Unix systems."
	@echo "- In file README.win32.adoc for Windows systems."
	@echo "On Unix systems, if you've just unpacked the distribution,"
	@echo "something like"
	@echo "	./configure"
	@echo "	make"
	@echo "	make install"
	@echo "should work."
	@false
endif
