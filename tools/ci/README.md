# OCaml CI Infrastructure

## Unified CI

During the 5.2 development cycle, the CI configurations were synchronised in
[#12846][], [#12847][], [#12848][] and [#12849][]. This series of PRs focused on
`.github/workflows`, `tools/ci/actions`, `tools/ci-appveyor` and `appveyor.yml`.
Subsequent work has extended this to the Jenkins configurations in
`tools/ci/inria`.

[#12846]: https://github.com/ocaml/ocaml/pull/12846
[#12847]: https://github.com/ocaml/ocaml/pull/12847
[#12848]: https://github.com/ocaml/ocaml/pull/12848
[#12849]: https://github.com/ocaml/ocaml/pull/12849

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

[#8650]: https://github.com/ocaml/ocaml/pull/8650
[#9414]: https://github.com/ocaml/ocaml/pull/9414
[#9437]: https://github.com/ocaml/ocaml/pull/9437
[#9557]: https://github.com/ocaml/ocaml/pull/9557
[#9919]: https://github.com/ocaml/ocaml/pull/9919
[#9981]: https://github.com/ocaml/ocaml/pull/9981
[#10045]: https://github.com/ocaml/ocaml/pull/10045
[#10046]: https://github.com/ocaml/ocaml/pull/10046
[#10148]: https://github.com/ocaml/ocaml/pull/10148
[#10380]: https://github.com/ocaml/ocaml/pull/10380
[#10723]: https://github.com/ocaml/ocaml/pull/10723
[#10831]: https://github.com/ocaml/ocaml/pull/10831
[#10835]: https://github.com/ocaml/ocaml/pull/10835
[#11100]: https://github.com/ocaml/ocaml/pull/11100
[#11675]: https://github.com/ocaml/ocaml/pull/11675
[#11861]: https://github.com/ocaml/ocaml/pull/11861
[#12231]: https://github.com/ocaml/ocaml/pull/12231
[#12372]: https://github.com/ocaml/ocaml/pull/12372
[#12509]: https://github.com/ocaml/ocaml/pull/12509
[#12520]: https://github.com/ocaml/ocaml/pull/12520
[#12577]: https://github.com/ocaml/ocaml/pull/12577
[#12993]: https://github.com/ocaml/ocaml/pull/12993
[#13018]: https://github.com/ocaml/ocaml/pull/13018
[#13019]: https://github.com/ocaml/ocaml/pull/13019
[#13065]: https://github.com/ocaml/ocaml/pull/13065
[#13339]: https://github.com/ocaml/ocaml/pull/13339
[#14607]: https://github.com/ocaml/ocaml/pull/14607
[98a24eaaeef]: https://github.com/ocaml/ocaml/commit/98a24eaaeefaa714f03427f763d73dca87f56e4d
[c9f4c113e5]: https://github.com/ocaml/ocaml/commit/c9f4c113e51f0602207b88169181810eb52c228a

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
