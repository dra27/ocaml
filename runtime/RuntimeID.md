# RuntimeID

## Background

The RuntimeID is a sequence of 4 characters appended with a hyphen to the name
of the runtime (i.e. `ocamlrun-xxxx`, `ocamlrund-xxxx`, etc.) and the names of
C stub libraries (i.e. `dllunix-xxxx.so`, etc.). It was introduced in
OCaml 4.13, but the scheme is designed to be compatible with OCaml 3.12+.

The purpose of the RuntimeID is to allow for reliable path-based searching (both
executable `PATH`-search for the runtime and DLL `CAML_LD_LIBRARY_PATH`-search
for stub libraries). For the runtime, this allows bytecode executable headers to
fall back to a `PATH`-search if `ocamlrun` is moved. For stubs, it means that
when `CAML_LD_LIBRARY_PATH` points to the `stublibs` directory of a different
compiler that the DLLs in it will be ignored by a bytecode executable and it
will continue to search for the _correct_ `dllunix.so`, rather than stopping on
the first one it finds.

## Scheme

**XXX Fill in example below**

All versions of ocamlrun since 3.12.0 have supported the `-vnum` argument.
Beginning with OCaml 4.13.0, the `-config` argument is also supported, so the
principal requirement for the RuntimeID is its uniqueness, rather than its ease
of encoding/decoding by humans (i.e. faced with **example here** you can always run **example here** `-vnum` to find out what it is, and potentially **example here** `-config` to get a precise configuration list)

The RuntimeID is 24 bits encoded using Base64. Since the RuntimeID will be used
in filenames, the symbol `/` cannot be used and since `+` is frequently used to
denote versions and variants in opam and elsewhere, the symbols `-` and `=` are
used for `+` and `/`. The RuntimeID will always a multiple of 24 bits, meaning
‘paddings’ is never required (or, at least the padding will always be `A` at the
start). The RuntimeID aims that defaults have no bits set and several sextets
are 0 by default. For aesthetic reasons, the lowercase letters are used before
the uppercase!

The RuntimeID may be determined from a filename by:
 - Stripping the file extension (if present)
 - Taking the longest suffix matching `-[A-Za-z0-9=-]{4}`
 - Discarding the initial hyphen
 - Decoding the remaining string Base64 with the MSB of the resulting word first
   (i.e. extension bits are added to the left)

**XXX Clarification example that a present 24 bit encoding done in 48 bit is NOT valid**

The bits are allocated:

- 0-5: release number, relative to 3.12. This has the visual benefit that the
  last encoded character in the RuntimeID is the same for all configuration of a
  particular version of the runtime (with a further 49 releases possible).
- 6: interpreter supporting 63-bit `int`. A bytecode executable which
  _requires_ 63-bit support (either by having constants which don't fit in a
  31-bit `int` **do we do this?!** or by being forced with the **option name?!** option)
  sets this bit so that a 32-bit `ocamlrun` will never be selected. When a
  64-bit `ocamlrun` is _installed_, two copies are created one with this bit set
  and one without (i.e. it is intentionally not possible to have a bytecode
  executable which _must_ target a 32-bit runtime).
- 7-11: number of the reserved header bits in the header word for profiling
  information. This feature is essentially unused since the removal of Spacetime
  in OCaml 4.12.0, but the feature remains part of the runtime.
- 12: runtime supports shared libraries. As for 64-bit (bit 6), a runtime which
  supports shared libraries is also linked without this bit set. Bytecode
  executables which have a `DLLS` section will have this bit set. Note that a
  bytecode executable which does not itself require shared library support but
  which uses `Dynlink` would be expected to check Dynlink.**this is another PR!!**
  to determine if the runtime actually supports shared libraries. Note that this
  is _not_ set for native code, since the only place it would be used is in
  `libasmrun_shared.so`!
- 13: set if the runtime is configured with `--enable-frame-pointers`. This is
  always unset for bytecode, but affects `libasmrun_shared.so`.
- 14: set if the runtime is configured with `--enable-naked-pointers`
- 15: set if the runtime is configured with `--enable-spacetime`. This is always
  unset for bytecode, but affects `libasmrun_shared.so`. Note that
  `--enable-spacetime` does affect the bytecode RuntimeID through the reserved
  header bits.
- 16: set if the runtime is configured with `--disable-force-safe-string`.
- 17: set if the runtime is configured with `--disable-flat-float-array`.
- 18: set if the runtime is configured with `WINDOWS_UNICODE=compatible` or not
  set at all.
- 19: set if the runtime supports multiple execution domains
- 20: set if the runtime supports effects syntax
- 21-23: at present, unset.

Note that bits 19 and 20 are reserved for use by the Multicore OCaml team, but
are not at present set for any official version of the OCaml compiler.
