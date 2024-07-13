# "in-prefix" compiler testing

This directory performs tests on the compiler after it has been installed to the
prefix given to `configure`. The test requires at least the Unix library to have
been compiled, and only works if bindir and libdir share a common root directory
(e.g. /usr/bin and /usr/lib/ocaml share a common root of /usr, but /bin and
/lib/ocaml do not share a common root directory). The test needs to be able to
rename this common root directory by adding a suffix ".new". For this reasoa,
the test intentionally uses a non-standard Makefile filename and a specific
target giving `make -f Makefile.test -C testsuite/in_prefix test-in-prefix`. The
test should always restore the common root directory to its original name.

At its most basic level, the test validates the `install` target of the build
system. For this reason, the test driver use command line parameters to be
given the expected configuration of the compiler, rather than probing it (for
example `--with-ocamlopt` is passed, rather than relying on the detection of the
`ocamlopt` binary).

## Testing

The test battery consists of six individual tests:

1. Loading libraries in the bytecode toplevel (skipped for `--disable-shared`)
2. Loading libraries in the native toplevel (skipped for
   `--disable-native-toplevel`)
3. Loading libraries with `dynlink.cma` (skipped for `--disable-shared`)
4. Loading libraries with `dynlink.cmxa` (skipped for `--disabled-shared` or
   `--disable-native-compiler`)
5. Executing any bytecode binaries found in bindir with with `-vnum`
6. Compilation and execution of a `print_endline Config.standard_library`
   application with the fourteen compilation mechanisms (tests requiring the
   shared runtime are skipped for `--disable-shared` or on Windows, where it is
   isn't available and native mode tests are skipped for
   `--disable-native-compiler`):
   - Bytecode/native standard compilation
   - Bytecode compilation with -custom running on the static/shared runtime
   - Bytecode compilation with -output-complete-exe on the static/shared runtime
   - Bytecode/native compilation with -output-obj linked with the static/shared
     runtime
   - Bytecode/native compilation with -output-complete-obj linked with the
     static/shared runtime

Having executed this battery on the configured prefix, the test then renames the
common root directory, appending the suffix `.new`. The programs compiled in the
sixth test are re-run and then the entire battery is executed a second time.

During this second execution, the test harness does whatever is physically
possible to allow these tests to proceed:
- The `OCAMLLIB` environment variable is used to allow the compiler to operate,
  unless the compiler has been configured with `--enable-relative`
- Bytecode executables which will no longer be able to find `ocamlrun` are
  explictly passed to `ocamlrun`. The harness always verifies that this step is
  required by first executing the binary and ensuring that it fails and then
  passing it directly to `ocamlrun`.

## Tests

In these descriptions, the Shims section describes the adjustments necessary for
the second phase of testing after the common root directory has been renamed.

### Loading archives/plugins (.cma / .cmxa / .cmxs) in `ocaml` / `ocamlnat`

Verifies that all the .cma files built from `otherlibs/` (dynlink,
runtime\_events, str, threads and unix) can be loaded in the two toplevels.
This test is skipped on builds which don't support shared libraries.

Exercises:
- `CAML_LD_LIBRARY_PATH` and `ld.conf` logic (locating C stubs)
- ocamlnat's conversion machinery converting dynlink.cmxa to dynlink.cmxs
- `CAMLextern` header attribute for Windows (`RELOC_REL32`, etc.)

Shims:
- On Unix, the bytecode toplevel contains the absolute location of `ocamlrun`,
  so must be explicitly invoked via `ocamlrun`
- Both toplevels contain the absolute location of the Standard Library,
  requiring `OCAMLLIB` to be set, unless the compiler was configured with
  `--enable-relative`

### Loading archives/plugins (.cma / .cmxs) with `Dynlink`

As for the toplevel test, but using the `Dynlink` library.

Shims:
- For a bytecode-only build, `ocamlc` contains the absolute location of
  `ocamlrun`, so must be explicitly invoked via `ocamlrun` (if the native
  compiler is available, then both `ocamlc` and `ocamlopt` will be native
  executables)
- Both compilers contain the absolute location of the Standard Library,
  requiring `OCAMLLIB` to be set, unless the comnpiler was configured with
  `--enable-relative`
- The executable created by `ocamlc` contains the absolute location of
  `ocamlrun`, so must be explicitly invoked via `ocamlrun` and also have
  `OCAMLLIB` adjusted, as that `ocamlrun` contains an absolute path to the
  Standard Library

### Executing installed bytecode binaries with `-vnum`

This test looks for filenames match `flexlink*` and `ocaml*` in bindir. For each
name matched, if the file ends with the bytecode magic number, then that program
is executed with `-vnum`.

Exercises:
- Bytecode executable header and logic in `ocamlc` for computing the "shebang"
  header

Shims:
- On builds with shared library support, all the executables will contain the
  absolute location of `ocamlrun` and will fail to execute
- On builds without shared library support, executables using libraries with
  C stubs (in particular, `ocamldebug` and `ocamldoc`) are compiled with
  `-custom` and do succeed
- The test ensures that executables fail exactly when expected, rather than
  explicitly invoking them via `ocamlrun`. The reason for this is that some of
  the binaries (in particular, `ocamlmktop`) invoke another executable (in
  `ocamlmktop`'s case, `ocamlc`) which will itself fail if `ocamlc` is a
  bytecode executable

### Compilation mechanisms

This battery of tests exercises each of the compilation mechanisms available in
OCaml with a simple test program linked with the `ocamlcommon` library which
displays the location of the Standard Library (as determined by
`Config.standard_library`) and checks whether that directory exists.

Exercises:
- Default linking mode of both `ocamlc` ("tendered bytecode") and `ocamlopt`
  (static executables)
- `-custom` and `-output-complete-exe` modes of `ocamlc` with both the default
  static runtime and the shared runtime (`libcamlrun_shared`/`libasmrun_shared`)
- "Main program in C" linking modes `-output-obj` and `-output-complete-obj`
  with both the static and shared runtimes

Shims:
- As with the `Dynlink` test, on bytecode-only builds the compiler must be
  explicitly invoked via `ocamlrun`
- The executable produced by `ocamlc` by default contains the absolute location
  of `ocamlrun` and so has to be run explicitly via `ocamlrun`
