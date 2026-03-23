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

- [91df237be4][] (from [#10831][]) was cherry-picked to 4.14 in order to support
  [#13065][]. The issue was masked previously because `macos-latest` flipped
  over to an arm64 image, which skips the unwind test for architecture reasons;
  but switching back to amd64 testing re-revealed the problem with the script.
- [#12231][] was backported to 5.0 (but is not needed in 4.x). It is required in
  order to compile the branch with mingw-w64 11.0, otherwise the testsuite will
  fail with flexdll relocation errors.
- [#11861][] and [#12509][] were backported to 5.0 (4.14 already has [#12577][]
  including both of these). These are necessary for macOS CI, as clang in C17
  mode emits warnings otherwise.
- [#13019][] was backported to 5.1 and 5.0 (4.14 already has [#13018][]). As of
  March 2024, this change is required for the testsuite to pass when running on
  Apple silicon to eliminate linker warnings.
- [c9f4c113e5][] was added to 4.14 to disable the `lib-threads/beat.ml` test on
  macOS only (see [#13339][] for more details).

[#10831]: https://github.com/ocaml/ocaml/pull/10831
[#11861]: https://github.com/ocaml/ocaml/pull/11861
[#12231]: https://github.com/ocaml/ocaml/pull/12231
[#12509]: https://github.com/ocaml/ocaml/pull/12509
[#12577]: https://github.com/ocaml/ocaml/pull/12577
[#13018]: https://github.com/ocaml/ocaml/pull/13018
[#13019]: https://github.com/ocaml/ocaml/pull/13019
[#13065]: https://github.com/ocaml/ocaml/pull/13065
[#13339]: https://github.com/ocaml/ocaml/pull/13339
[91df237be4]: https://github.com/ocaml/ocaml/commit/91df237be42a0d3b7c5525ef19b7cbeed108c09c
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
