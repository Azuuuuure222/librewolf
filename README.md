# LibreWolf — Skylake / Void Linux musl

LibreWolf 158.0 for an Intel Core i3-6100U (Skylake), 4 GB RAM, HDD, and Void Linux x86_64-musl. The binary is not portable to pre-Skylake CPUs.

## Native Wayland only

Built with GTK3 `cairo-gtk3-wayland` for `dwl` without Xwayland or an X11 server. Launch explicitly with:

```sh
MOZ_ENABLE_WAYLAND=1 librewolf-wayland
```

Verify `about:support` → **Window Protocol** reports `wayland`, not `xwayland`. Avoid setting `GDK_BACKEND=wayland` globally; CI sets it only for the isolated PGO workload.

## Target tuning

- C/C++: Clang 22, `-O2 -march=skylake`; LLD 22. Rust: `-C target-cpu=skylake`.
- Build: cross-language full LLVM LTO and PGO.
- Memory: unload inactive tabs under low memory; limit Fission process counts and prelaunches.
- HDD: disable new-tab preload, write session state every 30 seconds, and cap cache-chunk memory at 16 MiB per cache class.
- Audio: ALSA and PulseAudio protocol support, including PipeWire's PulseAudio server.

These settings trade some parallelism for lower memory and I/O pressure on the target system.

## Build and release

- Source: LibreWolf 158.0, source revision 1; Void package revision 2.
- CI builds on a hosted runner, profiles under native Wayland via headless Weston (1366×768), validates PGO data, and caches source, profiles, compiler outputs, and Void dependencies.
- CI publishes XBPS packages, repository metadata, and SHA-256/SHA-512 manifests. The build job has read-only repository permissions; publishing is master-only.

## Repository rule

Commit changes directly to `master`. Do not create feature branches or pull requests unless explicitly instructed otherwise.
