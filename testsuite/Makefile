#**************************************************************************
#*                                                                        *
#*                                 OCaml                                  *
#*                                                                        *
#*                 Xavier Clerc, SED, INRIA Rocquencourt                  *
#*                                                                        *
#*   Copyright 2010 Institut National de Recherche en Informatique et     *
#*     en Automatique.                                                    *
#*                                                                        *
#*   All rights reserved.  This file is distributed under the terms of    *
#*   the GNU Lesser General Public License version 2.1, with the          *
#*   special exception on linking described in the file LICENSE.          *
#*                                                                        *
#**************************************************************************

BASEDIR := $(shell pwd)
NO_PRINT=`$(MAKE) empty --no-print-directory >/dev/null 2>&1 \
	  && echo --no-print-directory`

FIND=find
TOPDIR := ..
include $(TOPDIR)/Makefile.tools

OCAMLTESTDIR_CYGPATH=$(shell $(CYGPATH) $(BASEDIR)/$(DIR)/_ocamltest)

TESTLOG ?= _log

CPU_COUNT = \
  $(if $(filter FreeBSD,$(shell uname -s)),\
	    $(shell sysctl -n hw.ncpu),\
			$(shell getconf _NPROCESSORS_ONLN))

J_ARG = $(if $(filter -j,$(MAKEFLAGS)),,-j $(CPU_COUNT))

ocamltest_directory := ../ocamltest

ocamltest_program := $(or \
  $(wildcard $(ocamltest_directory)/ocamltest.opt$(EXE)),\
  $(wildcard $(ocamltest_directory)/ocamltest$(EXE)))

ifeq "$(UNIX_OR_WIN32)" "unix"
  ifeq "$(SYSTEM)" "cygwin"
    find := /usr/bin/find
  else # Non-cygwin Unix
    find := find
  endif
  FLEXLINK_ENV =
else # Windows
  find := /usr/bin/find
  FLEXDLL_SUBMODULE_PRESENT := $(wildcard ../flexdll/Makefile)
  ifeq "$(FLEXDLL_SUBMODULE_PRESENT)" ""
    FLEXLINK_ENV =
  else
    ROOT := $(shell cd .. && pwd| cygpath -m -f -)
    FLEXLINK_ENV = \
      OCAML_FLEXLINK="$(ROOT)/boot/ocamlrun $(ROOT)/flexdll/flexlink.exe"
  endif
endif

ifeq "$(FLEXLINK_ENV)" ""
  ocamltest := MKDLL="$(MKDLL)" SORT=$(SORT) MAKE=$(MAKE) $(ocamltest_program)
else
  MKDLL=$(WINTOPDIR)/boot/ocamlrun $(WINTOPDIR)/flexdll/flexlink.exe \
                                   $(FLEXLINK_FLAGS)

  ocamltest := $(FLEXLINK_ENV) MKDLL="$(MKDLL)" SORT=$(SORT) MAKE=$(MAKE) \
                               $(ocamltest_program)
endif

# PROMOTE is only meant to be used internally in recursive calls;
# users should call the 'promote' target explicitly.
PROMOTE =
ifeq "$(PROMOTE)" ""
  OCAMLTEST_PROMOTE_FLAG :=
else
  OCAMLTEST_PROMOTE_FLAG := -promote
endif

# KEEP_TEST_DIR_ON_SUCCESS should be set by the user (to a non-empty value)
# if they want to pass the -keep-test-dir-on-success option to ocamltest,
# to preserve test data of succesful tests.
KEEP_TEST_DIR_ON_SUCCESS ?=
ifeq "$(KEEP_TEST_DIR_ON_SUCCESS)" ""
  OCAMLTEST_KEEP_TEST_DIR_ON_SUCCESS_FLAG :=
else
  OCAMLTEST_KEEP_TEST_DIR_ON_SUCCESS_FLAG := -keep-test-dir-on-success
endif

OCAMLTESTFLAGS := \
  $(OCAMLTEST_PROMOTE_FLAG) \
  $(OCAMLTEST_KEEP_TEST_DIR_ON_SUCCESS_FLAG)

.PHONY: default
default:
	@echo "Available targets:"
	@echo "  all             launch all tests"
	@echo "  all-foo         launch all tests beginning with foo"
	@echo "  parallel        launch all tests using GNU parallel"
	@echo "  parallel-foo    launch all tests beginning with foo using \
	GNU parallel"
	@echo "  list FILE=f     launch the tests listed in f (one per line)"
	@echo "  one DIR=p       launch the tests located in path p"
	@echo "  promote DIR=p   promote the reference files for the tests in p"
	@echo "  lib             build library modules"
	@echo "  tools           build test tools"
	@echo "  clean           delete generated files"
	@echo "  report          print the report for the last execution"
	@echo
	@echo "all*, parallel* and list can automatically re-run failed test"
	@echo "directories if MAX_TESTSUITE_DIR_RETRIES permits"
	@echo "(default value = $(MAX_TESTSUITE_DIR_RETRIES))"

.PHONY: all
all:
	@$(MAKE) $(NO_PRINT) new-without-report
	@$(MAKE) $(NO_PRINT) report

.PHONY: all-parallel
all-parallel:
	@$(MAKE) $(NO_PRINT) $(J_ARG) all

TEST_DIR_OUTPUT = $(subst /,-,$*)
.PHONY: %.result
%.result:
	@echo "Running tests from 'tests/"'$*'"' ..." > 't-$(TEST_DIR_OUTPUT)'
	@$(MAKE) exec-ocamltest DIR=tests/$* OCAMLTESTENV="" 2>&1 \
      >> 't-$(TEST_DIR_OUTPUT)'
	@mv 't-$(TEST_DIR_OUTPUT)' '$(TEST_DIR_OUTPUT).result'
	@$(MAKE) emit-log TEST='$(TEST_DIR_OUTPUT)'

# emit-log is called by each test directory, running in parallel. The test
# attempts to lock the console by atomically setting print-lock to its test
# result filename (NB `mv -n` is not portable, hence the strange invocation with
# `mv -i`). Only process will succeed, and it then prints all the results it
# can, leaving the results still to be printed in test-dirs. There is a
# potential race condition at the end of the run, hence emit-log is called at
# the end with a dummy "flush" target to guarantee that all results have been
# printed to the console.
emit-log:
	@if [ ! -e print-lock ] ; then \
    echo '$(TEST)' > print-lock.$(TEST); \
    echo n | LC_MESSAGES=POSIX mv -i print-lock.$(TEST) print-lock \
       2>/dev/null; \
    rm -f print-lock.$(TEST); \
   fi; \
   if [ "$$(cat print-lock 2>/dev/null)" = '$(TEST)' ]; then \
     cat test-dirs 2>/dev/null | while IFS= read -r dir; do \
       if [ -e printing ] ; then \
         echo "$$dir" >> printing; \
       else \
         if [ -e "$$dir" ]; then \
           cat "$$dir"; \
         else \
           echo "$$dir" > printing; \
         fi; \
       fi; \
     done; \
     if [ -e printing ] ; then \
       mv printing test-dirs; \
     else \
       rm -f test-dirs; \
     fi; \
     rm -f print-lock; \
   fi

ALL_TEST_DIRS = $(shell $(ocamltest) -find-test-dirs tests)
ALL_RESULTS = $(subst tests/,,$(addsuffix .result,$(ALL_TEST_DIRS)))

# test-dirs is phony so that it is always executed
.PHONY: test-dirs
test-dirs:
	@$(ocamltest) -find-test-dirs tests \
      | sed -e 's|tests/||;s|/|-|g;s|$$|.result|' > $@

.PHONY: new-without-report
new-without-report: lib tools test-dirs
	@rm -f *.result print-lock
	@$(MAKE) $(ALL_RESULTS)
	@$(MAKE) emit-log TEST='testsuite-flush-output'
	@touch empty.result
	@cat *.result > $(TESTLOG)
	@rm *.result

.PHONY: all-%
all-%: lib tools
	@for dir in tests/$**; do \
	  $(MAKE) $(NO_PRINT) exec-one DIR=$$dir; \
	done 2>&1 | tee $(TESTLOG)
	@$(MAKE) $(NO_PRINT) retries
	@$(MAKE) report

# The targets below use GNU parallel to parallelize tests
# 'make all' and 'make parallel' should be equivalent
#
# parallel uses specific logic to make sure the output of the commands
# run in parallel are not mangled. By default, it will reproduce
# the output of each completed command atomically, in order of completion.
#
# With the --keep-order option, we ask it to save the completed output
# and replay them in invocation order instead. In theory this costs
# a tiny bit of performance, but I could not measure any difference.
# In theory again, the reporting logic works fine with test outputs
# coming in in arbitrary order (so we should not need --keep-order),
# but keeping the output deterministic is guaranteed to make
# someone's life easier at least once in the future.
#
# Finally, note that the command we run has a 2>&1 redirection, as
# in the other make targets. If we removed the quoting around
# "$(MAKE) ... 2>&1", the rediction would apply to the complete output
# of parallel, and have a slightly different behavior: by default parallel
# cleanly separates the stdout and stderr output of each completed command,
# printing stderr first then stdout second (for each command).
# I chose to keep the previous behavior exactly unchanged,
# but the demangling separation is arguably nicer behavior that we might
# want to implement at the exec-one level to also have it in the 'all' target.
.PHONY: parallel-%
parallel-%: lib tools
	@echo | parallel >/dev/null 2>/dev/null \
	 || (echo "Unable to run the GNU parallel tool;";\
	     echo "You should install it before using the parallel* targets.";\
	     exit 1)
	@echo | parallel --gnu --no-notice >/dev/null 2>/dev/null \
	 || (echo "Your 'parallel' tool seems incompatible with GNU parallel.";\
	     echo "This target requires GNU parallel.";\
	     exit 1)
	@for dir in tests/$**; do echo $$dir; done \
	 | parallel --gnu --no-notice --keep-order \
	     "$(MAKE) $(NO_PRINT) exec-one DIR={} 2>&1" \
	 | tee $(TESTLOG)
	@$(MAKE) $(NO_PRINT) retries
	@$(MAKE) report

.PHONY: parallel
parallel: parallel-*

.PHONY: list
list: lib tools
	@if [ -z "$(FILE)" ]; \
	  then echo "No value set for variable 'FILE'."; \
	  exit 1; \
	fi
	@while read LINE; do \
	  $(MAKE) $(NO_PRINT) exec-one DIR=$$LINE; \
	done <$(FILE) 2>&1 | tee $(TESTLOG)
	@$(MAKE) $(NO_PRINT) retries
	@$(MAKE) report

.PHONY: one
one: lib tools
	@if [ -z "$(DIR)" ]; then \
	  echo "No value set for variable 'DIR'."; \
	  exit 1; \
	fi
	@if [ ! -d $(DIR) ]; then \
	  echo "Directory '$(DIR)' does not exist."; \
	  exit 1; \
	fi
	@$(MAKE) $(NO_PRINT) exec-one DIR=$(DIR)

.PHONY: exec-one
exec-one:
	@if $(ocamltest) -list-tests $(DIR) >/dev/null 2>&1; then \
	  echo "Running tests from '$$DIR' ..."; \
	  $(MAKE) exec-ocamltest DIR=$(DIR) \
	    OCAMLTESTENV="OCAMLTESTDIR=$(OCAMLTESTDIR_CYGPATH)"; \
	else \
	  for dir in $(DIR)/*; do \
	    if [ -d $$dir ]; then \
	      $(MAKE) exec-one DIR=$$dir; \
	    fi; \
	  done; \
	fi

.PHONY: exec-ocamltest
exec-ocamltest:
	@if [ -z "$(DIR)" ]; then exit 1; fi
	@if [ ! -d "$(DIR)" ]; then exit 1; fi
	@(IFS=$$(printf "\r\n"); \
	$(ocamltest) -list-tests $(DIR) | while read testfile; do \
	   TERM=dumb $(OCAMLTESTENV) \
	     $(ocamltest) $(OCAMLTESTFLAGS) $(DIR)/$$testfile || \
	   echo " ... testing '$$testfile' => unexpected error"; \
	done)

.PHONY: clean-one
clean-one:
	@if [ ! -f $(DIR)/Makefile ]; then \
	  for dir in $(DIR)/*; do \
	    if [ -d $$dir ]; then \
	      $(MAKE) clean-one DIR=$$dir; \
	    fi; \
	  done; \
	else \
	  cd $(DIR) && $(MAKE) TERM=dumb BASEDIR=$(BASEDIR) clean; \
	fi

.PHONY: promote
promote:
	@if [ -z "$(DIR)" ]; then \
	  echo "No value set for variable 'DIR'."; \
	  exit 1; \
	fi
	@if [ ! -d $(DIR) ]; then \
	  echo "Directory '$(DIR)' does not exist."; \
	  exit 1; \
	fi
	@if $(ocamltest) -list-tests $(DIR) >/dev/null 2>&1; then \
	  $(MAKE) exec-ocamltest DIR=$(DIR) \
	    OCAMLTESTENV="OCAMLTESTDIR=$(OCAMLTESTDIR_CYGPATH)" \
	    PROMOTE="true"; \
	else \
	  cd $(DIR) && $(MAKE) TERM=dumb BASEDIR=$(BASEDIR) promote; \
	fi

.PHONY: lib
lib:
	@$(MAKE) -s -C lib

.PHONY: tools
tools:
	@cd tools && $(MAKE) -s BASEDIR=$(BASEDIR)

.PHONY: clean
clean:
	@$(MAKE) -C lib clean
	@cd tools && $(MAKE) BASEDIR=$(BASEDIR) clean
	$(FIND) . -name '*_ocamltest*' | xargs rm -rf

.PHONY: report
report:
	@if [ ! -f $(TESTLOG) ]; then echo "No $(TESTLOG) file."; exit 1; fi
	@$(AWK) -f ./summarize.awk < $(TESTLOG)

.PHONY: retry-list
retry-list:
	@while read LINE; do \
	  if [ -n "$$LINE" ] ; then \
	    echo re-ran $$LINE>> $(TESTLOG); \
	    $(MAKE) $(NO_PRINT) clean-one DIR=$$LINE; \
	    $(MAKE) $(NO_PRINT) exec-one DIR=$$LINE 2>&1 | tee -a $(TESTLOG) ; \
	  fi \
	done <_retries;
	@$(MAKE) $(NO_PRINT) retries

.PHONY: retries
retries:
	@$(AWK) -v retries=1 -v max_retries=$(MAX_TESTSUITE_DIR_RETRIES) \
	     -f ./summarize.awk < $(TESTLOG) > _retries
	@test `cat _retries | wc -l` -eq 0 || $(MAKE) $(NO_PRINT) retry-list
	@rm -f _retries

.PHONY: empty
empty:
