# LibreWolf — Skylake / Void Linux musl

LibreWolf 158.0, tuned for an Intel Core i3-6100U (Skylake), 4 GB RAM, HDD, and Void Linux `x86_64-musl`. The binary requires a Skylake-class CPU or newer.

## Native Wayland runtime

Built with GTK3 `cairo-gtk3-wayland` for `dwl` without Xwayland or an X11 server. Launch with:

```sh
MOZ_ENABLE_WAYLAND=1 librewolf-wayland
```

Verify `about:support` → **Window Protocol** reports `wayland`, not `xwayland`. Xvfb/X11 is used only in the isolated CI PGO profiling step; it is a build dependency, not a runtime requirement.

## Target tuning

- C/C++: Clang 22, `-O2 -march=skylake`; Rust: `-C target-cpu=skylake`; LLD 22.
- Build: cross-language LLVM LTO and profile-guided optimization (PGO).
- Memory: unload tabs under low-memory conditions; constrain Fission process reuse and prelaunch.
- HDD: disable new-tab preload, save session state every 30 seconds, and cap cache-chunk memory at 16 MiB per cache class.
- Audio: ALSA and PulseAudio protocol support, including `pipewire-pulse`.

These settings prioritize resource stability on the target; process limits trade some parallelism for lower memory pressure.

## Build and release

- Source revision: LibreWolf 158.0-1; package revision: 2.
- CI builds on a hosted runner. Build parallelism follows runner CPU and RAM capacity.
- CI validates the source checksum and PGO profile, caches source/compiler/PGO/Void dependencies, and publishes XBPS packages, repository metadata, and SHA-256/SHA-512 manifests.
- Build permissions are read-only; publishing runs separately and only for `master`.

## Key paths

- `srcpkgs/librewolf/template`: package recipe and build flags.
- `srcpkgs/librewolf/files/vendor.js`: runtime preferences.
- `.github/workflows/main.yml`: build and release automation.
- `.github/scripts/validate-template.sh`: pre-build checks.

## Repository rule

Commit changes directly to `master`. Do not create feature branches or pull requests unless explicitly instructed otherwise.
