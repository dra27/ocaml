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

# Lists of source files

BYTECODE_C_SOURCES := $(addsuffix .c, \
  interp misc stacks fix_code startup_aux startup_byt freelist major_gc \
  minor_gc memory alloc roots_byt globroots fail_byt signals \
  signals_byt printexc backtrace_byt backtrace compare ints eventlog \
  floats str array io extern intern hash sys meta parsing gc_ctrl md5 obj \
  lexing callback debugger weak compact finalise custom dynlink \
  spacetime_byt afl $(UNIX_OR_WIN32) bigarray main memprof domain \
  skiplist codefrag)

NATIVE_C_SOURCES := $(addsuffix .c, \
  startup_aux startup_nat main fail_nat roots_nat signals \
  signals_nat misc freelist major_gc minor_gc memory alloc compare ints \
  floats str array io extern intern hash sys parsing gc_ctrl eventlog md5 obj \
  lexing $(UNIX_OR_WIN32) printexc callback weak compact finalise custom \
  globroots backtrace_nat backtrace dynlink_nat debugger meta \
  dynlink clambda_checks spacetime_nat spacetime_snapshot afl bigarray \
  memprof domain skiplist codefrag)

# The other_files variable stores the list of files whose dependencies
# should be computed by `make depend` although they do not need to be
# compiled on the current build system
ifeq "$(UNIX_OR_WIN32)" "win32"
other_files := unix.c
else
other_files := win32.c
endif

ifeq "$(TOOLCHAIN)" "msvc"
ASM_EXT := asm
ASM_SOURCES := $(ARCH)nt.$(ASM_EXT)
else
ASM_EXT := S
ASM_SOURCES := $(ARCH).$(ASM_EXT)
endif

# Targets to build and install

PROGRAMS := ocamlrun
BYTECODE_STATIC_LIBRARIES := libcamlrun.$(A)
BYTECODE_SHARED_LIBRARIES :=
NATIVE_STATIC_LIBRARIES := libasmrun.$(A)
NATIVE_SHARED_LIBRARIES :=

ifeq "$(RUNTIMED)" "true"
PROGRAMS += ocamlrund
BYTECODE_STATIC_LIBRARIES += libcamlrund.$(A)
NATIVE_STATIC_LIBRARIES += libasmrund.$(A)
endif

ifeq "$(RUNTIMEI)" "true"
PROGRAMS += ocamlruni
BYTECODE_STATIC_LIBRARIES += libcamlruni.$(A)
NATIVE_STATIC_LIBRARIES += libasmruni.$(A)
endif

ifeq "$(UNIX_OR_WIN32)" "unix"
ifeq "$(SUPPORTS_SHARED_LIBRARIES)" "true"
BYTECODE_STATIC_LIBRARIES += libcamlrun_pic.$(A)
BYTECODE_SHARED_LIBRARIES += camlrun
NATIVE_STATIC_LIBRARIES += libasmrun_pic.$(A)
NATIVE_SHARED_LIBRARIES += asmrun
endif
endif

# List of object files for each target

ASM_OBJECTS := $(ASM_SOURCES:.$(ASM_EXT)=.$(O))

libcamlrun_OBJECTS := $(BYTECODE_C_SOURCES:.c=_b.$(O))

libcamlrun_non_shared_OBJECTS := \
  $(subst $(UNIX_OR_WIN32)_b.$(O),$(UNIX_OR_WIN32)_non_shared_b.$(O), \
          $(libcamlrun_OBJECTS))

libcamlrund_OBJECTS := $(BYTECODE_C_SOURCES:.c=_bd.$(O)) \
  instrtrace_bd.$(O)

libcamlruni_OBJECTS := $(BYTECODE_C_SOURCES:.c=_bi.$(O))

libcamlrunpic_OBJECTS := $(BYTECODE_C_SOURCES:.c=_bpic.$(O))

libasmrun_OBJECTS := $(NATIVE_C_SOURCES:.c=_n.$(O)) $(ASM_OBJECTS)

libasmrund_OBJECTS := $(NATIVE_C_SOURCES:.c=_nd.$(O)) $(ASM_OBJECTS)

libasmruni_OBJECTS := $(NATIVE_C_SOURCES:.c=_ni.$(O)) $(ASM_OBJECTS)

libasmrunpic_OBJECTS := $(NATIVE_C_SOURCES:.c=_npic.$(O)) \
  $(ASM_OBJECTS:.$(O)=_libasmrunpic.$(O))

# General (non target-specific) assembler and compiler flags

ifneq "$(CCOMPTYPE)" "msvc"
OC_CFLAGS += -g
endif

OC_NATIVE_CPPFLAGS = -DNATIVE_CODE -DTARGET_$(ARCH)

ifeq "$(UNIX_OR_WIN32)" "unix"
OC_NATIVE_CPPFLAGS += -DMODEL_$(MODEL)
endif

OC_NATIVE_CPPFLAGS += -DSYS_$(SYSTEM) $(LIBUNWIND_INCLUDE_FLAGS)

OC_DEBUG_CPPFLAGS=-DDEBUG
OC_INSTR_CPPFLAGS=-DCAML_INSTR

ifeq "$(TOOLCHAIN)" "msvc"
ASMFLAGS=
ifeq ($(WITH_SPACETIME),true)
ASMFLAGS=/DWITH_SPACETIME
endif
endif

ASPPFLAGS = -DSYS_$(SYSTEM) -I$(ROOTDIR)/runtime
ifeq "$(UNIX_OR_WIN32)" "unix"
ASPPFLAGS += -DMODEL_$(MODEL)
endif

# Commands used to build native libraries

LIBS := $(BYTECCLIBS)

ifeq "$(UNIX_OR_WIN32)" "win32"
LIBS += $(EXTRALIBS)
endif

# Build, install and clean targets

.PHONY: all
all: $(BYTECODE_STATIC_LIBRARIES) \
     $(BYTECODE_SHARED_LIBRARIES:%=lib%_shared$(EXT_DLL)) \
     $(PROGRAMS:%=%$(EXE))

.PHONY: allopt
allopt: $(NATIVE_STATIC_LIBRARIES) \
        $(NATIVE_SHARED_LIBRARIES:%=lib%_shared$(EXT_DLL))

INSTALL_INCDIR=$(INSTALL_LIBDIR)/caml
.PHONY: install

ifeq "$(SUFFIXING)" "true"
MANGLE_RUNTIME_NAME = $(TARGET)-$(1)-$(BYTECODE_RUNTIME_ID)$(EXE)
MANGLE_RUNTIME_DLL_NAME = lib$(1)-$(TARGET)-$($(2)_RUNTIME_ID)$(EXT_DLL)
else
MANGLE_RUNTIME_NAME = $(1)$(EXE)
MANGLE_RUNTIME_DLL_NAME = lib$(1)_shared$(EXT_DLL)
endif

define INSTALL_RUNTIME
install::
	$(INSTALL_PROG) \
    $(1)$(EXE) "$(INSTALL_BINDIR)/$(call MANGLE_RUNTIME_NAME,$(1))"
ifeq "$(SUFFIXING)" "true"
	cd "$(INSTALL_BINDIR)" && \
    $(LN) "$(TARGET)-$(1)-$(BYTECODE_RUNTIME_ID)$(EXE)" "$(1)$(EXE)"
	cd "$(INSTALL_BINDIR)" && \
    $(LN) "$(TARGET)-$(1)-$(BYTECODE_RUNTIME_ID)$(EXE)" \
	    "$(1)-$(ZINC_RUNTIME_ID)$(EXE)"
endif
endef
define INSTALL_RUNTIME_LIB
ifeq "$(2)" "BYTECODE"
install::
else
installopt::
endif
	$(INSTALL_PROG) \
    lib$(1)_shared$(EXT_DLL) \
	    "$(INSTALL_LIBDIR)/$(call MANGLE_RUNTIME_DLL_NAME,$(1),$(2))"
ifeq "$(SUFFIXING)" "true"
	cd "$(INSTALL_LIBDIR)" && \
    $(LN) "$(call MANGLE_RUNTIME_DLL_NAME,$(1),$(2))" \
    "lib$(1)_shared$(EXT_DLL)"
endif
endef

$(foreach runtime, $(PROGRAMS), \
  $(eval $(call INSTALL_RUNTIME,$(runtime))))

install::
	$(INSTALL_DATA) ld.conf $(BYTECODE_STATIC_LIBRARIES) "$(INSTALL_LIBDIR)"

$(foreach shared_runtime, $(BYTECODE_SHARED_LIBRARIES), \
  $(eval $(call INSTALL_RUNTIME_LIB,$(shared_runtime),BYTECODE)))

install::
	mkdir -p "$(INSTALL_INCDIR)"
	$(INSTALL_DATA) caml/domain_state.tbl caml/*.h "$(INSTALL_INCDIR)"

.PHONY: installopt
installopt::
	$(INSTALL_DATA) $(NATIVE_STATIC_LIBRARIES) "$(INSTALL_LIBDIR)"

$(foreach shared_runtime, $(NATIVE_SHARED_LIBRARIES), \
  $(eval $(call INSTALL_RUNTIME_LIB,$(shared_runtime),NATIVE)))

.PHONY: clean
clean:
	rm -f *.o *.obj *.a *.lib *.so *.dll
	rm -f ocamlrun ocamlrund ocamlruni ocamlruns sak
	rm -f ocamlrun.exe ocamlrund.exe ocamlruni.exe ocamlruns.exe sak.exe
	rm -f primitives primitives.new prims.c caml/opnames.h caml/jumptbl.h
	rm -f caml/version.h domain_state*.inc build_config.h

.PHONY: distclean
distclean: clean
	rm -f ld.conf caml_internal_config.h

# Generated non-object files

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

ifeq "$(UNIX_OR_WIN32)" "unix"
  CHAR_OS = char
else
  CHAR_OS = wchar_t
endif

prims.c : primitives
	export LC_ALL=C; \
	(echo '#include "caml/config.h"'; \
	 echo '#include "build_config.h"'; \
	 echo 'typedef intnat value;'; \
	 echo 'typedef value (*c_primitive)(void);'; \
	 echo; \
	 sed -e 's/.*/extern value &(void);/' $<; \
	 echo; \
	 echo 'c_primitive caml_builtin_cprim[] = {'; \
	 sed -e 's/.*/  &,/' $<; \
	 echo '  0 };'; \
	 echo; \
	 echo 'char * caml_names_of_builtin_cprim[] = {'; \
	 sed -e 's/.*/  "&",/' $<; \
	 echo '  0 };'; \
	 echo; \
	 echo 'enum caml_byte_program_mode {STANDARD, APPENDED, EMBEDDED};'; \
   echo 'enum caml_byte_program_mode caml_byte_program_mode = STANDARD;'; \
	 echo "const $(CHAR_OS) *caml_runtime_standard_library_default = \
OCAML_STDLIB_DIR;") > $@

caml/opnames.h : caml/instruct.h
	tr -d '\r' < $< | \
	sed -e '/\/\*/d' \
	    -e '/^#/d' \
	    -e 's/enum /static char * names_of_/' \
	    -e 's/{$$/[] = {/' \
	    -e 's/\([[:upper:]][[:upper:]_0-9]*\)/"\1"/g' > $@

# caml/jumptbl.h is required only if you have GCC 2.0 or later
caml/jumptbl.h : caml/instruct.h
	tr -d '\r' < $< | \
	sed -n -e '/^  /s/ \([A-Z]\)/ \&\&lbl_\1/gp' \
	       -e '/^}/q' > $@

caml/version.h : $(ROOTDIR)/tools/make-version-header.sh $(ROOTDIR)/VERSION
	$^ > $@

sak$(EXE): sak.$(O)
	$(call MKEXE_BOOT,$@,$^)

C_LITERAL = $(shell ./sak$(EXE) encode-C-literal $(call QUOTE_SINGLE,$(1)))

build_config.h: $(ROOTDIR)/Makefile.config sak$(EXE)
	{ \
	  echo '/* This file is generated from $(ROOTDIR)/Makefile.config */'; \
	  printf '#define OCAML_STDLIB_DIR %s\n' \
	         $(call QUOTE_SINGLE,$(call C_LITERAL,$(TARGET_LIBDIR))); \
	  echo '#define HOST "$(HOST)"'; \
	  echo '#define BYTECODE_RUNTIME_ID "$(BYTECODE_RUNTIME_ID)"'; \
	} > $@

prims.$(O): build_config.h

# Libraries and programs

ocamlrun$(EXE): prims.$(O) libcamlrun.$(A)
	$(MKEXE) -o $@ $^ $(LIBS)

ocamlruns$(EXE): prims.$(O) libcamlrun_non_shared.$(A)
	$(call MKEXE_BOOT,$@,$^ $(LIBS))

libcamlrun.$(A): $(libcamlrun_OBJECTS)
	$(call MKLIB,$@, $^)

libcamlrun_non_shared.$(A): $(libcamlrun_non_shared_OBJECTS)
	$(call MKLIB,$@, $^)

ocamlrund$(EXE): prims.$(O) libcamlrund.$(A)
	$(MKEXE) $(MKEXEDEBUGFLAG) -o $@ $^ $(LIBS)

libcamlrund.$(A): $(libcamlrund_OBJECTS)
	$(call MKLIB,$@, $^)

ocamlruni$(EXE): prims.$(O) libcamlruni.$(A)
	$(MKEXE) -o $@ $^ $(LIBS)

libcamlruni.$(A): $(libcamlruni_OBJECTS)
	$(call MKLIB,$@, $^)

libcamlrun_pic.$(A): $(libcamlrunpic_OBJECTS)
	$(call MKLIB,$@, $^)

libcamlrun_shared.$(SO): $(libcamlrunpic_OBJECTS)
	$(MKDLL) -o $@ $^ $(BYTECCLIBS)

libasmrun.$(A): $(libasmrun_OBJECTS)
	$(call MKLIB,$@, $^)

libasmrund.$(A): $(libasmrund_OBJECTS)
	$(call MKLIB,$@, $^)

libasmruni.$(A): $(libasmruni_OBJECTS)
	$(call MKLIB,$@, $^)

libasmrun_pic.$(A): $(libasmrunpic_OBJECTS)
	$(call MKLIB,$@, $^)

libasmrun_shared.$(SO): $(libasmrunpic_OBJECTS)
	$(MKDLL) -o $@ $^ $(NATIVECCLIBS)

# Target-specific preprocessor and compiler flags

%_bd.$(O): OC_CPPFLAGS += $(OC_DEBUG_CPPFLAGS)

%_bi.$(O): OC_CPPFLAGS += $(OC_INSTR_CPPFLAGS)

%_bpic.$(O): OC_CFLAGS += $(SHAREDLIB_CFLAGS)

%_n.$(O): OC_CPPFLAGS += $(OC_NATIVE_CPPFLAGS)

%_nd.$(O): OC_CPPFLAGS += $(OC_NATIVE_CPPFLAGS) $(OC_DEBUG_CPPFLAGS)

%_ni.$(O): OC_CPPFLAGS += $(OC_NATIVE_CPPFLAGS) $(OC_INSTR_CPPFLAGS)

%_npic.$(O): OC_CFLAGS += $(SHAREDLIB_CFLAGS)
%_npic.$(O): OC_CPPFLAGS += $(OC_NATIVE_CPPFLAGS)

# Compilation of C files

# The COMPILE_C_FILE macro below receives as argument the pattern
# that corresponds to the name of the generated object file
# (without the extension, which is added by the macro)
define COMPILE_C_FILE
$(1).$(O): $(2).c
	$$(CC) -c $$(OC_CFLAGS) $$(PRIVATE_CFLAGS) $$(OC_CPPFLAGS) \
	  $$(OUTPUTOBJ)$$@ $$<
endef

object_types := % %_b %_bd %_bi %_bpic %_n %_nd %_ni %_np %_npic

$(foreach object_type, $(object_types), \
  $(eval $(call COMPILE_C_FILE,$(object_type),%)))

$(UNIX_OR_WIN32)_non_shared_%.$(O): OC_CPPFLAGS += -DBUILDING_LIBCAMLRUNS

$(eval $(call COMPILE_C_FILE,$(UNIX_OR_WIN32)_non_shared_%,$(UNIX_OR_WIN32)))

startup_byt.%.$(O): OC_CPPFLAGS += -DHOST='"$(HOST)"'

$(foreach object_type,$(subst %,,$(object_types)), \
  $(eval dynlink$(object_type).$(O): $(ROOTDIR)/Makefile.config))

# Compilation of assembly files

%.o: %.S
	$(ASPP) $(ASPPFLAGS) -o $@ $< || \
	{ echo "If your assembler produced syntax errors, it is probably";\
          echo "unhappy with the preprocessor. Check your assembler, or";\
          echo "try producing $*.o by hand.";\
          exit 2; }

%_libasmrunpic.o: %.S
	$(ASPP) $(ASPPFLAGS) $(SHAREDLIB_CFLAGS) -o $@ $<

domain_state64.inc: caml/domain_state.tbl gen_domain_state64_inc.awk
	$(AWK) -f ./gen_domain_state64_inc.awk $< > $@

domain_state32.inc: caml/domain_state.tbl gen_domain_state32_inc.awk
	$(AWK) -f ./gen_domain_state32_inc.awk $< > $@

amd64nt.obj: amd64nt.asm domain_state64.inc
	$(ASM)$@ $(ASMFLAGS) $<

i386nt.obj: i386nt.asm domain_state32.inc
	$(ASM)$@ $(ASMFLAGS) $<

%_libasmrunpic.obj: %.asm
	$(ASM)$@ $(ASMFLAGS) $<

# Dependencies

.PHONY: depend
ifeq "$(TOOLCHAIN)" "msvc"
depend:
	$(error Dependencies cannot be regenerated using the MSVC ports)
else

NATIVE_DEP_CPPFLAGS := $(OC_CPPFLAGS) $(OC_NATIVE_CPPFLAGS)
BYTECODE_DEP_FILES := $(BYTECODE_C_SOURCES) $(other_files) instrtrace.c
NATIVE_DEP_FILES := $(NATIVE_C_SOURCES) $(other_files)

depend: *.c caml/opnames.h caml/jumptbl.h caml/version.h build_config.h
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

# This empty target is here for AppVeyor to allow dependencies to be built
# without doing anything else.
.PHONY: setup-depend
setup-depend:
