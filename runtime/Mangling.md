# File Name Mangling

## Background

OCaml compiler installations exist in isolation. When running the compiler, it
is assumed that the caller will have configured the environment of the compiler
such that files and settings related to other compiler installations will not
interfere.

This is not true of the runtime. For bytecode, multiple different OCaml runtimes
may be "in scope" at the same time. To facilate this, a name mangling scheme is
used for the runtime's files.

## RuntimeID

A RuntimeID is a bitmask describing a given OCaml runtime. Currently, 20 bits
are used; the mangling format is designed to be trivially extensible.

- **Bit 0**: Release bit. This is always set for official released versions of
  OCaml and is never set for development/trunk builds or for customised
  compilers.
- **Bits 1-6**: OCaml release number; little-endian. This is incremented for
  each minor release of the compiler, with OCaml 3.12.0[^1] being release 0. At
  present, the ordering of release numbers matches the semantic ordering of the
  version numbers, but this is not guaranteed and should not be assumed[^2].
- **Bit 7**: Set if the runtime uses 31-bit `int` values.
- **Bit 8**: Set if the runtime does not support shared libraries.
- **Bit 9**: Set if the runtime is configured with `--enable-naked-pointers`.
- **Bits 10-14**: Number of reserved header bits; little-endian. This is the
  value passed to `--enable-reserved-header-bits` when the compiler was
  configured.
- **Bit 15**: Set if the runtime is configured with `--enable-frame-pointers`.
- **Bit 16**: Set if the runtime is configured with `--enable-spacetime`.
- **Bit 17**: Set if the runtime is configured with
  `--disable-force-safe-string`.
- **Bit 18**: Set if the runtime is configured with
  `--disable-flat-float-array`.
- **Bit 19**: Set if the runtime is configured with `WINDOWS_UNICODE=ansi`

The bit description are designed such that the default configuration of the
latest version of the compiler has unset bits.

[^1]: OCaml 3.12.0 was the first version where `ocamlrun` supported the `-vnum`
argument.
[^2]: In particular, should there be any additional releases in the OCaml 4.x
series, these will have higher release numbers than releases already made in the
OCaml 5.x series.

## Masks

A particular configuration of the compiler has one RuntimeID, but this is used
in two different contexts where certain bits are masked out:

1. Bytecode Mask (0xe7fff) is used by `libcamlrun` and masks out the frame
   pointers and spacetime bits since these affect neither the runtime nor code
   generation in bytecode.
2. Native Mask (0xfffff) is used by `libasmrun`. Note that in native code, the
   only place where name mangling is used is natdynlink, and bit 8 is therefore
   _never_ set.

## File Name Mangling

Filenames are mangled in two ways.

"triplet-prefixed" files have the _target_ triplet that the compliler was
prefixed with (e.g. `x86_64-pc-linux-gnu`) prepended with an additional hyphen
(e.g. `x86_64-pc-linux-gnu-ocamlrun`).

"Mask-suffixed" files have (RuntimeID & Mask) encoded in base32 using characters
`[0-9a-v]` appended with a prefixing hyphen (e.g. `ocamlrun-0013`)

Mangling is applied to the name of any file which will be loaded at runtime:

- `ocamlrun` (and variants) are triplet-prefixed and Bytecode-suffixed. A
  symbolic is created both for `ocamlrun` and for `ocamlrun` Byte-suffixed but
  not triplet-prefixed.
- C stub libraries loaded by both the bytecode runtime and bytecode `Dynlink`.
  These are triplet-prefixed and Bytecode-suffixed. The effect is that any
  runtime attempts to load stub libraries compiled for exactly the same runtime.
- Shared versions of the bytecode and native runtimes (`libcamlrun_shared.so`
  and `libasmrun_shared.so`). These are triplet-prefixed and
  Bytecode/Native-suffixed respectively.
