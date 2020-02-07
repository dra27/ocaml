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
AC_INIT([OCaml Runtime System],
        m4_esyscmd([head -n1 ../VERSION | tr -d '\r\n']),
        [caml-list@inria.fr],
        [ocaml-runtime],
        [http://www.ocaml.org])

AC_MSG_NOTICE([Configuring OCaml version AC_PACKAGE_VERSION])

# LT_INIT later will set enable_shared, but it will get the wrong value for MSVC
# so we cache enable_shared here so that ./configure --disable-shared has the
# correct effect for MSVC.
user_enable_shared="$enable_shared"

# Configuration variables

# Command to build executables
# COMBAK This should not include the OC_ variables (and in particular Windows should communicate these rather than overriding mkexe badly)
mkexe="\$(CC) \$(OC_CFLAGS) \$(OC_CPPFLAGS) \$(OC_LDFLAGS)"

# C configuration information is used in three contexts:
#   - Building the runtime
#   - Passed by ocamlc when compiling C files
#   - Passed by ocamlopt when compiling C files
# Flags used for runtime, ocamlc and ocamlopt
common_cflags=''
common_cppflags=''
# Flags used specifically for building the runtime
internal_cflags=''
internal_cppflags=''
# Flags used by ocamlc
ocamlc_cflags=''
ocamlc_cppflags=''
# Flags used by ocamlopt
ocamlopt_cflags=''
ocamlopt_cppflags=''
# Flags *always* passed to the linker for making executables
oc_ldflags=''
# toolchain differs slightly from ccomptype in that it's 'msvc', 'mingw' or 'cc'
toolchain='cc'
# Extra CPP flags needed to get flexdll.h used in the runtime
# XXX This should be folded into one or other of the internal CPP flags (care with stdlib/)
iflexdir=''

# Information about the package

## Source directory
AC_CONFIG_SRCDIR([interp.c])

## Directory containing auxiliary scripts used dugring build
AC_CONFIG_AUX_DIR([../build-aux])

## Output variables

# Note: This is present for the flexdll bootstrap where it exposed as the old
# TOOLPREF variable. It would be better if flexdll where updated to require
# WINDRES instead.
AC_SUBST([ac_tool_prefix])
AC_SUBST([exeext])
AC_SUBST([cclibs])
AC_SUBST([instrumented_runtime_libs])
AC_SUBST([OBJEXT])
AC_SUBST([arch])
AC_SUBST([arch64])
AC_SUBST([model])
AC_SUBST([system])
AC_SUBST([common_cflags])
AC_SUBST([common_cppflags])
AC_SUBST([internal_cflags])
AC_SUBST([internal_cppflags])
AC_SUBST([systhread_support])
AC_SUBST([unixlib])
AC_SUBST([toolchain])
AC_SUBST([oc_ldflags])
AC_SUBST([iflexdir])
AC_SUBST([supports_shared_libraries])
AC_SUBST([natdynlinkopts])
AC_SUBST([cc_has_debug_prefix_map])
AC_SUBST([as_has_debug_prefix_map])
AC_SUBST([pthread_link])
AC_SUBST([bfd_cppflags])
AC_SUBST([bfd_ldflags])
AC_SUBST([bfd_ldlibs])
AC_SUBST([asm_cfi_supported])
AC_SUBST([sharedlib_cflags])
AC_SUBST([rpath])
AC_SUBST([mksharedlib])
AC_SUBST([mkmaindll])
AC_SUBST([mksharedlibrpath])
AC_SUBST([libunwind_available])
AC_SUBST([libunwind_include_flags])
AC_SUBST([libunwind_link_flags])
AC_SUBST([flexdll_chain])
AC_SUBST([flexlink_flags])
AC_SUBST([PACKLD])
AC_SUBST([stdlib_manpages])

## Generated files

AC_CONFIG_FILES([vars.sh])
AC_CONFIG_HEADERS([caml/m.h])
AC_CONFIG_HEADERS([caml/s.h])

# Checks for system types

AC_CANONICAL_BUILD
AC_CANONICAL_HOST
AC_CANONICAL_TARGET

# C compiler configuration

AC_SUBST([CC])        # Final value of CC is determined here (MSVC override)
AC_SUBST([ccomptype]) # 'msvc' (Microsoft C) or 'cc' (all others)
AC_SUBST([S])         # Extension to use for assembly code files
AC_SUBST([SO])        # Extension of dynamic libraries
AC_SUBST([outputexe]) # Exact parameter to prefix an executable name with for CC
AC_SUBST([outputobj]) # Exact parameter to prefix an object name with for CC
AC_SUBST([syslib])    # make macro generating the parameter to link with $(1)
AC_SUBST([unix_or_win32]) # 'win32' for MSVC/mingw-w64 and 'unix' otherwise
AC_SUBST([unixlib])   # The directory containing the Unix library
AC_SUBST([exeext])    # The extension to add to executables

AS_CASE([$build],
  [*-pc-windows],
    [CC=cl # COMBAK It feels like CC should only be set if not already set, rather than forcibly overridden? X-Compilation will require context switching the C compiler anyway
    ccomptype='msvc'
    S='asm'
    SO='dll'
    outputexe='-Fe'
    outputobj='-Fo'
    syslib='$(1).lib'],
  [ccomptype='cc'
  S='s'
  SO='so'
  outputexe='-o $(EMPTY)'
  outputobj='-o $(EMPTY)'
  syslib='-l$(1)'])
AS_CASE([$build],
  [*-*-mingw32|*-pc-windows],
    [unix_or_win32='win32'
    unixlib='win32unix'],
  [unix_or_win32='unix'
  unixlib='unix'])
AS_CASE([$build],
  [*-*-cygwin*|*-*-mingw32|*-pc-windows],
    [exeext='.exe'],
  [exeext=''])

# Initialization of libtool
# Allow the MSVC linker to be found even if ld isn't installed.
# User-specified LD still takes precedence.
AC_CHECK_TOOLS([LD],[ld link])
# libtool expects host_os=mingw for native Windows
old_host_os=$host_os
AS_IF([test "$host_os" = 'xwindows'],[host_os=mingw])
LT_INIT
host_os=$old_host_os

# Extracting information from libtool's configuration
AC_SUBST([AR])        # Exported as ARCMD
AC_SUBST([RANLIB])    # Command used in the build system for ranlib
AC_SUBST([RANLIBCMD]) # Command used by ocamlmklib and ocamlopt
AC_SUBST([mklib])     # make macro to build library $(1) containing $(2)
AC_SUBST([libext])    # Extension of static libraries

# XXX X-Compilation COMBAK Might this be $host?
AS_CASE([$build],
  # In config/Makefile.mingw*, we had:
  # TARGET=i686-w64-mingw32 and x86_64-w64-mingw32
  # TOOLPREF=$(TARGET)-
  # ARCMD=$(TOOLPREF)ar
  # RANLIB=$(TOOLPREF)ranlib
  # RANLIBCMD=$(TOOLPREF)ranlib
  # However autoconf and libtool seem to use ar and ranlib
  # So we let them do, at the moment
  [*-pc-windows],
    [
      libext='lib'
      AR=''; RANLIB='true'; RANLIBCMD=''
      LD="$LD -lib -nologo"
      AS_IF([test "$host_cpu" = 'x86_64' ],[LD="$LD -machine:AMD64"])
      mklib="$LD -out:\$(1) \$(2)"
    ],
  [
    # $RANLIB must be a command; in most cases RANLIBCMD can be empty
    # XXX COMBAK The handling of RANLIBCMD in the drivers is a mess
    AS_IF([test -n "$RANLIB" ],
      [RANLIBCMD="$RANLIB"],
      [RANLIB="$AR rs"; RANLIBCMD=''])
    mklib="rm -f \$(1) && $AR rc \$(1) \$(2) && $RANLIB \$(1)"
  ])

## Find vendor of the C compiler
OCAML_CC_VENDOR

# Determine how to call the C preprocessor directly.
# Most of the time, calling the C preprocessor through the C compiler is
# desirable and even important.
# In some cases, though, we want to use the C preprocessor only to
# expand macros. In such cases, it is much more convenient to be able
# to invoke it directly rather than through the C compiler, for instance
# because, when invoked directly, the C preprocessor does not require
# to be invoked on a file with a '.c' extension
# We thus figure out how to invoke the C preprocessor directly but
# let the CPP variable untouched, except for the MSVC port where we set it
# manually to make sure the backward compatibility is preserved
AC_SUBST([CPP])
AS_CASE([$ocaml_cv_cc_vendor],
  [xlc-*],
    [CPP="$CC -E -qnoppline"], # suppress incompatible XLC line directives
  [msvc-*],
    [CPP="$CC -nologo -EP"])

# Checks for programs

## Check for the C compiler: done by libtool
## AC_PROG_CC

## Check for C99 support: done by libtool
## AC_PROG_CC_C99

## Determine which flags to use for the C compiler

# Initialise $internal_cflags with warnings
AS_CASE([$ocaml_cv_cc_vendor],
  [xlc-*],
    [internal_cflags='-qflag=i:i' # all warnings enabled
     warn_error=''],
  [msvc-*],
    [internal_cflags=''
     warn_error='-WX'],
  [internal_cflags='-Wall'
   warn_error='-Werror'])

# Enable warnings as errors on development builds
AS_CASE([AC_PACKAGE_VERSION],
  [*+dev*],
    [APPEND_FLAG([internal_cflags], [$warn_error])])

# We select high optimization levels, provided we can turn off:
# - strict type-based aliasing analysis (too risky for the OCaml runtime)
# - strict no-overflow conditions on signed integer arithmetic
#   (the OCaml runtime assumes Java-style behavior of signed integer arith.)
# Concerning optimization level, -O3 is somewhat risky, so take -O2.
# Concerning language version, gnu99 is ISO C99 plus GNU extensions
# that are often used in standard headers.  Older GCC versions
# defaults to gnu89, which is not C99.  Clang defaults to gnu99 or
# gnu11, which is fine.

# Note: the vendor macro can not recognize MinGW because it calls the
# C preprocessor directly so no compiler specific macro like __MING32__
# is defined. We thus catch MinGW first by looking at host and examine
# the vendor only as a fall-back. We could put tis part of the logic
# in the macro itself, too
# XXX TODO inject user-supplied CFLAGS here?
add_cflags=''
AS_CASE([$build],
  [*-*-mingw32],
    [# TODO: see whether the code can be fixed to avoid -Wno-unused
    add_cflags='-Wno-unused'
    common_cflags='-O -mms-bitfields'
    internal_cppflags='-DUNICODE -D_UNICODE'],
  [AS_CASE([$ocaml_cv_cc_vendor],
    [clang-*],
      [common_cflags='-O2 -fno-strict-aliasing -fwrapv'
      add_cflags='-fno-common'],
    [gcc-[012]-*],
      # Some versions known to miscompile OCaml, e,g, 2.7.2.1, some 2.96.
      # Plus: C99 support unknown.
      [AC_MSG_ERROR([This version of GCC is too old.
        Please use GCC version 4.2 or above.])],
    [gcc-3-*|gcc-4-[01]],
      # No -fwrapv option before GCC 3.4.
      # Known problems with -fwrapv fixed in 4.2 only.
      [AC_MSG_WARN([This version of GCC is rather old.
        Reducing optimization level."])
      AC_MSG_WARN([Consider using GCC version 4.2 or above.])
      common_cflags='-std=gnu99 -O'],
    [gcc-4-*],
      [common_cflags="-std=gnu99 -O2 -fno-strict-aliasing -fwrapv \
-fno-builtin-memcmp"],
    [gcc-*],
      [common_cflags='-O2 -fno-strict-aliasing -fwrapv'
      add_cflags='-fno-common'],
    [msvc-*],
      [common_cflags='-nologo -O2 -Gy- -MD'
      common_cppflags='-D_CRT_SECURE_NO_DEPRECATE'
      internal_cppflags='-DUNICODE -D_UNICODE'],
    [xlc-*],
      [common_cflags="-O5 -qtune=balanced -qnoipa -qinline $CFLAGS"
      ],
    [common_cflags='-O'])])

APPEND_FLAG([internal_cflags], [$add_cflags])

PREPEND_FLAG([internal_cppflags], [-DCAML_NAME_SPACE])

# Enable SSE2 on x86 mingw to avoid using 80-bit registers.
AS_CASE([$host],
  [i686-*-mingw32],
    [APPEND_FLAG([internal_cflags], [-mfpmath=sse -msse2])])

# Use 64-bit file offset if possible
# See also AC_SYS_LARGEFILE
# Problem: flags are added to CC rather than CPPFLAGS
AS_CASE([$host],
  [*-*-mingw32|*-pc-windows], [],
  [APPEND_FLAG([common_cppflags], [-D_FILE_OFFSET_BITS=64])])

# Adjust according to target

# For MSVC, autoconf will religiously assume that shared libraries don't
# work - use the previously-cached user_enable_shared to allow this default
# to be corrected.
AS_IF([test "$ccomptype" = 'msvc' -a "$user_enable_shared" != 'no'],
  [enable_shared='yes'])

AC_SUBST([mkexe]) # The command to compile executables (see note mkexe= at top of file)
AC_SUBST([mkexedebugflag]) # The instruction to compile an executable with debugging information enabled

# Flags for building executable files with debugging symbols
mkexedebugflag='-g'
# Win32 (native Windows - i.e. mingw-w64 or MSVC); Cygwin (Cygwin's GCC) or Unix
ostype='Unix'
AS_CASE([$CC,$host],
  [*,*-*-darwin*],
    [mkexe="$mkexe -Wl,-no_compact_unwind" # XXX COMBAK This should be an additional cflag of some kind? or in OC_LDFLAGS?
    AC_DEFINE([HAS_ARCH_CODE32], [1])],
  [*,*-*-haiku*], [mathlib=''], # XXX COMBAK this should be elsewhere
  [*,*-*-cygwin*],
    [AS_CASE([$host],
      [i686-*], [flexdll_chain=cygwin],
      [x86_64-*], [flexdll_chain=cygwin64],
      [AC_MSG_ERROR([unknown cygwin variant])])
    APPEND_FLAG([common_cppflags], [-U_WIN32])
    # XXX COMBAK This should be elsewhere
    AS_IF([test "$enable_shared" = 'yes'],
      [flexlink="flexlink -chain $flexdll_chain -merge-manifest -stack 16777216"
      flexdir=`$flexlink -where | tr -d '\015'`
      AS_IF([test -z "$flexdir"],
        # XXX DRA COMBAK This should be an error if $user_enable_shared = 'yes'
        [AC_MSG_WARN(
          [flexlink not found: native shared libraries will not be available.]
        )
        enable_shared='no'],
        [iflexdir="-I\"$flexdir\""
        mkexe="$flexlink -exe"
        mkexedebugflag='-link -g']
      )],
      [mkexe="$mkexe -Wl,--stack,16777216"
      oc_ldflags='-Wl,--stack,16777216'])
    ostype='Cygwin'],
  [*,*-*-mingw32],
    [AS_IF([test "$enable_shared" = 'yes'], # XXX COMBAK This should be elsewhere (and also have an error for enable_shared = no)
      [AS_CASE([$host],
        [i686-*-*], [flexdll_chain='mingw'],
        [x86_64-*-*], [flexdll_chain='mingw64'])
      flexlink="flexlink -chain $flexdll_chain -merge-manifest -stack 16777216"
      flexdir=`$flexlink -where | tr -d '\015'`
      AS_IF([test -z "$flexdir"], [flexdir='$(ROOTDIR)/flexdll'])
      iflexdir="-I\"$flexdir\""
      mkexedebugflag='-link -g'])
    ostype='Win32'
    toolchain='mingw'
    mkexe='$(FLEXLINK) -exe $(if $(OC_LDFLAGS),-link "$(OC_LDFLAGS)")'
    # XXX COMBAK why is SO here?
    oc_ldflags='-municode'
    SO='dll'],
  [*,*-pc-windows],
    [toolchain='msvc'
    ostype='Win32'
    mkexe='$(FLEXLINK) -exe $(if $(OC_LDFLAGS),-link "$(OC_LDFLAGS)")'
    oc_ldflags='/ENTRY:wmainCRTStartup'
    AS_CASE([$host],
      [i686-pc-windows], [flexdll_chain=msvc],
      [x86_64-pc-windows], [flexdll_chain=msvc64])
    AS_IF([test "$enable_shared" = 'yes'], # XXX COMBAK This should be elsewhere (and also have an error enabled_shared = no)
      [flexlink="flexlink -chain $flexdll_chain -merge-manifest -stack 16777216"
      flexdir=`$flexlink -where | tr -d '\015'`
      AS_IF([test -z "$flexdir"], [flexdir='$(ROOTDIR)/flexdll'])
      iflexdir="-I\"$flexdir\""
      mkexedebugflag=''])],
  [*,x86_64-*-linux*],
    AC_DEFINE([HAS_ARCH_CODE32], [1]),
  [xlc*,powerpc-ibm-aix*],
    [mkexe="$mkexe " # XXX Eh?
     oc_ldflags='-brtl -bexpfull'
    AC_DEFINE([HAS_ARCH_CODE32], [1])],
)

AC_DEFINE_UNQUOTED([OCAML_OS_TYPE], ["$ostype"])

# Checks for libraries

## Mathematical library
AC_CHECK_LIB([m], [cos])

AS_IF([test "$ac_cv_lib_m_cos" = 'yes' ], [mathlib='-lm'], [mathlib=''])

# Checks for header files

AC_CHECK_HEADER([math.h])
AC_CHECK_HEADERS([unistd.h], [AC_DEFINE([HAS_UNISTD])])
AC_CHECK_HEADER([stdint.h], [AC_DEFINE([HAS_STDINT_H])])
AC_CHECK_HEADER([sys/shm.h], [AC_DEFINE([HAS_SYS_SHM_H])])
AC_CHECK_HEADER([dirent.h], [AC_DEFINE([HAS_DIRENT])], [],
  [#include <sys/types.h>])
AC_CHECK_HEADER([sys/select.h], [AC_DEFINE([HAS_SYS_SELECT_H])], [],
  [#include <sys/types.h>])

# Checks for types

## off_t
AC_TYPE_OFF_T

# Checks for structures

# Checks for compiler characteristics

AC_CHECK_SIZEOF(int)
AC_CHECK_SIZEOF(long)
AC_CHECK_SIZEOF(long *)
AC_CHECK_SIZEOF(short)
AC_CHECK_SIZEOF(long long)

AS_IF(
  [test "$ac_cv_sizeof_long_p" = '4' ],
    [bits=32
    arch64=false],
  [test "$ac_cv_sizeof_long_p" = '8' ],
    [bits=64
    arch64=true
    AC_DEFINE([ARCH_SIXTYFOUR], [1])],
  [AC_MSG_ERROR([Neither 32 nor 64 bits architecture.])])

AS_IF([test "$ac_cv_sizeof_int" != '4' && test "$ac_cv_sizeof_long" != '4' \
       && test "$ac_cv_sizeof_short" != '4'],
  [AC_MSG_ERROR([Sorry, we can't find a 32-bit integer type.])])

AS_IF([test "$ac_cv_sizeof_long" != '8' \
       && test "$ac_cv_sizeof_long_long" != '8'],
  [AC_MSG_ERROR([Sorry, we can't find a 64-bit integer type.])])

AC_DEFINE_UNQUOTED([SIZEOF_PTR], [$ac_cv_sizeof_long_p])
AC_DEFINE_UNQUOTED([SIZEOF_LONGLONG], [$ac_cv_sizeof_long_long])

AC_MSG_NOTICE([Target is a $bits bits architecture])

AC_C_BIGENDIAN(
  [AC_DEFINE([ARCH_BIG_ENDIAN], [1])],
  [],
  [AC_MSG_ERROR([could not determine endianness.])],
  [AC_MSG_ERROR([unable to handle universal endianness])]
)

AC_CHECK_ALIGNOF([double])
AC_CHECK_ALIGNOF([long])

AS_IF([! $arch64],
  [AS_CASE([$target_cpu],
    [i686], [],
    [AS_IF([test "$ac_cv_alignof_double" -gt 4],
      [AC_DEFINE([ARCH_ALIGN_DOUBLE], [1])])
    AS_IF([test "$ac_cv_alignof_long" -gt 4],
      [AC_DEFINE([ARCH_ALIGN_LONG], [1])])
    ])])

# Shared library support

supports_shared_libraries=false
sharedlib_cflags=''
mksharedlib='shared-libs-not-available'
rpath=''
mksharedlibrpath=''
natdynlinkopts=''

AS_IF([test "$enable_shared" != 'no'],
  [AS_CASE([$host],
    [*-apple-darwin*],
      [mksharedlib="$CC -shared -flat_namespace -undefined suppress \
                   -Wl,-no_compact_unwind"
      supports_shared_libraries=true],
    [*-*-mingw32],
      [mksharedlib='$(FLEXLINK)'
      mkmaindll='$(FLEXLINK) -maindll'
      supports_shared_libraries=true],
    [*-pc-windows],
      [mksharedlib='$(FLEXLINK)'
      mkmaindll='$(FLEXLINK) -maindll'
      supports_shared_libraries=true],
    [*-*-cygwin*],
      [mksharedlib="$flexlink"
      mkmaindll="$flexlink -maindll"
      supports_shared_libraries=true],
    [powerpc-ibm-aix*],
      [AS_CASE([$CC],
               [xlc*],
               [mksharedlib="$CC -qmkshrobj -G"
                supports_shared_libraries=true])],
    [[*-*-linux*|*-*-freebsd[3-9]*|*-*-freebsd[1-9][0-9]*\
    |*-*-openbsd*|*-*-netbsd*|*-*-dragonfly*|*-*-gnu*|*-*-haiku*]],
      [sharedlib_cflags='-fPIC'
      mksharedlib="$CC -shared"
      oc_ldflags="$oc_ldflags -Wl,-E"
      rpath='-Wl,-rpath,'
      mksharedlibrpath='-Wl,-rpath,'
      natdynlinkopts='-Wl,-E'
      supports_shared_libraries=true])])

AS_IF([test -z "$mkmaindll"], [mkmaindll="$mksharedlib"])

# Try to work around the Skylake/Kaby Lake processor bug.
AS_CASE(["$CC,$host"],
  [*gcc*,x86_64-*|*gcc*,i686-*],
    [OCAML_CC_HAS_FNO_TREE_VRP
    AS_IF([$cc_has_fno_tree_vrp],
      [internal_cflags="$internal_cflags -fno-tree-vrp"])])

OCAML_CC_SUPPORTS_ALIGNED

# Configure the native-code compiler

arch=none
model=default
system=unknown

AS_CASE([$host],
  [[i[3456]86-*-linux*]],
    [arch=i386; system=linux_elf],
  [[i[3456]86-*-*bsd*]],
    [arch=i386; system=bsd_elf],
  [[i[3456]86-*-haiku*]],
    [arch=i386; system=beos],
  [[i[3456]86-*-cygwin]],
    [arch=i386; system=cygwin],
  [[i[3456]86-*-gnu*]],
    [arch=i386; system=gnu],
  [[i[3456]86-*-mingw32]],
    [arch=i386; system=mingw],
  [i686-pc-windows],
    [arch=i386; system=win32],
  [x86_64-pc-windows],
    [arch=amd64; system=win64],
  [[powerpc64le*-*-linux*]],
    [arch=power; model=ppc64le; system=elf],
  [[powerpc*-*-linux*]],
    [arch=power; AS_IF([$arch64],[model=ppc64],[model=ppc]); system=elf],
  [[s390x*-*-linux*]],
    [arch=s390x; model=z10; system=elf],
  [armv6*-*-linux-gnueabihf],
    [arch=arm; model=armv6; system=linux_eabihf],
  [armv7*-*-linux-gnueabihf],
    [arch=arm; model=armv7; system=linux_eabihf],
  [armv8*-*-linux-gnueabihf],
    [arch=arm; model=armv8; system=linux_eabihf],
  [armv8*-*-linux-gnueabi],
    [arch=arm; model=armv8; system=linux_eabi],
  [armv7*-*-linux-gnueabi],
    [arch=arm; model=armv7; system=linux_eabi],
  [armv6t2*-*-linux-gnueabi],
    [arch=arm; model=armv6t2; system=linux_eabi],
  [armv6*-*-linux-gnueabi],
    [arch=arm; model=armv6; system=linux_eabi],
  [armv6*-*-freebsd*],
    [arch=arm; model=armv6; system=freebsd],
  [earmv6*-*-netbsd*],
    [arch=arm; model=armv6; system=netbsd],
  [earmv7*-*-netbsd*],
    [arch=arm; model=armv7; system=netbsd],
  [armv5te*-*-linux-gnueabi],
    [arch=arm; model=armv5te; system=linux_eabi],
  [armv5*-*-linux-gnueabi],
    [arch=arm; model=armv5; system=linux_eabi],
  [arm*-*-linux-gnueabihf],
    [arch=arm; system=linux_eabihf],
  [arm*-*-linux-gnueabi],
    [arch=arm; system=linux_eabi],
  [arm*-*-openbsd*],
    [arch=arm; system=bsd],
  [zaurus*-*-openbsd*],
    [arch=arm; system=bsd],
  [x86_64-*-linux*],
    [arch=amd64; system=linux],
  [x86_64-*-gnu*],
    [arch=amd64; system=gnu],
  [x86_64-*-dragonfly*],
    [arch=amd64; system=dragonfly],
  [x86_64-*-freebsd*],
    [arch=amd64; system=freebsd],
  [x86_64-*-netbsd*],
    [arch=amd64; system=netbsd],
  [x86_64-*-openbsd*],
    [arch=amd64; system=openbsd],
  [x86_64-*-darwin*],
    [arch=amd64; system=macosx],
  [x86_64-*-mingw32],
    [arch=amd64; system=mingw64],
  [aarch64-*-linux*],
    [arch=arm64; system=linux],
  [aarch64-*-freebsd*],
    [arch=arm64; system=freebsd],
  [x86_64-*-cygwin*],
    [arch=amd64; system=cygwin]
)

AC_CHECK_TOOL([DIRECT_LD],[ld])
# The string for PACKLD must be capable of being concatenated with the
# output filename. Don't assume that all C compilers understand GNU -ofoo
# form, so ensure that the definition includes a space at the end (which is
# achieved using the $(EMPTY) expansion trick).
AS_CASE(["$arch,$CC,$system,$model"],
  [amd64,gcc*,macosx,*], [PACKLD='ld -r -arch x86_64 -o $(EMPTY)'],
  [amd64,gcc*,solaris,*], [PACKLD='ld -r -m elf_x86_64 -o $(EMPTY)'],
  [power,gcc*,elf,ppc], [PACKLD='ld -r -m elf32ppclinux -o $(EMPTY)'],
  [power,gcc*,elf,ppc64], [PACKLD='ld -r -m elf64ppc -o $(EMPTY)'],
  [power,gcc*,elf,ppc64le], [PACKLD='ld -r -m elf64lppc -o $(EMPTY)'],
  # For the Microsoft C compiler there must be no space at the end of the
  # string.
  [*,cl,*,*], [PACKLD="$LD -out:"],
  [PACKLD="$DIRECT_LD -r -o \$(EMPTY)"])

# Assembler

AS_IF([test -n "$host_alias"], [toolpref="${host_alias}-"], [toolpref=''])

# We first compute default values for as and aspp
# If values have been given by the user then they take precedence over
# those just computed
# One may want to check whether the user provided values first
# and only compute values if none has been provided

AS_CASE(["$arch,$system"],
  [i386,win32],
    [default_as='ml -nologo -coff -Cp -c -Fo'],
  [amd64,win64],
    [default_as='ml64 -nologo -Cp -c -Fo'],
  [amd64,macosx],
    [AS_CASE([$ocaml_cv_cc_vendor],
      [clang-*],
        [default_as='clang -arch x86_64 -Wno-trigraphs -c'
        default_aspp='clang -arch x86_64 -Wno-trigraphs -c'],
      [default_as="${toolpref}as -arch x86_64"
      default_aspp="${toolpref}gcc -arch x86_64 -c"])],
  [amd64,solaris],
    [default_as="${toolpref}as --64"
    default_aspp="${toolpref}gcc -m64 -c"],
  [i386,solaris],
    [default_as="${toolpref}as"
    default_aspp="${toolpref}gcc -c"],
  [power,elf],
    [AS_CASE([$model],
      [ppc64le],
        [default_as="${toolpref}as -a64 -mpower8"
        default_aspp="${toolpref}gcc -m64 -mcpu=powerpc64le -c"],
      [ppc64],
        [default_as="${toolpref}as -a64 -mppc64"
        default_aspp="${toolpref}gcc -m64 -c"],
      [ppc],
        [default_as="${toolpref}as -mppc"
        default_aspp="${toolpref}gcc -m32 -c"])],
  [s390x,elf],
    [default_as="${toolpref}as -m 64 -march=$model"
    default_aspp="${toolpref}gcc -c -Wa,-march=$model"],
  [arm,freebsd|arm64,freebsd],
    [default_as="${toolpref}cc -c"
    default_aspp="${toolpref}cc -c"],
  [*,dragonfly],
    [default_as="${toolpref}as"
    default_aspp="${toolpref}cc -c"],
  [*,freebsd],
    [default_as="${toolpref}as"
    default_aspp="${toolpref}cc -c"],
  [amd64,*|arm,*|arm64,*|i386,*],
    [default_as="${toolpref}as"
    AS_CASE([$ocaml_cv_cc_vendor],
      [clang-*], [default_aspp="${toolpref}clang -c -Wno-trigraphs"],
      [default_aspp="${toolpref}gcc -c"])])

# Checks for library functions

## Check the semantics of signal handlers
OCAML_SIGNAL_HANDLERS_SEMANTICS

## Check for C99 float ops

# Note: this was disabled on Windows but the autoconf-generated script
# does find the function it is looking for.
# however the fma test does not pass so we disable the feature
# for the moment, to be backward-compatible

AS_CASE([$host],
  [*-*-mingw32|*-pc-windows], [],
  [has_c99_float_ops=true
  AC_CHECK_FUNC([expm1], [], [has_c99_float_ops=false])
  AS_IF([$has_c99_float_ops],
    [AC_CHECK_FUNC([log1p], [], [has_c99_float_ops=false])])
  AS_IF([$has_c99_float_ops],
    [AC_CHECK_FUNC([hypot], [], [has_c99_float_ops=false])])
  AS_IF([$has_c99_float_ops],
    [AC_CHECK_FUNC([fma], [
      AS_CASE([$target],[x86_64-*-cygwin],[],[AC_DEFINE([HAS_WORKING_FMA])])],
      [has_c99_float_ops=false])])
  AS_IF([$has_c99_float_ops],
    [AC_CHECK_FUNC([copysign], [AC_DEFINE([HAS_C99_FLOAT_OPS])])])])

## getrusage
AC_CHECK_FUNC([getrusage], [AC_DEFINE([HAS_GETRUSAGE])])

## times
AC_CHECK_FUNC([times], [AC_DEFINE([HAS_TIMES])])

## secure_getenv and __secure_getenv

saved_CPPFLAGS="$CPPFLAGS"
CPPFLAGS="-D_GNU_SOURCE $CPPFLAGS"

AC_CHECK_FUNC([secure_getenv],
  [AC_DEFINE([HAS_SECURE_GETENV])],
  [AC_CHECK_FUNC([__secure_getenv], [AC_DEFINE([HAS___SECURE_GETENV])])])

CPPFLAGS="$saved_CPPFLAGS"

## issetugid

AC_CHECK_FUNC([issetugid], [AC_DEFINE([HAS_ISSETUGID])])

## clock_gettime, for the instrumented runtime

# XXX COMBAK This is in the wrong script!
## Note: on MinGW, configure finds a clock_gettime and thus the build
# system tries to build the instrumented runtime, which causes
# warnings. For the moment we simply disable it on MinGW
# but this would need to be further investigated
instrumented_runtime_libs=''
AC_SUBST([has_clock_gettime])
AC_SEARCH_LIBS([clock_gettime], [rt],
  [has_clock_gettime=true],
  [has_clock_gettime=false])
AS_IF([$has_clock_gettime],
  [AS_IF([test "$ac_cv_search_clock_gettime" = 'none required'],
    [instrumented_runtime_libs=''],
    [instrumented_runtime_libs=$ac_cv_search_clock_gettime])])

## Sockets

## TODO: check whether the different libraries are really useful

sockets=false

AS_CASE([$host],
  [*-*-mingw32|*-pc-windows],
    [sockets=true],
  [
    AC_CHECK_FUNC([socket])
    AC_CHECK_FUNC([socketpair])
    AC_CHECK_FUNC([bind])
    AC_CHECK_FUNC([listen])
    AC_CHECK_FUNC([accept])
    AC_CHECK_FUNC([connect])
    sockets=true
  ]
)

AS_IF([$sockets], [AC_DEFINE([HAS_SOCKETS])])

## socklen_t in sys/socket.h

AC_CHECK_TYPE(
  [socklen_t],
  [AC_DEFINE([HAS_SOCKLEN_T])], [],
  [#include <sys/socket.h>])

AC_CHECK_FUNC([inet_aton], [AC_DEFINE([HAS_INET_ATON])])

## IPv6 support

ipv6=true

AC_CHECK_TYPE(
  [struct sockaddr_in6], [], [ipv6=false],
[
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
]
)

AS_IF([$ipv6],
  [AC_CHECK_FUNC([getaddrinfo], [], [ipv6=false])])

AS_IF([$ipv6],
  [AC_CHECK_FUNC([getnameinfo], [], [ipv6=false])])

AS_IF([$ipv6],
  [AC_CHECK_FUNC([inet_pton], [], [ipv6=false])])

AS_IF([$ipv6],
  [AC_CHECK_FUNC([inet_ntop], [AC_DEFINE([HAS_IPV6])])])

AC_CHECK_FUNC([rewinddir], [AC_DEFINE([HAS_REWINDDIR])])

AC_CHECK_FUNC([lockf], [AC_DEFINE([HAS_LOCKF])])

AC_CHECK_FUNC([mkfifo], [AC_DEFINE([HAS_MKFIFO])])

AC_CHECK_FUNC([getcwd], [AC_DEFINE([HAS_GETCWD])])

## utime
AC_CHECK_HEADER([sys/types.h],
  [AC_CHECK_HEADER([utime.h],
    [AC_CHECK_FUNC([utime], [AC_DEFINE([HAS_UTIME])])])])

## Note: this was defined in config/s-nt.h but the autoconf macros do not
# seem to detect it properly on Windows so we hardcode the definition
# of HAS_UTIME on Windows but this will probably need to be clarified
AS_CASE([$host],
  [*-*-mingw32|*-pc-windows], [AC_DEFINE([HAS_UTIME])])

AC_CHECK_FUNC([utimes], [AC_DEFINE([HAS_UTIMES])])

AC_CHECK_FUNC([fchmod],
  [AC_CHECK_FUNC([fchown], [AC_DEFINE([HAS_FCHMOD])])])

AC_CHECK_FUNC([truncate],
  [AC_CHECK_FUNC([ftruncate], [AC_DEFINE([HAS_TRUNCATE])])])

## select
AC_CHECK_FUNC([select],
  [AC_CHECK_TYPE([fd_set],
    [AC_DEFINE([HAS_SELECT])
    select=true], [select=false], [
#include <sys/types.h>
#include <sys/select.h>
  ])])

AC_CHECK_FUNC([nanosleep], [AC_DEFINE([HAS_NANOSLEEP])])

AC_CHECK_FUNC([symlink],
  [AC_CHECK_FUNC([readlink],
    [AC_CHECK_FUNC([lstat], [AC_DEFINE([HAS_SYMLINK])])])])

# wait
AC_CHECK_FUNC(
  [waitpid],
  [
    wait=true
    AC_DEFINE([HAS_WAITPID])
  ],
  [wait=false])

AC_CHECK_FUNC(
  [wait4],
  [
    has_wait=true
    AC_DEFINE([HAS_WAIT4])
  ])

## getgroups
AC_CHECK_FUNC([getgroups], [AC_DEFINE([HAS_GETGROUPS])])

## setgroups
AC_CHECK_FUNC([setgroups], [AC_DEFINE([HAS_SETGROUPS])])

## initgroups
AC_CHECK_FUNC([initgroups], [AC_DEFINE([HAS_INITGROUPS])])

## termios

AC_CHECK_HEADER([termios.h],
  [AC_CHECK_FUNC([tcgetattr],
    [AC_CHECK_FUNC([tcsetattr],
      [AC_CHECK_FUNC([tcsendbreak],
        [AC_CHECK_FUNC([tcflush],
          [AC_CHECK_FUNC([tcflow], [AC_DEFINE([HAS_TERMIOS])])])])])])])

## setitimer

AC_CHECK_FUNC([setitimer],
  [
    setitimer=true
    AC_DEFINE([HAS_SETITIMER])
  ],
  [setitimer=false])

## gethostname
# Note: detection fails on Windows so hardcoding the result
# (should be debugged later)
AS_CASE([$host],
  [*-*-mingw32|*-pc-windows], [AC_DEFINE([HAS_GETHOSTNAME])],
  [AC_CHECK_FUNC([gethostname], [AC_DEFINE([HAS_GETHOSTNAME])])])

## uname

AC_CHECK_HEADER([sys/utsname.h],
  [AC_CHECK_FUNC([uname], [AC_DEFINE([HAS_UNAME])])])

## gettimeofday

AC_CHECK_FUNC([gettimeofday],
  [
    gettimeofday=true
    AC_DEFINE([HAS_GETTIMEOFDAY])
  ],
  [gettimeofday=false])

## mktime

AC_CHECK_FUNC([mktime], [AC_DEFINE([HAS_MKTIME])])

## setsid

AS_CASE([$host],
  [*-cygwin|*-*-mingw32|*-pc-windows], [],
  [AC_CHECK_FUNC([setsid], [AC_DEFINE([HAS_SETSID])])])

## putenv

AC_CHECK_FUNC([putenv], [AC_DEFINE([HAS_PUTENV])])

## newlocale() and <locale.h>
AC_CHECK_HEADER([locale.h],
  [AC_CHECK_FUNC([newlocale],
    [AC_CHECK_FUNC([freelocale],
      [AC_CHECK_FUNC([uselocale], [AC_DEFINE([HAS_LOCALE_H])])])])])
# Note: the detection fails on msvc so we hardcode the result
# (should be debugged later)
AS_CASE([$host],
  [*-pc-windows], [AC_DEFINE([HAS_LOCALE_H])])

AC_CHECK_HEADER([xlocale.h],
  [AC_CHECK_FUNC([newlocale],
    [AC_CHECK_FUNC([freelocale],
      [AC_CHECK_FUNC([uselocale], [AC_DEFINE([HAS_XLOCALE_H])])])])])

## strtod_l
AC_CHECK_FUNC([strtod_l], [AC_DEFINE([HAS_STRTOD_L])])
# Note: not detected on MSVC so hardcoding the result
# (should be debugged later)
AS_CASE([$host],
  [*-pc-windows], [AC_DEFINE([HAS_STRTOD_L])])

# #COMBAK DRA the issue here is checking for -ldl - this should just be done with the rest of it above
## shared library support
AC_SUBST([dynlink_libs])
AS_IF([$supports_shared_libraries],
  [AS_CASE([$host],
    [*-*-mingw32|*-pc-windows],
      [supports_shared_libraries=true; dynlink_libs=''],
    [AC_CHECK_FUNC([dlopen],
      [supports_shared_libraries=true dynlink_libs=''],
      [AC_CHECK_LIB([dl], [dlopen],
        [supports_shared_libraries=true dynlink_libs='-ldl'],
        [supports_shared_libraries=false])])])],
  [supports_shared_libraries=false])

AS_IF([$supports_shared_libraries],
  [AC_MSG_NOTICE([Dynamic loading of shared libraries is supported.])
  AC_DEFINE([SUPPORT_DYNAMIC_LINKING])],
  AS_IF([test "$enable_shared" = 'no'],
    [AC_MSG_NOTICE([Dynamic loading of shared libraries is not supported.])],
    [AC_MSG_ERROR([Dynamic loading of shared libraries is not available.])]))

## mmap

AC_CHECK_HEADER([sys/mman.h],
  [AC_CHECK_FUNC([mmap],
    [AC_CHECK_FUNC([munmap], [AC_DEFINE([HAS_MMAP])])])])

## pwrite

AC_CHECK_FUNC([pwrite], [AC_DEFINE([HAS_PWRITE])])

## -fdebug-prefix-map support by the C compiler
AS_CASE([$CC,$host],
  [*,*-*-mingw32], [cc_has_debug_prefix_map=false],
  [*,*-pc-windows], [cc_has_debug_prefix_map=false],
  [xlc*,powerpc-ibm-aix*], [cc_has_debug_prefix_map=false],
  [OCAML_CC_HAS_DEBUG_PREFIX_MAP])

## Does stat support nanosecond precision

AC_CHECK_MEMBER([struct stat.st_atim.tv_nsec],
  [stat_has_ns_precision=true
  AC_DEFINE([HAS_NANOSECOND_STAT], [1])],
  [],
  [
    AC_INCLUDES_DEFAULT
    #include <sys/stat.h>
  ])

AS_IF([! $stat_has_ns_precision],
  [AC_CHECK_MEMBER([struct stat.st_atimespec.tv_nsec],
    [stat_has_ns_precision=true
    AC_DEFINE([HAS_NANOSECOND_STAT], [2])],
    [],
    [
      AC_INCLUDES_DEFAULT
      #include <sys/stat.h>
    ])])

AS_IF([! $stat_has_ns_precision],
  [AC_CHECK_MEMBER([struct stat.st_atimensec],
    [stat_has_ns_precision=true
    AC_DEFINE([HAS_NANOSECOND_STAT], [3])],
    [],
    [
      AC_INCLUDES_DEFAULT
      #include <sys/stat.h>
    ])])

AS_IF([$stat_has_ns_precision],
  [AC_MSG_NOTICE([stat supports nanosecond precision])],
  [AC_MSG_NOTICE([stat does not support nanosecond precision])])

# Number of arguments of gethostbyname_r

AX_FUNC_WHICH_GETHOSTBYNAME_R

AS_CASE([$ac_cv_func_which_gethostbyname_r],
  [six], [AC_DEFINE([HAS_GETHOSTBYNAME_R],[6])],
  [five], [AC_DEFINE([HAS_GETHOSTBYNAME_R],[5])],
  [three], [AC_MSG_WARN([OCaml does not support this variant])])

# Number of arguments of gethostbyaddr_r

AX_FUNC_WHICH_GETHOSTBYADDR_R

AS_CASE([$ac_cv_func_which_gethostbyaddr_r],
  [eight], [AC_DEFINE([HAS_GETHOSTBYADDR_R],[8])],
  [seven], [AC_DEFINE([HAS_GETHOSTBYADDR_R],[7])])

## mkstemp

AC_CHECK_FUNC([mkstemp], [AC_DEFINE([HAS_MKSTEMP])])

## nice

AC_CHECK_FUNC([nice], [AC_DEFINE([HAS_NICE])])

## dup3

AC_CHECK_FUNC([dup3], [AC_DEFINE([HAS_DUP3])])

## pipe2

AC_CHECK_FUNC([pipe2], [AC_DEFINE([HAS_PIPE2])])

## accept4

AC_CHECK_FUNC([accept4], [AC_DEFINE([HAS_ACCEPT4])])

## getauxval

AC_CHECK_FUNC([getauxval], [AC_DEFINE([HAS_GETAUXVAL])])

## execvpe

AC_CHECK_FUNC([execvpe], [AC_DEFINE([HAS_EXECVPE])])

## ffs or _BitScanForward

AC_CHECK_FUNC([ffs], [AC_DEFINE([HAS_FFS])])
AC_CHECK_FUNC([_BitScanForward], [AC_DEFINE([HAS_BITSCANFORWARD])])

## Determine if system stack overflows can be detected

AC_MSG_CHECKING([whether stack overflows can be detected])

AS_CASE([$arch,$system],
  [i386,linux_elf|amd64,linux|amd64,macosx \
    |amd64,openbsd|i386,bsd_elf],
    [AC_DEFINE([HAS_STACK_OVERFLOW_DETECTION])
    AC_MSG_RESULT([yes])],
  [AC_MSG_RESULT([no])])

## Determine if the POSIX threads library is supported

AS_CASE([$host],
 [*-*-mingw32|*-pc-windows],
   [systhread_support=true
   pthread_link=''
   AC_MSG_NOTICE([the Win32 threads library is supported])],
 [AX_PTHREAD(
   [systhread_support=true
   AS_CASE([$host],
     [*-*-solaris*], [pthread_link='-lpthread -lposix4'],
     [*-*-haiku*], [pthread_link=''],
     [pthread_link='-lpthread'])
   saved_CFLAGS="$CFLAGS"
   saved_LIBS="$LIBS"
   CFLAGS="$CFLAGS $PTHREAD_CFLAGS"
   LIBS="$LIBS $pthread_link"
   AC_CHECK_FUNC([sigwait], [AC_DEFINE([HAS_SIGWAIT])])
   LIBS="$saved_LIBS"
   CFLAGS="$saved_CFLAGS"
   AC_MSG_NOTICE([the POSIX threads library is supported])])])

AC_SUBST([AS])
AC_SUBST([ASPP])
AS_IF([test -z "$AS"], [AS="$default_as"])

AS_IF([test -z "$ASPP"], [ASPP="$default_aspp"])

## Does the assembler support debug prefix map and CFI directives
as_has_debug_prefix_map=false
asm_cfi_supported=false
AS_CASE([$host],
 [*-pc-windows], [],
 [OCAML_AS_HAS_DEBUG_PREFIX_MAP
 OCAML_AS_HAS_CFI_DIRECTIVES])

## Check for mmap support for huge pages and contiguous heap
OCAML_MMAP_SUPPORTS_HUGE_PAGES

# libunwind detection

AS_IF([test "$system" = "macosx"],
  [AS_IF([test -n "$LIBUNWIND_INCLUDE_DIR" -o -n "$LIBUNWIND_LIB_DIR"],
    [AC_MSG_WARN(m4_normalize([
      On MacOSX, specifying paths for libunwind headers or libraries
      is strongly discouraged.  It is recommended to rely on the
      defaults provided by the configure script
    ]))])])

AS_IF([test -n "$LIBUNWIND_INCLUDE_DIR"],
  [libunwind_include_flags="-I$LIBUNWIND_INCLUDE_DIR"],
  [libunwind_include_flags=""])

AS_CASE(["$system"],
  ["macosx"], [libunwind_link_flags="-framework System"],
  [libunwind_link_flags="-lunwind -lunwind-x86_64"])

AS_IF([test -n "$LIBUNWIND_LIB_DIR"x],
  [PREPEND_FLAG(libunwind_link_flags, [-L$LIBUNWIND_LIB_DIR])])

OCAML_CHECK_LIBUNWIND

AC_SUBST([libunwind_available])

# We need unwinding information at runtime, but since we use
# -no_compact_unwind, we also need -keep_dwarf_unwind otherwise
# the OS X linker will chuck away the DWARF-like (.eh_frame)
# information.  (Older versions of OS X don't provide this.)

AC_SUBST([function_sections])
AS_CASE([$arch],
 [amd64|i386|arm64], # not supported on arm32, see issue #9124.
  [AS_CASE([$target],
     [*-cygwin*|*-mingw*|*-windows|*-apple-darwin*],
       [function_sections=false;
        AC_MSG_NOTICE([No support for function sections on $target.])],
     [*],
       [AS_CASE([$ocaml_cv_cc_vendor],
         [gcc-[0123]-*|gcc-4-[01234567]],
           [function_sections=false;
           AC_MSG_NOTICE([Function sections are not
           supported in GCC prior to version 4.8.])],
         [clang-[012]-*|clang-3-[01234]],
           [function_sections=false;
           AC_MSG_NOTICE([Function sections are not supported
           in Clang prior to version 3.5.])],
         [gcc-*|clang-*],
           [function_sections=true;
           # XXX COMBAK This is not correct - the flags should be added only if enabled
           internal_cflags="$internal_cflags -ffunction-sections"],
         [*],
           [function_sections=false;
           AC_MSG_NOTICE([Function sections are not supported by
           $ocaml_cv_cc_vendor.])])])],
 [function_sections=false])

# XXX DRA COMBAK Isn't/shouldn't this be done earlier?
AS_CASE([$host],
  [*-*-mingw32],
    [cclibs="$cclibs -lws2_32 -lversion"],
  [*-pc-windows],
    [cclibs="$cclibs advapi32.lib ws2_32.lib version.lib"],
  [cclibs="$cclibs $mathlib"])

# Define flexlink chain and flags correctly for the different Windows ports
# XXX COMBAK DRA Isn't this done above?
AS_CASE([$host],
  [i686-w64-mingw32],
    [flexdll_chain='mingw'
    flexlink_flags="-chain $flexdll_chain -stack 16777216"],
  [x86_64-w64-mingw32],
    [flexdll_chain='mingw64'
    flexlink_flags="-chain $flexdll_chain -stack 33554432"],
  [i686-pc-windows],
    [flexdll_chain='msvc'
    flexlink_flags='-merge-manifest -stack 16777216'],
  [x86_64-pc-windows],
    [flexdll_chain='msvc64'
    flexlink_flags='-x64 -merge-manifest -stack 33554432'])


# Define a few macros that were defined in config/m-nt.h
# but whose value is not guessed properly by configure
# (all this should be understood and fixed)
AS_CASE([$host],
  [*-*-mingw32|*-pc-windows],
    [AC_DEFINE([HAS_BROKEN_PRINTF])
    AC_DEFINE([HAS_STRERROR])
    AC_DEFINE([HAS_IPV6])
    AC_DEFINE([HAS_NICE])])

AC_OUTPUT
