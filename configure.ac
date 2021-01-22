#**************************************************************************
#*                                                                        *
#*                                 OCaml                                  *
#*                                                                        *
#*            Sebastien Hinderer, projet Gallium, INRIA Paris             *
#*                                                                        *
#*   Copyright 2018 Institut National de Recherche en Informatique et     *
#*     en Automatique.                                                    *
#*                                                                        *
#*   All rights reserved.  This file is distributed under the terms of    *
#*   the GNU Lesser General Public License version 2.1, with the          *
#*   special exception on linking described in the file LICENSE.          *
#*                                                                        *
#**************************************************************************

# Process this file with autoconf to produce a configure script.

# Require Autoconf 2.69 for repeatability in CI
AC_PREREQ([2.69])
AC_INIT([OCaml],
        m4_esyscmd([head -n1 VERSION | tr -d '\r\n']),
        [caml-list@inria.fr],
        [ocaml],
        [http://www.ocaml.org])

AC_MSG_NOTICE([Configuring OCaml version AC_PACKAGE_VERSION])

# Configuration variables

## Command-line arguments passed to configure
CONFIGURE_ARGS="$*"

# Command-line tools section of the Unix manual
programs_man_section=1

# Library section of the Unix manual
libraries_man_section=3

# Default profinfo configuration. profinfo_width is ignored if profinfo=false
profinfo=false
profinfo_width=0

# Exported as EXTRALIBS, this used to be needed for very old x64 MSVC compilers
# XXX This variable should be completely eliminated
extralibs=

# Information about the package

## Source directory
AC_CONFIG_SRCDIR([runtime/interp.c])

## Directory containing auxiliary scripts used during build
AC_CONFIG_AUX_DIR([build-aux])

## Output variables

AC_SUBST([CONFIGURE_ARGS])
AC_SUBST([native_compiler])
AC_SUBST([AS])
AC_SUBST([ASPP])
AC_SUBST([VERSION], [AC_PACKAGE_VERSION])
AC_SUBST([programs_man_section])
AC_SUBST([libraries_man_section])
AC_SUBST([fpic])
AC_SUBST([bytecclibs])
AC_SUBST([nativecclibs])
AC_SUBST([long_shebang])
AC_SUBST([shebangscripts])
AC_SUBST([debug_runtime])
AC_SUBST([instrumented_runtime])
AC_SUBST([otherlibraries])
AC_SUBST([with_debugger]) # TODO: rename this variable
AC_SUBST([with_camltex])
AC_SUBST([ocamldoc])
AC_SUBST([install_bytecode_programs])
AC_SUBST([install_source_artifacts])
AC_SUBST([natdynlink])
AC_SUBST([cmxs])
AC_SUBST([profinfo])
AC_SUBST([extralibs])
AC_SUBST([profinfo_width])
AC_SUBST([frame_pointers])
AC_SUBST([spacetime])
AC_SUBST([call_counts])
AC_SUBST([oc_cflags])
AC_SUBST([oc_cppflags])
AC_SUBST([ocamlc_cflags])
AC_SUBST([ocamlc_cppflags])
AC_SUBST([ocamlopt_cflags])
AC_SUBST([ocamlopt_cppflags])
AC_SUBST([as_has_debug_prefix_map])
AC_SUBST([flambda])
AC_SUBST([flambda_invariants])
AC_SUBST([max_testsuite_dir_retries])
AC_SUBST([windows_unicode])
AC_SUBST([flat_float_array])
AC_SUBST([afl])
AC_SUBST([force_safe_string])
AC_SUBST([default_safe_string])
AC_SUBST([stdlib_manpages])

## Generated files

AC_CONFIG_FILES([Makefile.common])
AC_CONFIG_FILES([Makefile.config])
# TODO Ensure all the varibles in runtime/caml/r.h.in are available
AC_CONFIG_HEADERS([runtime/target/r.h])

# COMBAK precise details for when this should be done
mkdir -p runtime/host
cat > runtime/host/r.h <<EOF
#define CAML_SAFE_STRING 1
#define FLAT_FLOAT_ARRAY 1
#define FUNCTION_SECTIONS 1
EOF

# Checks for system types

AC_CANONICAL_BUILD
AC_CANONICAL_HOST
AC_CANONICAL_TARGET

# Environment variables that are taken into account

# XXX COMBAK THIS IS NOT CORRECT FROM X-COMPILATION
AC_ARG_VAR([AS], [which assembler to use])
AC_ARG_VAR([ASPP], [which assembler (with preprocessor) to use])
AC_ARG_VAR([PARTIALLD], [how to build partial (relocatable) object files])

# XXX COMBAK THIS IS NOT CORRECT FROM X-COMPILATION
AC_ARG_VAR([DLLIBS],
  [which libraries to use (in addition to -ldl) to load dynamic libs])

# XXX COMBAK Care to inject this for X-Compilation
AC_ARG_VAR([LIBUNWIND_INCLUDE_DIR],
  [location of header files for libunwind])

AC_ARG_VAR([LIBUNWIND_LIB_DIR],
  [location of library files for libunwind])

# XXX COMBAK CARE NEEDED FOR X-COMPILATION
AC_ARG_VAR([BFD_INCLUDE_DIR],
  [location of header files for the BFD library])

AC_ARG_VAR([BFD_LIB_DIR],
  [location of library files for the BFD library])

# XXX COMBAK X-COMPILATION IMPLICATIONS?
AC_ARG_VAR([WINDOWS_UNICODE_MODE],
  [how to handle Unicode under Windows: ansi, compatible])

# Command-line arguments to configure

AC_ARG_ENABLE([debug-runtime],
  [AS_HELP_STRING([--disable-debug-runtime],
    [do not build runtime with debugging support])])

AC_ARG_ENABLE([debugger],
  [AS_HELP_STRING([--enable-debugger],
    [build the debugger @<:@default=auto@:>@])],
  [],
  [enable_debugger=auto])

AC_ARG_ENABLE([instrumented-runtime],
  [AS_HELP_STRING([--enable-instrumented-runtime],
    [build the instrumented runtime @<:@default=auto@:>@])],
  [],
  [enable_instrumented_runtime=auto])

AC_ARG_ENABLE([vmthreads], [],
  [AC_MSG_ERROR([The vmthreads library is no longer available. \
It was deleted in OCaml 4.09.])],
  [])

AC_ARG_ENABLE([systhreads],
  [AS_HELP_STRING([--disable-systhreads],
    [disable the Win32/POSIX threads library])])

AC_ARG_WITH([libunwind],
  [AS_HELP_STRING([--without-libunwind],
    [disable libunwind support for Spacetime profiling])])

AC_ARG_WITH([bfd],
  [AS_HELP_STRING([--without-bfd],
    [disable BFD (Binary File Description) library support])],
    [],
    [with_bfd=auto])
AC_ARG_ENABLE([graph-lib], [],
  [AC_MSG_ERROR([The graphics library is no longer distributed with OCaml \
since version 4.09. It is now distributed as a separate "graphics" package: \
https://github.com/ocaml/graphics])],
  [])

AC_ARG_ENABLE([str-lib],
  [AS_HELP_STRING([--disable-str-lib],
    [do not build the str library])])

AC_ARG_ENABLE([unix-lib],
  [AS_HELP_STRING([--disable-unix-lib],
    [do not build the unix library])])

AC_ARG_ENABLE([bigarray-lib],
  [AS_HELP_STRING([--disable-bigarray-lib],
    [do not build the legacy separate bigarray library])])

AC_ARG_ENABLE([ocamldoc],
  [AS_HELP_STRING([--disable-ocamldoc],
    [do not build the ocamldoc documentation system])],
  [],
  [ocamldoc=auto])

AC_ARG_ENABLE([frame-pointers],
  [AS_HELP_STRING([--enable-frame-pointers],
    [use frame pointers in runtime and generated code])])

AC_ARG_ENABLE([naked-pointers],
  [AS_HELP_STRING([--disable-naked-pointers],
    [do not allow naked pointers])])

AC_ARG_ENABLE([spacetime],
  [AS_HELP_STRING([--enable-spacetime],
    [build the spacetime profiler])])

AC_ARG_ENABLE([call-counts],
  [AS_HELP_STRING([--disable-call-counts],
    [disable the call counts in spacetime])])

# XXX COMBAK DRA at the moment --disable-cfi doesn't work
AC_ARG_ENABLE([cfi],
  [AS_HELP_STRING([--disable-cfi],
    [disable the CFI directives in assembly files])])

AC_ARG_ENABLE([installing-source-artifacts],
  [AS_HELP_STRING([--enable-installing-source-artifacts],
    [install *.cmt* and *.mli files])])
AC_ARG_ENABLE([installing-bytecode-programs],
  [AS_HELP_STRING([--enable-installing-bytecode-programs],
    [also install the bytecode versions of programs])])

AC_ARG_ENABLE([native-compiler],
  [AS_HELP_STRING([--disable-native-compiler],
    [do not build the native compiler])])

AC_ARG_ENABLE([flambda],
  [AS_HELP_STRING([--enable-flambda],
    [enable flambda optimizations])])

AC_ARG_ENABLE([flambda-invariants],
  [AS_HELP_STRING([--enable-flambda-invariants],
    [enable invariants checks in flambda])])

# XXX COMBAK This is hopefully meaningless with X-Compilation
AC_ARG_WITH([target-bindir],
  [AS_HELP_STRING([--with-target-bindir],
    [location of binary programs on target system])])

AC_ARG_ENABLE([reserved-header-bits],
  [AS_HELP_STRING([--enable-reserved-header-bits=BITS],
  [reserve BITS (between 0 and 31) bits in block headers for profiling info])],
  [AS_CASE([$enable_reserved_header_bits],
    [0],
      [with_profinfo=false
      profinfo_width=0],
    [[[1-9]]|1[[0-9]]|2[[0-1]]],
      [with_profinfo=true
      profinfo_width="$enable_reserved_header_bits"],
    [AC_MSG_ERROR([invalid argument to --enable-reserved-header-bits])])])

AC_ARG_ENABLE([stdlib-manpages],
  [AS_HELP_STRING([--disable-stdlib-manpages],
    [do not build or install the library man pages])])

# There are two configure-time string safety options,
# --(enable|disable)-force-safe-string and
# DEFAULT_STRING=safe|unsafe that
# interact with a compile-time (un)safe-string option.
#
# If --enable-force-safe-string is set at configure time, then the compiler
# will always enforce that string and bytes are distinct: the
# compile-time -unsafe-string option is disabled. This lets us
# assume pervasive string immutability, for code optimizations and
# in the C layer.
#
# If --disable-force-safe-string is set at configure-time, the compiler
# will use the compile-time (un)safe-string option to decide whether
# string and bytes are compatible on a per-file basis. The
# configuration variable DEFAULT_STRING=safe|unsafe decides which
# setting will be chosen by default, if no compile-time option is
# explicitly passed.
#
# The configure-time behavior of OCaml 4.05 and older was equivalent
# to --disable-force-safe-string DEFAULT_STRING=unsafe. With OCaml 4.06
# and older was equivalent to --disable-force-safe-string DEFAULT_STRING=safe.
# With OCaml 4.10 and later use --enable-force-safe-string DEFAULT_STRING=safe.
# We expect the --disable-force-safe-string and DEFAULT_STRING=unsafe options
# to be removed in the future.

AC_ARG_ENABLE([force-safe-string],
  [AS_HELP_STRING([--disable-force-safe-string],
    [do not force strings to be safe])])

AC_ARG_VAR([DEFAULT_STRING],
  [whether strings should be safe (default) or unsafe])

AC_ARG_ENABLE([flat-float-array],
  [AS_HELP_STRING([--disable-flat-float-array],
    [do not use flat float arrays])])

AC_ARG_ENABLE([function-sections],
  [AS_HELP_STRING([--disable-function-sections],
    [do not emit each function in a separate section])],
  [],
  [enable_function_sections=auto])

AC_ARG_WITH([afl],
  [AS_HELP_STRING([--with-afl],
    [use the AFL fuzzer])])

AS_IF([test x"$enable_unix_lib" = "xno"],
  [AS_IF([test x"$enable_debugger" = "xyes"],
    [AC_MSG_ERROR([replay debugger requires the unix library])],
    [enable_debugger="no"])
   AS_IF([test x"$enable_bigarray_lib" = "xyes"],
    [AC_MSG_ERROR([legacy bigarray library requires the unix library])])])

AS_IF([test x"$enable_unix_lib" = "xno" -o x"$enable_str_lib" = "xno"],
  [AS_IF([test x"$enable_ocamldoc" = "xyes"],
    [AC_MSG_ERROR([ocamldoc requires the unix and str libraries])],
    [enable_ocamldoc="no"
     with_camltex=""])],
  [with_camltex="true"])

AS_IF([test "$host" = "$build"],
  [AC_MSG_NOTICE([We are NOT cross-compiling])
  cross_compiling='false'],
  [AC_MSG_ERROR([We are using $build to create a compiler which will run on $host])
  cross_compiling='true'])
AS_IF([test "$host" = "$target"],
  [AC_MSG_NOTICE([We are making a normal compiler (for $host)])
  cross_compiler='false'],
  [AC_MSG_NOTICE([We are producing a cross-compiler which will target $target])
  cross_compiler='true'])

AC_SUBST([cross_compiling])
AC_SUBST([cross_compiler])

# Get the host system configuration
cd runtime
mkdir -p host
cd host
if test -n "$cache_file" ; then :
  # XXX For cross-compilation, this will then be recomputed
  # XXX The eval quoting below is also not working
  cache_file="--cache-file \"../../$cache_file\""
fi
# XXX Temporary - cache_file defaults to /dev/null
cache_file=
build_arg=
host_arg=
if test -n "$build_alias" ; then :
  build_arg="--build=$build_alias"
fi
if test -n "$host_alias" ; then :
  host_arg="--host=$host_alias"
fi
# Environment variables which are used by the runtime configure script are explicitly passed
# (X-Compilation TODO reminder)
AS_IF([test "$with_libunwind" != 'yes' && test "$with_libunwind" != 'no'],
  [AS_IF([test -z "$LIBUNWIND_INCLUDE_DIR"],
    [LIBUNWIND_INCLUDE_DIR="$with_libunwind/include"])
   AS_IF([test -z "$LIBUNWIND_LIB_DIR"],
    [LIBUNWIND_LIB_DIR="$with_libunwind/lib"])])
# XXX CC=\"$CC\" causing trouble?
# XXX TODO AS and ASPP should be being passed here
# XXX CONF_PREFIX should only be set if we are building a cross-compiler
eval ../configure $build_arg $host_arg $cache_file CONF_PREFIX=host_ LIBUNWIND_INCLUDE_DIR=\"$LIBUNWIND_INCLUDE_DIR\" LIBUNWIND_LIB_DIR=\"$LIBUNWIND_LIB_DIR\" BFD_INCLUDE_DIR=\"$BFD_INCLUDE_DIR\" BFD_LIB_DIR=\"$BFD_LIB_DIR\" # "
# If we're building a cross-compiler, then host ocamlrun only
# XXX COMBAK What's really needed here it to shift logic from runtime/Makefile for what gets built to configure.ac
#AS_IF([$cross_compiler],
#  [cat > Makefile <<"EOF"
#runtime: ocamlrun$(EXE)
#
#include ../Makefile
#EOF
#],[cat > Makefile <<"EOF"
#runtime: all
#
#include ../Makefile
#EOF
#])
cd ..

AS_IF([$cross_compiler],
[
  # We're building a cross-compiler, so we need the build->target configuration as well
  if test -n "$target_alias" ; then :
    host_arg="--host=$target_alias"
  else
    # XXX DRA Is this impossible?
    host_arg=''
  fi
  mkdir -p target
  cd target
  eval ../configure $build_arg $host_arg LIBUNWIND_INCLUDE_DIR=\"$LIBUNWIND_INCLUDE_DIR\" LIBUNWIND_LIB_DIR=\"$LIBUNWIND_LIB_DIR\" BFD_INCLUDE_DIR=\"$BFD_INCLUDE_DIR\" BFD_LIB_DIR=\"$BFD_LIB_DIR\" # "
#  cat > Makefile <<"EOF"
#runtime: all
#include ../Makefile
#EOF
  cd ..
])

cd ..

# XXX DRA TODO If build <> host then we also need a build ocamlrun!

# Read the variables
. runtime/host/vars.sh
AS_IF([$cross_compiler],
[. runtime/target/vars.sh])

# Variables from the runtime configure script which we export
AC_SUBST([CC])
AC_SUBST([host_CC])
AC_SUBST([TOOLPREF])
AC_SUBST([cc_has_debug_prefix_map])
AC_SUBST([oc_ldflags])
AC_SUBST([host_oc_ldflags])
AC_SUBST([CPP])
AC_SUBST([RANLIB])
AC_SUBST([RANLIBCMD])
AC_SUBST([AR])
AC_SUBST([OBJEXT])
AC_SUBST([host_OBJEXT])
AC_SUBST([outputobj])
AC_SUBST([host_outputobj])
AC_SUBST([libext])
AC_SUBST([host_libext])
AC_SUBST([S])
AC_SUBST([host_S])
AC_SUBST([SO])
AC_SUBST([sharedlib_cflags])
AC_SUBST([rpath])
AC_SUBST([arch])
AC_SUBST([host_arch])
AC_SUBST([arch64])
AC_SUBST([model])
AC_SUBST([system])
AC_SUBST([pthread_link])
AC_SUBST([unix_or_win32])
AC_SUBST([host_unix_or_win32])
AC_SUBST([unixlib])
AC_SUBST([bfd_cppflags])
AC_SUBST([function_sections])
AC_SUBST([bfd_ldflags])
AC_SUBST([bfd_ldlibs])
AC_SUBST([bytecclibs])
AC_SUBST([exeext])
AC_SUBST([host_exeext])
AC_SUBST([outputexe])
AC_SUBST([host_outputexe])
AC_SUBST([supports_shared_libraries])
AC_SUBST([mksharedlibrpath])
AC_SUBST([natdynlinkopts])
AC_SUBST([syslib])
AC_SUBST([mklib])
AC_SUBST([host_mklib])
AC_SUBST([nativecclibs])
AC_SUBST([systhread_support])
AC_SUBST([PACKLD])
AC_SUBST([iflexdir])
AC_SUBST([ccomptype])
AC_SUBST([toolchain])
AC_SUBST([host_toolchain])
AC_SUBST([mkexe])
AC_SUBST([mksharedlib])
AC_SUBST([mkmaindll])
AC_SUBST([mkexedebugflag])
AC_SUBST([asm_cfi_supported])
AC_SUBST([libunwind_available])
AC_SUBST([libunwind_include_flags])
AC_SUBST([libunwind_link_flags])
AC_SUBST([flexdll_chain])
AC_SUBST([flexlink_flags])
AC_SUBST([dynlink_libs])
AC_SUBST([AWK])

otherlibraries="dynlink"
AS_IF([test x"$enable_unix_lib" != "xno"],
  [AS_IF([test x"$enable_bigarray_lib" != "xno"],
   # XXX COMBAK Use of $unixlib or $target?
    [otherlibraries="$otherlibraries $unixlib bigarray"],
    [otherlibraries="$otherlibraries $unixlib"])])
AS_IF([test x"$enable_str_lib" != "xno"],
  [otherlibraries="$otherlibraries str"])

# Checks for system services

## Test whether #! scripts are supported
## TODO: have two values, one for host and one for target
AC_SYS_INTERPRETER

long_shebang=false
AS_IF(
  [test "x$interpval" = "xyes"],
    [AS_CASE([$host],
      [*-cygwin|*-*-mingw32|*-pc-windows],
        [shebangscripts=false],
      [shebangscripts=true
       prev_exec_prefix="$exec_prefix"
       AS_IF([test "x$exec_prefix" = "xNONE"],[exec_prefix="$prefix"])
       eval "expanded_bindir=\"$bindir\""
       exec_prefix="$prev_exec_prefix"
       # Assume maximum shebang is 128 chars; less #!, /ocamlrun, an optional
       # 1 char suffix and the \0 leaving 115 characters
       AS_IF([test "${#expanded_bindir}" -gt 115],[long_shebang=true])
      ]
    )],
  [shebangscripts=false]
)

# Configuration for the OCaml compilers
APPEND_FLAG([dynlink_libs], [$DLLIBS])
bytecclibs="$cclibs $dynlink_libs $pthread_link $instrumented_runtime_libs"
host_bytecclibs="$host_cclibs $host_dynlink_libs $host_pthread_link"
AC_SUBST([host_bytecclibs])
nativecclibs="$cclibs $dynlink_libs"

# Checks for programs

## Program to use to install files
AC_PROG_INSTALL

# If set, $PARTIALLD overrides the detected $PACKLD
AS_IF([test -n "$PARTIALLD"],[PACKLD="$PARTIALLD -o \$(EMPTY)"])

# Configure native dynlink

natdynlink=false

AS_IF([test x"$enable_shared" != "xno"],
  [AS_CASE(["$host"],
    [*-*-cygwin*], [natdynlink=true],
    [*-*-mingw32], [natdynlink=true],
    [*-pc-windows], [natdynlink=true],
    [[i[3456]86-*-linux*]], [natdynlink=true],
    [[i[3456]86-*-gnu*]], [natdynlink=true],
    [[x86_64-*-linux*]], [natdynlink=true],
    [x86_64-*-darwin*], [natdynlink=true],
    [s390x*-*-linux*], [natdynlink=true],
    [powerpc*-*-linux*], [natdynlink=true],
    [i686-*-kfreebsd*], [natdynlink=true],
    [x86_64-*-kfreebsd*], [natdynlink=true],
    [x86_64-*-dragonfly*], [natdynlink=true],
    [[i[3456]86-*-freebsd*]], [natdynlink=true],
    [x86_64-*-freebsd*], [natdynlink=true],
    [[i[3456]86-*-openbsd*]], [natdynlink=true],
    [x86_64-*-openbsd*], [natdynlink=true],
    [[i[3456]86-*-netbsd*]], [natdynlink=true],
    [x86_64-*-netbsd*], [natdynlink=true],
    [i386-*-gnu0.3], [natdynlink=true],
    [[i[3456]86-*-haiku*]], [natdynlink=true],
    [arm*-*-linux*], [natdynlink=true],
    [arm*-*-freebsd*], [natdynlink=true],
    [earm*-*-netbsd*], [natdynlink=true],
    [aarch64-*-linux*], [natdynlink=true],
    [aarch64-*-freebsd*], [natdynlink=true])])

# Configure the native-code compiler

AS_IF([test x"$enable_native_compiler" = "xno"],
  [arch=none; model=default; system=unknown; native_compiler=false
  AC_MSG_NOTICE([the native compiler is disabled])],
  [native_compiler=true])

AS_IF([! $native_compiler], [natdynlink=false])

AS_IF([$natdynlink], [cmxs="cmxs"], [cmxs="cmx"])

# XXX COMBAK X-Compilation
AS_IF([test $arch != "none" && $arch64 ],
  [otherlibraries="$otherlibraries raw_spacetime_lib"])

# XXX COMBAK X-COMPILATIONS
AS_IF([test "$with_pic"],
  [fpic=true
  AC_DEFINE([CAML_WITH_FPIC])
  internal_cflags="$internal_cflags $sharedlib_cflags"
  default_aspp="$default_aspp $sharedlib_cflags"],
  [fpic=false])

## Determine whether the debugger should/can be built

AS_CASE([$enable_debugger],
  [no],
    [with_debugger=""
    AC_MSG_NOTICE([replay debugger disabled])],
  [AS_IF([$sockets],
    [with_debugger="ocamldebugger"
    AC_MSG_NOTICE([replay debugger supported])],
    [with_debugger=""
    AC_MSG_NOTICE([replay debugger not supported])])
  ])

## Should the runtime with debugging support be built
AS_CASE([$enable_debug_runtime],
  [no], [debug_runtime=false],
  [debug_runtime=true])

## Show the runtime with instrumentation support be built
instrumented_runtime=false
AS_IF([$has_clock_gettime],
  [AS_CASE([$host,$enable_instrumented_runtime],
    [*-*-mingw32,auto], [instrumented_runtime=false],
    [*-*-mingw32,yes], [AC_MSG_ERROR([the instrumented runtime cannot be built])],
    [instrumented_runtime=true])],
  [AS_IF([test "$enable_instrumented_runtime" = 'yes'],
    [AC_MSG_ERROR([the instrumented runtime cannot be built])])])

## Determine if the POSIX threads library is supported

# XXX COMBAK X-COMPILATION THIS NEEDS TO BE SEPARATED OUT
AS_IF([test x"$enable_systhreads" = "xno"],
  [systhread_support=false
  AC_MSG_NOTICE([the Win32/POSIX threads library is disabled])],
  [AS_IF([$systhread_support],
     [APPEND_FLAG([otherlibraries], [systhreads])
     AS_CASE([$host],
       [*-*-mingw32|*-pc-windows], [],
       [APPEND_FLAG([common_cppflags], [-D_REENTRANT])
       AC_MSG_NOTICE([the POSIX threads library is supported])])])])
       # @@DRA COMBAK This test looks incorrect?
#      [AS_IF([test x"$enable_systhreads" = "xyes"],
#        [AC_MSG_ERROR([the POSIX thread library is not available])],
#        [systhread_support=false
#        AC_MSG_NOTICE([the POSIX threads library is not supported])])])])])

## BFD (Binary File Description) library

# XXX COMBAK X-COMPILATION THIS NEEDS TO BE SEPARATED OUT
bfd_cppflags=""
bfd_ldflags=""
bfd_ldlibs=""

#AS_IF([test x"$with_bfd" != "xno"],
#  [bfd_available=false
#  AS_CASE([$host],
#    [x86_64-*-darwin*],
#      [AS_IF([test -z "$BFD_INCLUDE_DIR"],
#        [BFD_INCLUDE_DIR="/opt/local/include"])
#      AS_IF([test -z "$BFD_LIB_DIR"],
#        [BFD_LIB_DIR="/opt/local/lib"])],
#    [*-*openbsd*],
#      [AS_IF([test -z "$BFD_INCLUDE_DIR"],
#        [BFD_INCLUDE_DIR="/usr/local/include"])
#      AS_IF([test -z "$BFD_LIB_DIR"],
#        [BFD_LIB_DIR="/usr/local/lib"])])
#  AS_IF([test -n "$BFD_INCLUDE_DIR"],
#    [bfd_cppflags="-I$BFD_INCLUDE_DIR"])
#  AS_IF([test -n "$BFD_LIB_DIR"],
#    [bfd_ldflags="-L$BFD_LIB_DIR"])
#  SAVED_CPPFLAGS="$CPPFLAGS"
#  SAVED_LDFLAGS="$LDFLAGS"
#  CPPFLAGS="$CPPFLAGS $bfd_cppflags"
#  LDFLAGS="$LDFLAGS $bfd_ldflags"
#  AC_CHECK_HEADER([bfd.h],
#    [bfd_ldlibs=""
#    AC_CHECK_LIB([bfd], [bfd_openr], [bfd_ldlibs="-lbfd"])
#    AS_IF([test -z "$bfd_ldlibs"],
#      [unset ac_cv_lib_bfd_bfd_openr
#      AC_CHECK_LIB([bfd], [bfd_openr],
#        [bfd_ldlibs="-lbfd -liberty"], [], [-liberty])])
#    AS_IF([test -z "$bfd_ldlibs"],
#      [unset ac_cv_lib_bfd_bfd_openr
#      AC_CHECK_LIB([bfd], [bfd_openr],
#        [bfd_ldlibs="-lbfd -liberty -lz"], [], [-liberty -lz])])
#    AS_IF([test -z "$bfd_ldlibs"],
#      [unset ac_cv_lib_bfd_bfd_openr
#      AC_CHECK_LIB([bfd], [bfd_openr],
#        [bfd_ldlibs="-lbfd -liberty -lz -lintl"], [],
#        [-liberty -lz -lintl])])
#    AS_IF([test -n "$bfd_ldlibs"],
#      [bfd_available=true
#      AC_DEFINE([HAS_LIBBFD])])])
#  AS_IF([! $bfd_available],
#    [AS_IF([test x"$with_bfd" = "xyes"],
#      [AC_MSG_ERROR([BFD library support requested but not available])],
#      [bfd_cppflags=""
#      bfd_ldflags=""
#      AC_MSG_NOTICE(m4_normalize([
#        BFD library not found, 'ocamlobjinfo' will be unable to display
#        info on .cmxs files.
#      ]))])])
#  LDFLAGS="$SAVED_LDFLAGS"
#  CPP_FLAGS="$SAVED_CPPFLAGS"],
#  [AC_MSG_NOTICE(m4_normalize([
#    Support for the BFD (Binary File Description) library disabled,
#    'ocamlobjinfo' will be unable to display info on .cmxs files.
#    ]))])

## Frame pointers

# XXX COMBAK X-COMPILATION
AS_IF([test x"$enable_frame_pointers" = "xyes"],
  [AS_CASE(["$host,$CC"],
    [x86_64-*-linux*,gcc*|x86_64-*-linux*,clang*],
      [common_cflags="$common_cflags -g  -fno-omit-frame-pointer"
      frame_pointers=true
      AC_DEFINE([WITH_FRAME_POINTERS])
      AC_MSG_NOTICE([using frame pointers])],
    [AC_MSG_ERROR([frame pointers not supported on this platform])]
  )],
  [AC_MSG_NOTICE([not using frame pointers])
  frame_pointers=false])

## No naked pointers

AS_IF([test x"$enable_naked_pointers" = "xno" ],
  [AC_DEFINE([NO_NAKED_POINTERS])])

# Spacetime profiling, including libunwind detection

# The number of bits used for profiling information is configurable here.
# The more bits used for profiling, the smaller will be Max_wosize.
# Note that PROFINFO_WIDTH must still be defined even if not configuring
# for Spacetime (see comment in runtime/caml/mlvalues.h on [Profinfo_hd]).
AC_MSG_CHECKING([whether to build spacetime])
AS_IF([test x"$enable_spacetime" != "xyes" ],
  [spacetime=false
  call_counts=true # as in original script but should probably be false
  libunwind_available=false
  libunwind_include_flags=
  libunwind_link_flags=
  AC_MSG_RESULT([no])],
  [AS_CASE([$arch],
    [amd64], [spacetime_supported=true],
    [spacetime_supported=false])
  AS_IF([$spacetime_supported],
    [AC_MSG_RESULT([yes])
    spacetime=true
    profinfo=true
    profinfo_width=26
    AC_DEFINE([WITH_SPACETIME])
    AS_IF([test x"$enable_call_counts" != "xno"],
      [call_counts=true
      AC_DEFINE([ENABLE_CALL_COUNTS])],
      [call_counts=false])
    AC_MSG_CHECKING([whether to use libunwind])
    AS_IF([test "$with_libunwind" = 'no'],
      [AC_MSG_RESULT([disabled])
       libunwind_requested=false],
      [AS_IF([test -z "$with_libunwind"],
        [libunwind_requested=false
        AC_MSG_RESULT([if available])],
        [libunwind_requested=true
        AC_MSG_RESULT([requested])])])
      AS_IF([$libunwind_requested && ! $libunwind_available],
        [AC_MSG_ERROR([libunwind was requested but can not be found])])

        # We need unwinding information at runtime, but since we use
        # -no_compact_unwind, we also need -keep_dwarf_unwind otherwise
        # the OS X linker will chuck away the DWARF-like (.eh_frame)
        # information.  (Older versions of OS X don't provide this.)

        AS_IF([$libunwind_available && test x"$system" = "xmacosx"],
          [extra_flags="-Wl,-keep_dwarf_unwind"
          mkexe="$mkexe $extra_flags"
          mksharedlib="$mksharedlib $extra_flags"])],
    [AS_IF([test x"$enable_spacetime" = "xyes"],
      [AC_MSG_RESULT([requested but not supported])
      AC_MSG_ERROR([exiting])],
      [AC_MSG_RESULT([no])])])])

AC_DEFINE_UNQUOTED([PROFINFO_WIDTH], [$profinfo_width])
AS_IF([$profinfo], [AC_DEFINE([WITH_PROFINFO])])

AS_IF([test x"$enable_installing_bytecode_programs" = "xno"],
  [install_bytecode_programs=false],
  [install_bytecode_programs=true])

AS_IF([test x"$enable_installing_source_artifacts" = "xno"],
  [install_source_artifacts=false],
  [install_source_artifacts=true])

AS_IF([test x"$enable_ocamldoc" = "xno"],
  [ocamldoc=""],
  [ocamldoc=ocamldoc])

AS_IF([test x"$enable_flambda" = "xyes"],
  [flambda=true
  AS_IF([test x"$enable_flambda_invariants" = "xyes"],
    [flambda_invariants=true],
    [flambda_invariants=false])],
  [flambda=false
  flambda_invariants=false])

AS_IF([test x"$enable_flat_float_array" = "xno"],
  [flat_float_array=false],
  [AC_DEFINE([FLAT_FLOAT_ARRAY])
  flat_float_array=true])

AS_IF([test "$enable_function_sections" = 'no'],
  [function_sections=false],
  [AS_IF([$function_sections],
    [AC_DEFINE([FUNCTION_SECTIONS])],
    [AS_IF([test "$enable_function_sections" = 'yes'],
      [AC_MSG_ERROR([Function sections are not supported.])],
      [AC_MSG_NOTICE([Disabling function sections.])])])])

AS_IF([test x"$with_afl" = "xyes"],
  [afl=true],
  [afl=false])

AS_IF([test x"$enable_force_safe_string" = "xno"],
  [force_safe_string=false],
  [AC_DEFINE([CAML_SAFE_STRING])
   force_safe_string=true])

AS_IF([test x"$DEFAULT_STRING" = "xunsafe"],
  [default_safe_string=false],
  [default_safe_string=true])

AS_IF([test x"$libdir" = x'${exec_prefix}/lib'],
  [libdir="$libdir"/ocaml])

AS_IF([test x"$mandir" = x'${datarootdir}/man'],
  [mandir='${prefix}/man'])

AS_CASE([$host],
  [*-*-mingw32|*-pc-windows],
    [max_testsuite_dir_retries=1
    AS_CASE([$WINDOWS_UNICODE_MODE],
      [ansi],
        [windows_unicode=0],
      [compatible|""],
        [windows_unicode=1],
      [AC_MSG_ERROR([unexpected windows unicode mode])])],
  [max_testsuite_dir_retries=0
  windows_unicode=0])

# Define default prefix correctly for the different Windows ports
AS_IF([test x"$prefix" = "xNONE"],
  [AS_CASE([$host],
    [i686-w64-mingw32], [prefix='C:/ocamlmgw'],
    [x86_64-w64-mingw32], [prefix='C:/ocamlmgw64'],
    [i686-pc-windows], [prefix='C:/ocamlms'],
    [x86_64-pc-windows], [prefix='C:/ocamlms64'])],
  # XXX sure this should be on host, not unix_or_win32?
  [AS_IF([test x"$unix_or_win32" = "xwin32" \
          && test "$host_vendor-$host_os" != "$build_vendor-$build_os" ],
    [AS_CASE([$build],
      [*-pc-cygwin], [prefix=`cygpath -m "$prefix"`])])])

AS_IF([test x"$enable_stdlib_manpages" != "xno"],
  [stdlib_manpages=true],[stdlib_manpages=false])

oc_cflags="$common_cflags $internal_cflags"
oc_cppflags="$common_cppflags $internal_cppflags -DWINDOWS_UNICODE=$windows_unicode"
host_oc_cflags="$host_common_cflags $host_internal_cflags"
host_oc_cppflags="$host_common_cppflags $host_internal_cppflags -DWINDOWS_UNICODE=$windows_unicode"
AC_SUBST([host_oc_cflags])
AC_SUBST([host_oc_cppflags])
ocamlc_cflags="$common_cflags $sharedlib_cflags"
ocamlc_cppflags="$common_cppflags"
ocamlopt_cflags="$common_cflags"
ocamlopt_cppflags="$common_cppflags"

AC_OUTPUT
