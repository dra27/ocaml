# File Name Mangling

## Background

OCaml compiler installations exist in isolation. When running the compiler, it
is assumed that the caller will have configured the environment of the compiler
such that files and settings related to other compiler installations will not
interfere.

This is not true of the runtime. Shared libraries are loaded from a global
namespace (dynamically loaded bytecode stub libraries and the shared versions of
both the native and bytecode runtimes). To allow programs compiled against
different coinstalled versions of the runtime to be executed, a name mangling
scheme is used for the runtime's executables and shared libraries.

## RuntimeID

A RuntimeID is a bit mask describing a given OCaml runtime. Currently, 20 bits
are used, but the mangling format is intended to be trivially extensible.
Ultimately, the only requirement is that each version and configuration
generates some kind of unique identifier which can then be used in filenames.

- Bit 0 (**dev**): Development bit. This should be set for development versions
  of OCaml or for customised compilers. If it is not set, the compiler should be
  an unaltered release.
- Bits 1-6 (**release**): OCaml release number. This is incremented for each
  minor release of the compiler, with OCaml 3.12.0[^1] being release 0. At
  present, the ordering of release numbers matches the semantic ordering of the
  version numbers, but this is not guaranteed and should not be assumed[^2].
- Bit 7 (**no-flat-float-array**): Set if the runtime is configured with
  `--disable-flat-float-array`.
- Bit 8 (**fp**): Set if the runtime is configured with
  `--enable-frame-pointers`. Affects the **native** runtime only.
- Bit 9 (**tsan**): For OCaml 5.2 onwards, set if the runtime is configured with
  `--enable-tsan`. Prior to OCaml 5.2, set if the runtime is configured with
  `--enable-spacetime` (this option was removed in OCaml 4.12, meaning this bit
  is always unset for OCaml 4.12-5.1). Affects the **native** runtime only.
- Bit 10 (**int31**): Set if the runtime uses 31-bit `int` values (i.e. runtimes
  running on 32-bit systems).
- Bit 11 (**static**): Set if the runtime does not support shared libraries,
  meaning dynamic loading of C code is not supported in bytecode and native
  dynlink is not supported.
- Bit 12 (**no-compression**): For OCaml 5.1 onwards, set if the runtime does
  not support compressed marshalling. Prior to OCaml 5.1, set if the runtime is
  configured with `--enable-naked-pointers` (this bit was always unset for
  OCaml 5.0, since it supports neither naked pointers nor compressed
  marshalling).
- Bit 13 (**mutable-string**): Set if the runtime is configured with
  `--disable-force-safe-string`. This option was removed in OCaml 5.0, and the
  bit is available for re-use. When this bit is unset, strings are guaranteed to
  be immutable.
- Bit 14 (**ansi**): Set if the runtime is configured with the legacy support
  `WINDOWS_UNICODE=ansi`.
- Bits 15-19 (**reserved**): Number of reserved header bits; This is the value
  passed to `--enable-reserved-header-bits` when the compiler was configured.

The bit description are designed such that the default configuration of the
latest version of the compiler has unset bits.

[^1]: OCaml 3.12.0 was the first version where `ocamlrun` supported the `-vnum`
argument.
[^2]: In particular, should there be any additional releases in the OCaml 4.x
series, these will have higher release numbers than releases already made in the
OCaml 5.x series.

## Masks

A particular configuration of the compiler has one RuntimeID, but this is used
in three different contexts where certain bits are masked out:

1. _Bytecode Mask_: masks out bits which are only ever set by the native runtime
   (at present, **fp** and **tsan**).
2. _Native Mask_: masks out bits which are only ever set by the bytecode runtime
   (at present there aren't any).
3. _Zinc Mask_: masks out bits which are not related to bytecode portability.
   Where the _Bytecode_ and _Native_ masks relate to _runtimes_, the _Zinc_ mask
   relates to _bytecode images_. At present, this selects **release** and
   **dev** (a given bytecode image targets a specific version of OCaml),
   **int31**, **static** and **no-compression**. i.e. for a given bytecode
   executable, setting **int31** indicates that the image can be run on a 32-bit
   runtime, setting **static** indicates that the executable does not require
   dynamic loading of C code and setting **no-compression** indicates that it
   does use the compressed marshalling support of the runtime.

The key aspect of the _Zinc Mask_ is that it is computed independently of the
actual configuration of a given compiler, meaning that the boot compiler
(`boot/ocamlc`) is able to compute it without additional external configuration.

## File Name Mangling

Filenames are mangled in two ways. The configuration triplet which the runtime
is configured for (e.g. `x86_64-pc-linux-gnu`) can be used along with Runtime ID
values encoded in base32 using the alphabet `[0-9a-v]` and with the quintets
laid out big-endian.

Mangling is applied to the name of any file which will be loaded at runtime:

- `ocamlrun` (and variants) are triplet-prefixed and Bytecode-suffixed. For
  example, `x86_64-pc-linux-gnu-ocamlrun-005a` is OCaml 5.5 configured with
  `--disable-flat-float-array` on 64-bit Intel/AMD Linux. A symbolic link is
  still created for `ocamlrun` pointing to this mangled name. Additionally, a
  symbolic link is also created for `ocamlrun-001a`, using the Zinc-suffix.
- C stub libraries loaded by both the bytecode runtime and bytecode `Dynlink`
  are triplet- and Bytecode-suffixed. For example,
  `dllunixbyt-x86_64-pc-linux-gnu-005a.so` contains the C stubs for Unix library
  for OCaml 5.5 configured with `--disable-flat-float-array` on 64-bit Intel/AMD
  Linux.
- Shared versions of the bytecode and native runtimes (`libcamlrun_shared.so`
  and `libasmrun_shared.so`) are triplet- and Bytecode/Native-suffixed
  respectively. For example, `libasmrun-x86_64-pc-linux-gnu-00la.so` and
  `libcamlrun-x86_64-pc-linux-gnu-005a.so` are OCaml 5.5 configured with
  `--disable-flat-float-array` and `--enable-tsan` on 64-bit Intel/AMD Linux
  (note the **tsan** not being set for the name of libcamlrun). Additionally,
  symbolic links are also created for `libasmrun_shared.so` and
  `libcamlrun_shared.so`.
