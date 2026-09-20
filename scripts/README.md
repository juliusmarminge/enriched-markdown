# Maintainer scripts

Repo-level tooling, mostly for releases. Not needed for regular contribution work — see [CONTRIBUTING.md](../CONTRIBUTING.md) for that.

## generate-changelog.mjs

Prints GitHub-release-style markdown for all commits since a tag, with PR links, author handles, and a New Contributors section. Commits are grouped by conventional-commit prefix: `feat` → New Features, `fix`/`perf` → Fixes & Improvements, `refactor` → Refactors, `test` → Tests, `docs`/`chore`/`build`/`ci` → Docs & Chores, and anything else → Other Changes.

```sh
./scripts/generate-changelog.mjs v0.7.0 | pbcopy          # everything since v0.7.0
./scripts/generate-changelog.mjs v0.6.0 v0.7.0            # explicit range
```

Author handles and the New Contributors section are resolved through an authenticated [GitHub CLI](https://cli.github.com/); without it the script falls back to plain commit author names.

## prepare-npm-publish.sh

`prepack`/`postpack` hooks for the library package: swaps the `cpp` symlink for a real copy of `packages/core/cpp` while packing. Run automatically by npm, not by hand.

## fetch-md4c.sh

Syncs `packages/core/cpp/md4c` from upstream [mity/md4c](https://github.com/mity/md4c). Run via `yarn workspace react-native-enriched-markdown sync-md4c`.

Restores Enriched's `md_parse` → `enrm_md_parse` alias after fetching so another embedded MD4C can link alongside it.

## test-md4c-isolation.sh

Run `bash scripts/test-md4c-isolation.sh` with a C99 compiler and a C++17 compiler available as `cc` and `c++`, or set `CC` and `CXX`. No React Native installation is required.

Compiles and links two complete MD4C copies, one with Enriched's symbol name and one with the original `md_parse`. Runs both callback parsers and Enriched's C++ AST parser. Also compiles the iOS bridges' C++ includes with conflicting headers first in the search path, using both the monorepo symlink and the published package's copied core layout. This header diagnostic does not replace an iOS CocoaPods build.
