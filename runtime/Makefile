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

# Lists of source files

BYTECODE_C_SOURCES := $(addsuffix .c, \
  interp misc stacks fix_code startup_aux startup_byt freelist major_gc \
  minor_gc memory alloc roots_byt globroots fail_byt signals \
  signals_byt printexc backtrace_byt backtrace compare ints \
  floats str array io extern intern hash sys meta parsing gc_ctrl md5 obj \
  lexing callback debugger weak compact finalise custom dynlink \
  spacetime_byt afl $(UNIX_OR_WIN32) bigarray main memprof domain)

NATIVE_C_SOURCES := $(addsuffix .c, \
  startup_aux startup_nat main fail_nat roots_nat signals \
  signals_nat misc freelist major_gc minor_gc memory alloc compare ints \
  floats str array io extern intern hash sys parsing gc_ctrl md5 obj \
  lexing $(UNIX_OR_WIN32) printexc callback weak compact finalise custom \
  globroots backtrace_nat backtrace dynlink_nat debugger meta \
  dynlink clambda_checks spacetime_nat spacetime_snapshot afl bigarray \
  memprof domain)

# The other_files variable stores the list of files whose dependencies
# should be computed by `make depend` although they do not need to be
# compiled on the current build system
ifeq "$(UNIX_OR_WIN32)" "win32"
other_files := unix.c
else
other_files := win32.c
endif

# Targets to build and install

PROGRAMS := target/ocamlrun$(EXE)
BYTECODE_STATIC_LIBRARIES := ld.conf target/libcamlrun.$(A)
BYTECODE_SHARED_LIBRARIES :=
NATIVE_STATIC_LIBRARIES := target/libasmrun.$(A)
NATIVE_SHARED_LIBRARIES :=

ifeq "$(RUNTIMED)" "true"
PROGRAMS += target/ocamlrund$(EXE)
BYTECODE_STATIC_LIBRARIES += target/libcamlrund.$(A)
NATIVE_STATIC_LIBRARIES += target/libasmrund.$(A)
endif

ifeq "$(RUNTIMEI)" "true"
PROGRAMS += target/ocamlruni$(EXE)
BYTECODE_STATIC_LIBRARIES += target/libcamlruni.$(A)
NATIVE_STATIC_LIBRARIES += target/libasmruni.$(A)
endif

ifeq "$(UNIX_OR_WIN32)" "unix"
ifeq "$(SUPPORTS_SHARED_LIBRARIES)" "true"
BYTECODE_STATIC_LIBRARIES += target/libcamlrun_pic.$(A)
BYTECODE_SHARED_LIBRARIES += target/libcamlrun_shared.$(SO)
NATIVE_STATIC_LIBRARIES += target/libasmrun_pic.$(A)
NATIVE_SHARED_LIBRARIES += target/libasmrun_shared.$(SO)
endif
endif

ifeq "$(CROSS_COMPILING)" "true"
PROGRAMS += build/ocamlrun$(build_EXE)
endif
ifeq "$(CROSS_COMPILER)" "true"
PROGRAMS += host/ocamlrun$(host_EXE)
NATIVE_STATIC_LIBRARIES += host/libasmrun.$(host_A)
endif

# Build, install and clean targets

.PHONY: all
all: $(BYTECODE_STATIC_LIBRARIES) $(BYTECODE_SHARED_LIBRARIES) $(PROGRAMS)

.PHONY: allopt
allopt: $(NATIVE_STATIC_LIBRARIES) $(NATIVE_SHARED_LIBRARIES)

# XXX COMBAK This is where we introduce all the other stuff if we're cross-compiling/building a cross-compiler

ifeq "$(CROSS_COMPILING)" "true"
include build/Makefile
endif
ifeq "$(CROSS_COMPILER)" "true"
include host/Makefile
endif
include target/Makefile

# XXX COMBAK
INSTALL_INCDIR=$(INSTALL_LIBDIR)/caml
.PHONY: install
install:
	$(INSTALL_PROG) $(PROGRAMS) "$(INSTALL_BINDIR)"
	$(INSTALL_DATA) $(BYTECODE_STATIC_LIBRARIES) "$(INSTALL_LIBDIR)"
ifneq "$(BYTECODE_SHARED_LIBRARIES)" ""
	$(INSTALL_PROG) $(BYTECODE_SHARED_LIBRARIES) "$(INSTALL_LIBDIR)"
endif
	mkdir -p "$(INSTALL_INCDIR)"
	$(INSTALL_DATA) caml/domain_state.tbl caml/*.h "$(INSTALL_INCDIR)"

.PHONY: installopt
installopt:
	$(INSTALL_DATA) $(NATIVE_STATIC_LIBRARIES) "$(INSTALL_LIBDIR)"
ifneq "$(NATIVE_SHARED_LIBRARIES)" ""
	$(INSTALL_PROG) $(NATIVE_SHARED_LIBRARIES) "$(INSTALL_LIBDIR)"
endif

.PHONY: clean
# XXX COMBAK The files aren't being cleaned in the right places
clean:
	rm -f $(PROGRAMS) build/*.$(O) build/*.$(A) build/*.$(SO) host/*.$(O) host/*.$(A) host/*.$(SO) target/*.$(O) target/*.$(A) target/*.$(SO) ld.conf
	rm -f primitives prims.c caml/opnames.h caml/jumptbl.h primitives.new
	rm -f caml/version.h domain_state*.inc

.PHONY: distclean
distclean: clean

libcamlrund_OBJECTS := $(BYTECODE_C_SOURCES:.c=_bd.$(O)) \
  instrtrace_bd.$(O)

libcamlruni_OBJECTS := $(BYTECODE_C_SOURCES:.c=_bi.$(O))

libcamlrunpic_OBJECTS := $(BYTECODE_C_SOURCES:.c=_bpic.$(O))

libasmrund_OBJECTS := $(NATIVE_C_SOURCES:.c=_nd.$(O)) $(ASM_OBJECTS)

libasmruni_OBJECTS := $(NATIVE_C_SOURCES:.c=_ni.$(O)) $(ASM_OBJECTS)

libasmrunpic_OBJECTS := $(NATIVE_C_SOURCES:.c=_npic.$(O)) \
  $(ASM_OBJECTS:.$(O)=_libasmrunpic.$(O))

target/ocamlrund$(EXE): target/prims.$(O) target/libcamlrund.$(A)
	$(MKEXE) $(MKEXEDEBUGFLAG) -o $@ $^ $(target_LIBS)

target/libcamlrund.$(A): $(addprefix target/,$(libcamlrund_OBJECTS))
	$(call MKLIB,$@, $^)

target/ocamlruni$(EXE): target/prims.$(O) target/libcamlruni.$(A)
	$(MKEXE) -o $@ $^ $(target_LIBS)

target/libcamlruni.$(A): $(addprefix target/,$(libcamlruni_OBJECTS))
	$(call MKLIB,$@, $^)

target/libcamlrun_pic.$(A): $(addprefix target/,$(libcamlrunpic_OBJECTS))
	$(call MKLIB,$@, $^)

target/libcamlrun_shared.$(SO): $(addprefix target/,$(libcamlrunpic_OBJECTS))
	$(MKDLL) -o $@ $^ $(BYTECCLIBS)

target/libasmrund.$(A): $(addprefix target/,$(libasmrund_OBJECTS))
	$(call MKLIB,$@, $^)

target/libasmruni.$(A): $(addprefix target/,$(libasmruni_OBJECTS))
	$(call MKLIB,$@, $^)

target/libasmrun_pic.$(A): $(addprefix target/,$(libasmrunpic_OBJECTS))
	$(call MKLIB,$@, $^)

target/libasmrun_shared.$(SO): $(addprefix target/,$(libasmrunpic_OBJECTS))
	$(MKDLL) -o $@ $^ $(NATIVECCLIBS)

# Generated non-object files

ld.conf: $(ROOTDIR)/Makefile.config
	echo "$(STUBLIBDIR)" > $@
	echo "$(LIBDIR)" >> $@

# If primitives contain duplicated lines (e.g. because the code is defined
# like
# #ifdef X
# CAMLprim value caml_foo() ...
# #else
# CAMLprim value caml_foo() ...
# end), horrible things will happen (duplicated entries in Runtimedef ->
# double registration in Symtable -> empty entry in the PRIM table ->
# the bytecode interpreter is confused).
# We sort the primitive file and remove duplicates to avoid this problem.

# Warning: we use "sort | uniq" instead of "sort -u" because in the MSVC
# port, the "sort" program in the path is Microsoft's and not cygwin's

# Warning: POSIX sort is locale dependent, that's why we set LC_ALL explicitly.
# Sort is unstable for "is_directory" and "isatty"
# see http://pubs.opengroup.org/onlinepubs/9699919799/utilities/sort.html:
# "using sort to process pathnames, it is recommended that LC_ALL .. set to C"

# To speed up builds, we avoid changing "primitives" when files
# containing primitives change but the primitives table does not
primitives: $(shell ./gen_primitives.sh > primitives.new; \
                    cmp -s primitives primitives.new || echo primitives.new)
	cp $^ $@

prims.c : primitives
	(echo '#define CAML_INTERNALS'; \
         echo '#include "caml/mlvalues.h"'; \
	 echo '#include "caml/prims.h"'; \
	 sed -e 's/.*/extern value &();/' primitives; \
	 echo 'c_primitive caml_builtin_cprim[] = {'; \
	 sed -e 's/.*/	&,/' primitives; \
	 echo '	 0 };'; \
	 echo 'char * caml_names_of_builtin_cprim[] = {'; \
	 sed -e 's/.*/	"&",/' primitives; \
	 echo '	 0 };') > prims.c

caml/opnames.h : caml/instruct.h
	cat $^ | tr -d '\r' | \
	sed -e '/\/\*/d' \
	    -e '/^#/d' \
	    -e 's/enum /static char * names_of_/' \
	    -e 's/{$$/[] = {/' \
	    -e 's/\([[:upper:]][[:upper:]_0-9]*\)/"\1"/g' > $@

# caml/jumptbl.h is required only if you have GCC 2.0 or later
caml/jumptbl.h : caml/instruct.h
	cat $^ | tr -d '\r' | \
	sed -n -e '/^  /s/ \([A-Z]\)/ \&\&lbl_\1/gp' \
	       -e '/^}/q' > $@

caml/version.h : $(ROOTDIR)/tools/make-version-header.sh $(ROOTDIR)/VERSION
	$^ > $@

domain_state64.inc: caml/domain_state.tbl gen_domain_state64_inc.awk
	awk -f gen_domain_state64_inc.awk $< > $@

domain_state32.inc: caml/domain_state.tbl gen_domain_state32_inc.awk
	awk -f gen_domain_state32_inc.awk $< > $@

# Target-specific preprocessor and compiler flags

target/%_bd.$(O): target_OC_CPPFLAGS += $(OC_DEBUG_CPPFLAGS)

target/%_bi.$(O): target_OC_CPPFLAGS += $(OC_INSTR_CPPFLAGS)

target/%_bpic.$(O): target_OC_CFLAGS += $(SHAREDLIB_CFLAGS)

target/%_nd.$(O): target_OC_CPPFLAGS += $(target_OC_NATIVE_CPPFLAGS) $(OC_DEBUG_CPPFLAGS)

target/%_ni.$(O): target_OC_CPPFLAGS += $(target_OC_NATIVE_CPPFLAGS) $(OC_INSTR_CPPFLAGS)

target/%_npic.$(O): target_OC_CFLAGS += $(SHAREDLIB_CFLAGS)
target/%_npic.$(O): target_OC_CPPFLAGS += $(target_OC_NATIVE_CPPFLAGS)

# Dependencies

.PHONY: depend
ifeq "$(TOOLCHAIN)" "msvc"
depend:
	$(error Dependencies cannot be regenerated using the MSVC ports)
else

NATIVE_DEP_CPPFLAGS := $(OC_CPPFLAGS) $(OC_NATIVE_CPPFLAGS)
BYTECODE_DEP_FILES := $(BYTECODE_C_SOURCES) $(other_files) instrtrace.c
NATIVE_DEP_FILES := $(NATIVE_C_SOURCES) $(other_files)

depend: *.c caml/opnames.h caml/jumptbl.h caml/version.h
	$(CC) -MM $(OC_CPPFLAGS) $(BYTECODE_DEP_FILES) | \
	  sed -e 's/\([^.]*\)\.o/\1_b.$$(O)/' > .depend
	$(CC) -MM $(OC_CPPFLAGS) $(OC_DEBUG_CPPFLAGS) \
                  $(BYTECODE_DEP_FILES) | \
	  sed -e 's/\([^.]*\)\.o/\1_bd.$$(O)/' >> .depend
	$(CC) -MM $(OC_CPPFLAGS) $(OC_INSTR_CPPFLAGS) \
               $(BYTECODE_DEP_FILES) | \
	  sed -e 's/\([^.]*\)\.o/\1_bi.$$(O)/' >> .depend
	$(CC) -MM $(OC_CPPFLAGS) $(BYTECODE_DEP_FILES) | \
	  sed -e 's/\([^.]*\)\.o/\1_bpic.$$(O)/' >> .depend
	$(CC) -MM $(NATIVE_DEP_CPPFLAGS) $(NATIVE_DEP_FILES) | \
	  sed -e 's/\([^.]*\)\.o/\1_n.$$(O)/' >> .depend
	$(CC) -MM $(NATIVE_DEP_CPPFLAGS) $(OC_DEBUG_CPPFLAGS) \
                  $(NATIVE_DEP_FILES) | \
	  sed -e 's/\([^.]*\)\.o/\1_nd.$$(O)/' >> .depend
	$(CC) -MM $(NATIVE_DEP_CPPFLAGS) $(OC_INSTR_CPPFLAGS) \
                  $(NATIVE_DEP_FILES) | \
	  sed -e 's/\([^.]*\)\.o/\1_ni.$$(O)/' >> .depend
	$(CC) -MM $(NATIVE_DEP_CPPFLAGS) $(NATIVE_DEP_FILES) | \
	  sed -e 's/\([^.]*\)\.o/\1_npic.$$(O)/' >> .depend
endif

include .depend
