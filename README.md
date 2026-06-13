# flutter-plezy

Patch series + build scripts for the custom Flutter engines that [Plezy](https://github.com/edde746) ships. **Just the diffs** — not a fork of the engine. Scripts fetch upstream Flutter / Dart / Skia at pinned hashes, apply our per-platform patches, and build. Prebuilt engine artifacts are published on [Releases](../../releases).

Two patch series live here:

| Series | Why it exists |
|---|---|
| `patches/tvos/` | Makes the engine build for **Apple TV (tvOS)** — no official Flutter tvOS support exists. (Formerly the `flutter-tvos` repo; old URLs redirect.) |
| `patches/windows/` | Makes the Windows embedder present via **DirectComposition** (premultiplied composition swapchain at the topmost DComp layer), so native content — Plezy's HDR mpv video — can composite *underneath* Flutter UI in the same window. Fixes Discord/OBS window capture and removes the legacy two-window transparency hacks. |

(Future candidate: a Linux series for HDR output.)

## Quickstart — tvOS (macOS + Xcode)

```bash
./scripts/fetch-sources.sh 3.44.0       # gclient sync upstream (~10 GB, ~20 min)
./scripts/apply-patches.sh 3.44.0 tvos
./scripts/build-engine.sh 3.44.0 host_release
./scripts/build-engine.sh 3.44.0 tvos_release
./scripts/package.sh 3.44.0
```

## Quickstart — Windows (VS 2022 + Windows SDK)

```powershell
.\scripts\fetch-sources.ps1 3.44.0      # gclient sync upstream (~30 GB)
.\scripts\apply-patches.ps1 3.44.0 windows
.\scripts\build-engine.ps1 3.44.0 host_debug      # what `flutter run` loads
.\scripts\build-engine.ps1 3.44.0 host_release    # what release builds load
.\scripts\package.ps1 3.44.0
```

Requirements: Visual Studio 2022 with C++ workload, Windows 10/11 SDK with Debugging Tools, Python 3, git, `LongPathsEnabled=1`. depot_tools is auto-cloned to `./depot_tools/` if not on `PATH` (it bootstraps its own pinned git/python, so your git config can't corrupt the checkout). `DEPOT_TOOLS_WIN_TOOLCHAIN=0` is set by the scripts.

`./sources/` (gitignored) holds the gclient-synced upstream trees.
`./out/` (gitignored) holds build output.

## Consuming the engines

**tvOS:** download the tarball from Releases, extract, point `FLUTTER_LOCAL_ENGINE` at `out/<version>/` in your Xcode build script (see a consumer's `xcode_appletv.sh`).

**Windows:** download `flutter-plezy-windows-<version>.zip` from Releases and extract its `windows-x64/` and `windows-x64-release/` folders over `<flutter-sdk>\bin\cache\artifacts\engine\windows-x64{,-release}\`. The flutter tool validates the cache by `engine.stamp` string only (no file hashing), so the swap sticks — but it is **silently wiped by `flutter upgrade` / `flutter precache --force`**; re-extract after SDK updates. Consumers should assert `bin\internal\engine.version` matches the version this zip was built for before swapping. The DComp presentation mode is opt-in at runtime via the `FLUTTER_WINDOWS_DCOMP=1` environment variable; without it the patched engine behaves exactly like stock.

## Supported build variants

| Variant | Platform | Purpose |
|---|---|---|
| `tvos_debug_sim_unopt_arm64` | tvOS | sim dev iteration |
| `tvos_release` | tvOS | device / TestFlight AOT |
| `host_release` (macOS) | tvOS | host tools (frontend_server, gen_snapshot) |
| `host_debug` (Windows) | Windows | engine `flutter run` loads (cache dir `windows-x64`) |
| `host_release` (Windows) | Windows | engine release builds load (cache dir `windows-x64-release`) |

tvOS device debug builds crash at Dart VM init (tvOS blocks RX mprotect) — develop on the sim; ship release.

## Maintenance

See [CLAUDE.md](CLAUDE.md) for the rules around editing patches, bumping Flutter versions, and the pile of gotchas that landed the current patch series.
