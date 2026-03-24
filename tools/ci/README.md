# OCaml CI Infrastructure

## Unified CI

During the 5.2 development cycle, the CI configurations were synchronised in
[#12846][], [#12847][], [#12848][] and [#12849][]. This series of PRs focused on
`.github/workflows`, `tools/ci/actions`, `tools/ci-appveyor` and `appveyor.yml`.
Subsequent work has extended this to the Jenkins configurations in
`tools/ci/inria`.

Following those PRs, additional changes to the CI configurations are freely
back-ported. Keeping the CI workflows running for old compilers occasionally
necessitates backporting non-CI related changes, typically because of C compiler
changes. These are:

- [#8650][] backported to 4.08 and 4.09 as a prerequisite for testing with
  `make --warn-undefined-variables`.
- [#9414][] backported to 4.08-4.10 adding `KEEP_TEST_DIR_ON_SUCCESS` support to
  the testsuite, necessary to Jenkins workers.
- [#9437][] backported to 4.08 and 4.09 to fix compilation on modern FreeBSD.
- [#9557][] backported to 4.08-4.10 to fix compilation on modern POWER.
- [98a24eaaeef][] (from [#10831][]) was cherry-picked to 4.08-4.14 in order to
  support [#13065][]. The issue was masked previously because `macos-latest`
  flipped over to an arm64 image, which skips the unwind test for architecture
  reasons; but switching back to amd64 testing re-revealed the problem with the
  script.
- [#9981][] backported to 4.08 and 4.09 to fix linking errors with Clang.
- [#10046][] backported to 4.08-4.11 to compile DLLs with `-static-libgcc` to
  fix compilation with mingw-w64 runtime 8.0.0+.
- [#10148][] backported to 4.11 and 4.12, trivially fixing a GCC warning.
- [#10045][] backported to 4.08-4.12 to allow the C# tests to run on mingw-w64.
- [#9919][] partially backported to 4.10-4.12 as it's a prerequisite of
  [#12577][]. `caml_do_exit` is needed to avoid declaring `caml_sys_exit` with
  two different prototypes; not needed for 4.08 and 4.09, because the change
  affects `-output-complete-exe`, which was introduced in 4.10.
- [#10380][] backported to 4.10-4.12 fixing compilation with non C-locale
  characters in `--prefix` on Windows (4.08 and 4.09 not affected because they
  don't attempt to normalise the prefix).
- [#10835][] backported to 4.08-4.13 to fix 32bit Unix shared compilation.
- [#10723][] backported to 4.08-4.13 to fix compilation on macOS
- [#11100][] backported to 4.08-4.14 to stop linker output from old versions of
  Xcode tools causing unexpected errors in the testsuite.
- [#11675][] backported to 4.08 and 4.10-5.0. This PR indirectly fixed a bug
  that `ocamloptp` is installed even when ocamlopt isn't built.
- [#12231][] was backported to 5.0 (but is not needed in 4.x). It is required in
  order to compile the branch with mingw-w64 11.0, otherwise the testsuite will
  fail with flexdll relocation errors.
- [#12372][] backported to 4.08-4.13 and 5.0 to fix compilation on OpenBSD.
- [#12520][] backported to 4.08-4.13, to provide support for testing
  `configure.ac`.
- [#11861][] and [#12509][] were backported to 5.0 and 4.14's [#12577][] version
  to 4.08-4.13. These are necessary for macOS CI, as clang in C17 mode emits
  warnings otherwise.
- [#12993][] backported from 4.14 to 4.08-4.13 to fix 32bit Unix compilation.
- [#13019][] was backported to 5.1 and 5.0 and 4.14's [#13018][] version to
  4.08-4.13. As of March 2024, this change is required for the testsuite to pass
  when running on Apple silicon to eliminate linker warnings.
- [c9f4c113e5][] was added to 4.08-4.14 to disable the `lib-threads/beat.ml`
  test on macOS only (see [#13339][] for more details).
- [#14607][] backported from 4.14 to 4.11-4.13 to fix RISC-V shared compilation.

## Maintenance notes

PRs which touch GitHub Actions are shown with:

```
git log --first-parent --oneline upstream/trunk -- .github/workflows appveyor.yml tools/ci
```

PRs which are entirely CI-related are simply back-ported as normal with
(`git cherry-pick -x -m1 ...`). PRs which are primarily a feature/fix which
happen to contain a CI change have the commit message altered to
`Unified CI cherry-pick: PR#nnnnn` to make it explicit that the feature itself
hasn't been back-ported.

PRs which have to be back-ported in order to allow CI to work are listed above,
and do not have the GitHub PR number "neutered" in commit messages.

GitHub insists on spamming GitHub PR conversations for every single rebase while
testing the branches on a fork. While testing the branches, it's worth neutering
all references to PRs in the commit messages (PR#xxxxx, rather than #xxxxx) and
changing them just before the final push to upstream. In the final version of
the branch, only back-ported features should have the `PR#` changed back to `#`.

Last sync'd: 20-Mar-2026 with #14612

## Branch differences

As far as possible, this process keeps `.github/workflows`, `appveyor.yml` and
`tools/ci` are kept in sync, with the exception on all release branches of
`.github/workflows/stale.yml`, which is deleted early after branching.
Naturally, features not present in older versions of OCaml can be neither tested
nor relied on. In general, CI workflows and supporting scripts are backported,
but then minimally disabled, as this allows subsequent changes on trunk to be
mechanically cherry-picked. Each branch can be compared with

```
git diff upstream/5.5 upstream/trunk -- .github/workflows appveyor.yml tools/ci
```

The differences on each branch are:

trunk:
- [#14421][] allows `sockaddr_cxx.ml` to run on Jenkins
5.5
- [#14240][] allows hacks around `pthread_cancel` to be removed from
  `build-cross.yml`
- Relocatable OCaml ([#14014][], [#14244][], [#14245][] and [#14246][]) add
  various matrix tests
- [#14310][] requires the addition of a C++ compiler in CI
- [#14424][] allows `--disable-dependency-generation` to be used more sparingly
- [#14563][] requires updates to the remove-sinh-primitive.patch used to test
  the bootstrap
5.4
- [#13199][] (and others) add debugger testing in CI
- [#13431][] adds `parsetree-change.yml`
- [#13458][] adds `multicoretests.yml`
- [#13526][] adds `build-cross.yml`
- [#13667][] adds `--enable-codegen-invariants`
5.3
- [#12904][] enables the TSAN workflow in CI
- [#12954][] means `build-msvc.yml` actually builds MSVC and requires
  winpthreads support in Jenkins
- [#13293][] improves the sanitizers Jenkins check
- [#13668][] adds a requirement for `luatex` for building the manual
5.2
- [#12321][] requires a tweak to AppVeyor for rebuilding ocamltest
- [#12514][] allows the Cygwin testsuite to be run on a CRLF checkout
- [#12644][] re-enables TSAN testing on Jenkins
- [#12652][] changes the way the magic numbers are bumped
- [#12843][] means i386 testing can switch to Debian 13 (and GNU make 4.4.1)
5.1
- [#11144][] allows frame pointers mode to be tested in Jenkins
- [#11642][] allows Cygwin to be tested in CI
5.0
- OCaml 5.x workflow alterations
- [#10926][] allows otherlibs C symbol names to be checked in CI
- [#11294][] means autoconf 2.69 no longer has to be installed in CI
- [#11389][] switched AppVeyor testing to use its Visual Studio 2022 image
4.14
- [#10690][] adds `--enable-native-toplevel`, replacing the manual compilation
  of `ocamlnat`
4.13
- [#944][] updates to the remove-sinh-primitive.patch used to test the bootstrap
- [#1400][] adds `--enable-cmm-invariants`
- [#9996][] changes the way the API documentation build commands are invoked
- [#10135][] means flexdll no longer has to be explicitly built on AppVeyor and
  Jenkins
- [#10336][] restores CI checking of the manual
4.12
- [#9332][] adds `--disable-dependency-generation`
- [#9625][] adds `--enable-warn-error`, removing the need for configuration
  hacks in AppVeyor
- [#9669][] adds macOS arm64 support
- [#9745][] synchronises the labelled/unlabelled standard library interfaces
- [#9824][] allows the sanitizers script to configure the compiler less hackily
- [#9927][] restores shared library support in Cygwin64
- [#10063][] re-enables Solaris support
4.11
- [#9250][] adds `--enable-ocamltest` (prior to that ocamltest was guaranteed to
  be built)
- [#9441][] adds RISC-V support
- [#10026][] macOS arm64 support was only applied to 4.10
4.10
- [#8790][] adds case-insensitive name-collision checks to the manual
- [#8835][] adds `--disable-stdlib-manpages`
- [#8951][] adds a default `Makefile` target to the compiler
- [#10026][] backports macOS arm64 from [#9669][] in 4.12
4.09
- [#2289][] removes the vmthreads library (a non-obvious side-effect of this is
  that it fixes `make alldepend` on Windows)
- [#2318][] removes the graphics library
- [#8537][] makes flexdll/flexlink.exe a normal executable, removing a special
  case in the AppVeyor script

[#944]: https://github.com/ocaml/ocaml/pull/944
[#1400]: https://github.com/ocaml/ocaml/pull/1400
[#2289]: https://github.com/ocaml/ocaml/pull/2289
[#2318]: https://github.com/ocaml/ocaml/pull/2318
[#8537]: https://github.com/ocaml/ocaml/pull/8537
[#8650]: https://github.com/ocaml/ocaml/pull/8650
[#8790]: https://github.com/ocaml/ocaml/pull/8790
[#8835]: https://github.com/ocaml/ocaml/pull/8835
[#8951]: https://github.com/ocaml/ocaml/pull/8951
[#9250]: https://github.com/ocaml/ocaml/pull/9250
[#9332]: https://github.com/ocaml/ocaml/pull/9332
[#9414]: https://github.com/ocaml/ocaml/pull/9414
[#9437]: https://github.com/ocaml/ocaml/pull/9437
[#9441]: https://github.com/ocaml/ocaml/pull/9441
[#9557]: https://github.com/ocaml/ocaml/pull/9557
[#9625]: https://github.com/ocaml/ocaml/pull/9625
[#9669]: https://github.com/ocaml/ocaml/pull/9669
[#9745]: https://github.com/ocaml/ocaml/pull/9745
[#9824]: https://github.com/ocaml/ocaml/pull/9824
[#9919]: https://github.com/ocaml/ocaml/pull/9919
[#9927]: https://github.com/ocaml/ocaml/pull/9927
[#9981]: https://github.com/ocaml/ocaml/pull/9981
[#9996]: https://github.com/ocaml/ocaml/pull/9996
[#10026]: https://github.com/ocaml/ocaml/pull/10026
[#10045]: https://github.com/ocaml/ocaml/pull/10045
[#10046]: https://github.com/ocaml/ocaml/pull/10046
[#10063]: https://github.com/ocaml/ocaml/pull/10063
[#10135]: https://github.com/ocaml/ocaml/pull/10135
[#10148]: https://github.com/ocaml/ocaml/pull/10148
[#10336]: https://github.com/ocaml/ocaml/pull/10336
[#10380]: https://github.com/ocaml/ocaml/pull/10380
[#10690]: https://github.com/ocaml/ocaml/pull/10690
[#10723]: https://github.com/ocaml/ocaml/pull/10723
[#10831]: https://github.com/ocaml/ocaml/pull/10831
[#10835]: https://github.com/ocaml/ocaml/pull/10835
[#10926]: https://github.com/ocaml/ocaml/pull/10926
[#11100]: https://github.com/ocaml/ocaml/pull/11100
[#11144]: https://github.com/ocaml/ocaml/pull/11144
[#11294]: https://github.com/ocaml/ocaml/pull/11294
[#11389]: https://github.com/ocaml/ocaml/pull/11389
[#11642]: https://github.com/ocaml/ocaml/pull/11642
[#11675]: https://github.com/ocaml/ocaml/pull/11675
[#11861]: https://github.com/ocaml/ocaml/pull/11861
[#12231]: https://github.com/ocaml/ocaml/pull/12231
[#12321]: https://github.com/ocaml/ocaml/pull/12321
[#12372]: https://github.com/ocaml/ocaml/pull/12372
[#12509]: https://github.com/ocaml/ocaml/pull/12509
[#12514]: https://github.com/ocaml/ocaml/pull/12514
[#12520]: https://github.com/ocaml/ocaml/pull/12520
[#12577]: https://github.com/ocaml/ocaml/pull/12577
[#12644]: https://github.com/ocaml/ocaml/pull/12644
[#12652]: https://github.com/ocaml/ocaml/pull/12652
[#12843]: https://github.com/ocaml/ocaml/pull/12843
[#12846]: https://github.com/ocaml/ocaml/pull/12846
[#12847]: https://github.com/ocaml/ocaml/pull/12847
[#12848]: https://github.com/ocaml/ocaml/pull/12848
[#12849]: https://github.com/ocaml/ocaml/pull/12849
[#12904]: https://github.com/ocaml/ocaml/pull/12904
[#12954]: https://github.com/ocaml/ocaml/pull/12954
[#12993]: https://github.com/ocaml/ocaml/pull/12993
[#13018]: https://github.com/ocaml/ocaml/pull/13018
[#13019]: https://github.com/ocaml/ocaml/pull/13019
[#13065]: https://github.com/ocaml/ocaml/pull/13065
[#13199]: https://github.com/ocaml/ocaml/pull/13199
[#13293]: https://github.com/ocaml/ocaml/pull/13293
[#13339]: https://github.com/ocaml/ocaml/pull/13339
[#13431]: https://github.com/ocaml/ocaml/pull/13431
[#13458]: https://github.com/ocaml/ocaml/pull/13458
[#13526]: https://github.com/ocaml/ocaml/pull/13526
[#13667]: https://github.com/ocaml/ocaml/pull/13667
[#13668]: https://github.com/ocaml/ocaml/pull/13668
[#14014]: https://github.com/ocaml/ocaml/pull/14014
[#14240]: https://github.com/ocaml/ocaml/pull/14240
[#14244]: https://github.com/ocaml/ocaml/pull/14244
[#14245]: https://github.com/ocaml/ocaml/pull/14245
[#14246]: https://github.com/ocaml/ocaml/pull/14246
[#14310]: https://github.com/ocaml/ocaml/pull/14310
[#14421]: https://github.com/ocaml/ocaml/pull/14421
[#14424]: https://github.com/ocaml/ocaml/pull/14424
[#14563]: https://github.com/ocaml/ocaml/pull/14563
[#14607]: https://github.com/ocaml/ocaml/pull/14607
[98a24eaaeef]: https://github.com/ocaml/ocaml/commit/98a24eaaeefaa714f03427f763d73dca87f56e4d
[c9f4c113e5]: https://github.com/ocaml/ocaml/commit/c9f4c113e51f0602207b88169181810eb52c228a
