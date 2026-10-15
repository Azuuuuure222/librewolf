# LibreWolf — Skylake / Void Linux musl

A hardware-specific LibreWolf package for an Intel Core i3-6100U (Skylake, 2 cores / 4 threads), 4 GB RAM, HDD, and Wayland on Void Linux x86_64-musl. It is intentionally not portable to pre-Skylake CPUs.

## Target profile

- C/C++: Clang 22, `-O2 -march=skylake`; LLD 22.
- Rust: `-C target-cpu=skylake`; Rust optimization level 2.
- Browser build: cross-language full LLVM LTO and PGO.
- Runtime memory: low-memory tab unloading, a two-process-per-site Fission cap, and one prelaunched Fission process.
- HDD/RAM: new-tab preload disabled, session-store writes every 30 seconds, and cache chunk memory limited to 16 MiB per cache class.
- Desktop/media: GTK3 Wayland; ALSA and PulseAudio protocol support (including PipeWire's pulse server).

The settings prioritize interactive speed and memory stability on this machine. They are not universal Firefox recommendations; process limits trade some per-site parallelism for lower memory pressure.

## Build and release

- Upstream source: LibreWolf 158.0, source revision 1; package revision 2.
- Default options: ALSA, D-Bus, PulseAudio, LTO, PGO, Clang, and WASI.
- CI builds on a hosted runner. Build parallelism is derived from that runner's CPUs and available RAM, never from the laptop's hardware.
- PGO uses Firefox's headless backend in a D-Bus session at a fixed 1366×768 viewport. Invalid LLVM profiles are rejected.
- sccache, verified source archives, PGO profiles, and Void binary packages are cached. Source archives are always checked against the template SHA-256.
- CI uploads XBPS packages, repository metadata, and SHA-256/SHA-512 manifests. The build job has read-only repository permission; a separate master-only job publishes releases.

## Key paths

- `srcpkgs/librewolf/template`: package recipe, compiler options, PGO/LTO, dependencies, and install rules.
- `srcpkgs/librewolf/files/vendor.js`: target-specific runtime preferences.
- `.github/workflows/main.yml`: CI build, caching, verification, and release workflow.
- `.github/scripts/validate-template.sh`: early source and package metadata validation.

## Repository workflow rule

Commit repository changes directly to `master`. Do not create feature branches or pull requests unless explicitly instructed otherwise.