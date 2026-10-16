# LibreWolf for Void Linux (musl) — Skylake / native Wayland

A hardware-specific LibreWolf package for **Void Linux `x86_64-musl`**, tuned for an Intel Core i3-6100U (Skylake, 2 cores / 4 threads), 4 GB RAM, HDD, and a native Wayland session such as `dwl`.

This is **not a generic or portable x86_64 build**. The compiler is allowed to emit Skylake instructions, so pre-Skylake CPUs are unsupported. Build artifacts are produced by GitHub Actions; the target laptop is not used to compile Firefox.

## Scope and current recipe

| Item | Current configuration |
|---|---|
| Upstream | LibreWolf 158.0 |
| Source revision (`_rev`) | 1 |
| Void package revision | 2 |
| Package target | `x86_64-musl` only |
| CPU baseline | Intel Skylake |
| Graphics toolkit | GTK3 `cairo-gtk3-wayland` |
| Compiler/linker | Clang 22 / LLVM 22 / LLD 22 |
| Optimization | `-O2`, Skylake-specific C/C++ and Rust code generation |
| Link-time optimization | Full cross-language LLVM LTO, enabled by default |
| Profile-guided optimization | PGO, enabled by default |
| Audio | ALSA and PulseAudio protocol (including PipeWire's `pipewire-pulse`) |

The version above describes the **current package recipe**, not a guarantee that its corresponding release asset has already been published. Check [Releases](https://github.com/Azuuuuure222/librewolf/releases) for available binaries and their checksums.

## Download and install

1. Open [GitHub Releases](https://github.com/Azuuuuure222/librewolf/releases) and choose a release. Download the `.xbps` package, `x86_64-musl-repodata`, and `SHA256SUMS` from the **same release** into one directory.
2. From that directory, verify the downloaded assets:

   ```sh
   sha256sum --check SHA256SUMS
   ```

3. Install using the local repository metadata, keeping the official Void repositories enabled so XBPS can resolve dependencies:

   ```sh
   sudo xbps-install --repository="$PWD" librewolf
   ```

Use assets from one release together. Do not treat a package from one tag and repository metadata from another tag as a matching set.

## Native Wayland runtime

The recipe configures GTK3's `cairo-gtk3-wayland` toolkit and installs `/usr/bin/librewolf-wayland` as a launcher alias. The intended environment is `dwl` or another native Wayland compositor **without Xwayland or an X11 server**.

Launch explicitly with:

```sh
MOZ_ENABLE_WAYLAND=1 librewolf-wayland
```

Verify in `about:support` that **Window Protocol** reports `wayland`, not `xwayland`. Do not export `GDK_BACKEND=wayland` globally as a workaround; the explicit Firefox selector is used for normal launching, while CI sets the GTK backend only for its isolated PGO workload.

Wayland is a build requirement, not an optional build toggle. The CI validator checks that the GTK toolkit and native-Wayland PGO settings remain present and rejects Xvfb/X11 and Firefox headless PGO fallbacks.

## Runtime tuning for 4 GB RAM and HDD

The package includes target-specific defaults in `srcpkgs/librewolf/files/vendor.js`:

| Setting | Purpose |
|---|---|
| `browser.tabs.unloadOnLowMemory = true` | Allow inactive tabs to be unloaded under memory pressure |
| `browser.sessionstore.interval = 30000` | Write session state every 30 seconds to reduce HDD write frequency while retaining recovery |
| `browser.newtab.preload = false` | Avoid loading new-tab content before it is requested |
| `browser.cache.disk.max_chunks_memory_usage = 16384` | Bound cache-chunk memory at 16 MiB per cache class |
| `browser.cache.disk.max_priority_chunks_memory_usage = 16384` | Apply the same bound to priority cache chunks |
| `dom.ipc.processCount = 4` | Limit the general content-process count |
| `dom.ipc.processCount.webIsolated = 2` | Limit isolated-site process reuse |
| `dom.ipc.processPrelaunch.fission.number = 1` | Prelaunch only one Fission process |

These are deliberate tradeoffs between process isolation/parallelism and memory pressure on the target. They are not universal Firefox recommendations and do not guarantee a measured performance improvement in every workload.

## Compiler and linker profile

The current recipe in `srcpkgs/librewolf/template` controls the build:

- **C/C++:** `-O2 -march=skylake`.
- **Rust:** `-C target-cpu=skylake`, with Rust optimization level 2.
- **Toolchain:** Clang/LLVM/LLD 22; LLD's LTO worker and partition counts follow the selected build concurrency.
- **LTO:** `--enable-lto=cross,full` when the default `lto` option is enabled, allowing optimization across supported language boundaries through Firefox's current build integration.
- **PGO:** Enabled by default. The workload produces a profile that is validated with `llvm-profdata` before reuse or final profile-use compilation.
- **Other recipe choices:** Mozilla hardening remains enabled; tests, crash reporting, updater, jemalloc, and ELF-hack options are disabled in the package build. Audio is explicitly enabled only for the ALSA and PulseAudio protocol options.

`-O2` is intentional: a higher optimization level is not automatically faster in real browser use and can increase code size or build cost. `-march=skylake` deliberately sacrifices compatibility with older CPUs. This build is optimized for the target rather than arbitrary x86_64 systems.

## CI architecture

GitHub Actions is the build machine; the laptop is only the deployment target. Compilation parallelism and LTO concurrency are selected from the runner's CPU and available memory, **not** the target laptop's two cores and four threads. The workflow reserves memory for the operating system/linker and limits worker counts to reduce out-of-memory risk on hosted or custom runners.

The workflow:

1. Runs on pushes to `master` that change `srcpkgs/librewolf/**`, `.github/workflows/main.yml`, or `.github/scripts/**`, or through manual `workflow_dispatch`.
2. Checks out this repository and Void's `void-packages`, then overlays the local LibreWolf package.
3. Validates the template and derives version, source revision, checksum, and release identity before the expensive build.
4. Restores verified source, PGO, Void binary-package, and `sccache` caches where available.
5. Bootstraps `xbps-src`, fetches and checksum-verifies the LibreWolf source, then builds the XBPS package.
6. Generates PGO through native Wayland on a headless Weston compositor **only on a PGO cache miss**. The Wayland socket is shared into the build chroot; the profile and jarlog must validate before they are cached or used.
7. Publishes packages, repository metadata, and SHA-256/SHA-512 checksum manifests from the separate master-only publishing job.

The workflow uses Ubuntu 24.04 by default; `LIBREWOLF_RUNNER` can override the runner through a repository variable. Build and PGO/LTO work can be expensive, so the workflow has a long timeout. README-only edits do not trigger a package build under the current path filters.

## Cache correctness and release integrity

Caching is for speed, not a source of truth:

- **Source archive:** The SHA-256 in the package template is authoritative. Cached archives are hashed again; a cache hit is rejected and refetched if verification fails.
- **PGO profile:** The cache key includes the source digest, package template, downstream patches, and relevant toolchain/base-chroot inputs. `merged.profdata` must be readable by `llvm-profdata`, and the jarlog must be non-empty. `LIBREWOLF_PGO_CACHE_VERSION` is the explicit invalidation control for workload changes not represented in those inputs.
- **Compiler cache:** Mozilla `sccache` is a real Void build dependency (`rust-sccache`), not an unmanaged binary copied into the chroot. It uses a local host cache and the GitHub Actions cache, with server behavior configured to persist across the PGO/build phases.
- **Void dependencies:** Binary packages are cached to reduce repeated bootstrap and build work.

The build job has read-only repository permissions. Publishing is separated into a master-only job with release-writing permissions. The publisher checks existing asset digests before reusing them and uploads the XBPS package(s), `x86_64-musl-repodata`, `SHA256SUMS`, and `SHA512SUMS`.

### Release naming

Release tags identify the source version and source revision: `version-source_revision`. If the packaging revision is greater than 1, `-rN` is appended so a packaging-only rebuild does not overwrite a prior release. For example, the current recipe's identity is `158.0-1-r2`.

The package filename follows XBPS naming, for example `librewolf-158.0_2.x86_64-musl.xbps` for source version 158.0 at package revision 2. Always use the exact filenames published by the selected release.

## Package maintenance

The local packaging and CI files are the source of truth for implementation details:

- `srcpkgs/librewolf/template` — version, revision, source URL and digest, dependencies, build options, compiler/linker configuration, PGO flow, and installation.
- `srcpkgs/librewolf/files/vendor.js` — target-specific browser preferences.
- `srcpkgs/librewolf/files/librewolf.desktop` — desktop entry.
- `srcpkgs/librewolf/files/stab.h` — compatibility header copied during extraction.
- `srcpkgs/librewolf/patches/` — narrow source/toolchain compatibility patches.
- `.github/scripts/validate-template.sh` — shell syntax, metadata, source URL/checksum and native Wayland PGO invariants.
- `.github/workflows/main.yml` — source/cache/build/release orchestration.

Current downstream patches address musl audio-thread compatibility, musl/system-header conflicts, Firefox build-system clobber behavior, fortify wrappers, LLVM 22, `mallinfo`, Parakeet's `cstdint` include, and the scheduler sandbox patch. Every source update requires auditing these patches against the new upstream source; obsolete patches should be removed rather than preserved by habit.

### Updating the source or recipe

1. Update `version`, `_rev`, and the source `checksum` when changing the upstream source archive.
2. Increment `revision` for package-only recipe changes.
3. Audit all downstream patches; retain only fixes still required by the new source/toolchain.
4. Review the PGO workload and its cache inputs. Bump `LIBREWOLF_PGO_CACHE_VERSION` when its behavior changes in a way not already covered by the cache key.
5. Review `SCCACHE_GHA_VERSION` if the compiler-cache namespace or compatibility changes.
6. Run CI and inspect source verification, PGO validation, cache behavior, package output, and published checksums—not only whether compilation exits successfully.

Repository workflow rule: commit changes directly to `master`. Do not create feature branches or pull requests unless explicitly instructed otherwise.

## Development history and rationale

This repository began as a conventional LibreWolf/Void packaging fork and became a deliberately specialized build. The commit history records several rounds of README expansion and reduction: early documentation described the personal target and package purpose; larger rewrites documented target hardware, optimization decisions, CI architecture and build failures; later edits removed stale implementation detail; the current documentation consolidates the still-relevant information without treating superseded approaches as current.

| Period | Engineering changes recorded in the commits |
|---|---|
| 2022–2025 | Initial README and repository identity changes, regular upstream LibreWolf package updates, and earlier release/integrity documentation. |
| Sep 23–25, 2026 | Narrowed the build to `x86_64-musl`/Skylake, updated musl fixes and package patches, moved CI to Ubuntu 24.04, and iterated on XBPS bootstrapping, signing/release handling, and compiler caching. |
| Sep 30, 2026 | Established the hardware-specific optimization profile, target runtime preferences, Clang/LLVM/LLD, full LTO and PGO; added source, compiler, PGO and Void package caching plus checksum validation. |
| Oct 1, 2026 | Simplified the CI/release architecture, integrated source-cache handling into the build, restored the package overlay, and tightened transactional release publication and patch compatibility. |
| Oct 2, 2026 | Hardened `sccache` integration through the XBPS chroot, extracted template validation into a script, corrected LTO/FFvpx/SQLite/patch issues, clarified cache invariants, and documented the hardware/build-host separation. |
| Oct 3, 2026 | Refined PGO/cache validation and release checksum behavior, and updated how Wayland targeting and display-related PGO constraints were represented. |
| Oct 14, 2026 | Updated the package to LibreWolf 158.0, fixed the Firefox scheduler sandbox patch, removed an obsolete Rust LTO patch path, and hardened cache identity. |
| Oct 15, 2026 | Tuned process reuse for the 4 GB target, repaired LLD worker parsing, improved PGO/cache handling, simplified routine master-only CI, and shortened the then-1,078-line README to target/build essentials. |
| Oct 16, 2026 | Re-established native Wayland PGO through headless Weston, added guards against X11/Xvfb/headless profiling fallbacks, skipped Weston when a verified PGO cache hit exists, documented runtime selection, and removed redundant packaging/CI code. |

### Lessons from prior build failures

- **Do not inject unmanaged tools into the chroot.** `xbps-src` can clean its build root; `sccache` must be installed as a proper package dependency.
- **Pass concrete tool paths.** Firefox configure did not reliably resolve a bare `sccache` name; the recipe uses `/usr/bin/sccache` explicitly.
- **Do not trust cache hits blindly.** Source checksum and PGO profile validation run even when cached data is present.
- **Keep cache keys specific.** Source and PGO caches must be invalidated when profile-relevant source, patch, toolchain, or workload inputs change; unrelated release housekeeping should not force expensive re-profiling.
- **Match PGO to the actual target toolkit.** Earlier history experimented with Xvfb/X11 and Firefox headless modes to work around runner failures. The current recipe and validator instead require native Wayland PGO using Weston, while caching avoids starting the compositor when a valid profile is available.
- **Keep patches narrow and version-aware.** Firefox source changes regularly make compatibility patches unnecessary or invalidate old patch contexts.
- **Optimize the right machine.** Runtime flags target Skylake/4 GB/HDD; build worker counts target the actual CI runner.

## Tradeoffs and non-goals

This project prioritizes, in order: useful runtime performance on the actual Skylake target, memory stability, less unnecessary HDD activity, efficient CI builds, reuse of expensive work, and maintainable downstream changes.

It intentionally does not aim to support older x86_64 CPUs, glibc builds, unrelated architectures, or generic distribution portability. PGO reflects a scripted profile-server workload, not every real user's browsing habits. PGO and LTO substantially increase build cost, which is why CI and persistent caches matter. Configuration choices are grounded in the target and the current recipe, but no benchmark claim is implied without measurement on the target hardware.

## Upstream references

- [LibreWolf](https://librewolf.dev/)
- [LibreWolf source releases](https://librewolf.dev/librewolf/source/releases)
- [Void Linux](https://voidlinux.org/)
- [Void `void-packages`](https://github.com/void-linux/void-packages)
- [Void Firefox package](https://github.com/void-linux/void-packages/tree/master/srcpkgs/firefox)
- [Mozilla Firefox build documentation](https://firefox-source-docs.mozilla.org/build/buildsystem.html)
- [Mozilla sccache](https://github.com/mozilla/sccache)
