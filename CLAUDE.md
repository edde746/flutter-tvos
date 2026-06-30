# flutter-plezy engine patches — maintainer guide

This repo holds the **per-platform patch series** for the custom Flutter engines Plezy ships: `tvos` (Apple TV — no official Flutter support exists) and `windows` (DirectComposition presentation so HDR mpv video composes under Flutter UI in one window). It does **not** contain any upstream Flutter / Dart / Skia source — those are fetched on demand via gclient and patched locally.

If you are an agent asked to "bump to Flutter X.Y" or "fix a tvOS/Windows regression", read this whole file before touching anything.

## Requirements

- tvOS series: macOS with Xcode installed (provides the Apple SDKs that Flutter's engine build expects).
- Windows series: Windows with Visual Studio 2022 (C++ workload) + Windows 10/11 SDK incl. Debugging Tools, `LongPathsEnabled=1`.
- Python 3.8+, git. All tooling is one cross-platform CLI, `engine.py` at the repo root (no third-party deps — stdlib only). No separate depot_tools install needed — `engine.py fetch` (and `build`) auto-clone it into `./depot_tools/` if `gclient` isn't already on `PATH`.
- ~10 GB free disk per version on macOS; ~80–100 GB on Windows (bigger toolchain prebuilts + build output).

## Repo layout

```
flutter-plezy/
├── CLAUDE.md                         # ← you are here
├── README.md                         # human-facing quickstart
├── engine.py                         # the one cross-platform CLI (subcommands below); stdlib only
│   # engine.py fetch <version>                       gclient sync the Flutter monorepo + deps into ./sources/<version>/
│   # engine.py apply <version> [--platform tvos|windows]    git am one platform's series (default: by host OS)
│   # engine.py regenerate <version> [--platform …]   CAPTURE your source edits back into that platform's series
│   # engine.py build <version> <variant>             gn + ninja via versions/<v>/build.py (host OS picks the variant set)
│   # engine.py package <version> [--platform …]      bundle release artifacts (tvOS tarball / Windows cache-layout zip)
├── versions/
│   └── 3.44.0/
│       ├── sdk.lock                  # pinned engine/dart/skia commit SHAs (bash-sourceable KEY=VALUE; parsed by engine.py)
│       ├── build.py                  # per-version variant table (tvOS keyed under "darwin", Windows under "win32")
│       └── patches/
│           ├── tvos/
│           │   ├── engine/           # Flutter monorepo patches (git-format-patch series, NNNN-name.patch)
│           │   ├── dart/             # Dart SDK patches
│           │   ├── skia/             # Skia patches
│           │   └── perfetto/         # Perfetto patches (nested in dart/third_party/perfetto/src)
│           └── windows/
│               └── engine/           # Windows embedder patches (DComp presentation mode)
├── depot_tools/                      # (gitignored) auto-cloned if gclient not on PATH
├── sources/                          # (gitignored) gclient-synced upstream trees
└── out/                              # (gitignored) build output promoted here per variant
```

**Per-platform regeneration rule:** `regenerate` captures *everything* between the pinned base and HEAD of the source tree. So a platform's series must only ever be regenerated from a sources tree that has ONLY that platform's patches applied. In practice: the Windows machine applies/regenerates `windows/`, the macOS machine applies/regenerates `tvos/` — never both in one tree.

After `fetch` finishes, source paths look like:

- `sources/<v>/engine/src/flutter/`                — engine source (its own git repo)
- `sources/<v>/engine/src/flutter/third_party/dart/`  — dart SDK (its own git repo)
- `sources/<v>/engine/src/flutter/third_party/skia/`  — skia (its own git repo)
- `sources/<v>/engine/src/flutter/third_party/dart/third_party/perfetto/src/` — perfetto (its own git repo; nested under dart)
- `sources/<v>/engine/src/flutter/prebuilts/`      — Apple SDKs, toolchains (CIPD-managed, not git)

The monorepo root (`sources/<v>/`, where `.gclient` lives) is **also** a git repo — the top-level Flutter monorepo. Engine patches target that root (paths like `a/engine/src/flutter/...`).

## The one rule

**Never hand-write or hand-edit the `.patch` files.**

The workflow is always:

1. `python engine.py fetch 3.44.0` — gclient-sync upstream into `./sources/3.44.0/`
2. `python engine.py apply 3.44.0` — git-am the current patch series (defaults to the host's series; `--platform` to override)
3. Edit freely inside `sources/3.44.0/` (engine patches), `sources/3.44.0/engine/src/flutter/third_party/dart/`, or `.../skia/`. Commit your changes **inside those checkouts** (`git commit` in the source tree, not in this repo).
4. `python engine.py regenerate 3.44.0` — writes the updated patch series back into `versions/3.44.0/patches/` by running `git format-patch` against the pinned bases in `sdk.lock`.
5. `git add versions/ && git commit` in this repo.

Why this matters: the patch files are *generated artifacts*. Editing them by hand will drift from what the source tree actually builds, conflicts will bite on the next rebase, and the engine you ship will not match the diff you think you're shipping. If you see a patch that needs changing, make the change in `./sources/` and regenerate.

## Bumping to a new Flutter version

Example: bump 3.44.0 → 3.45.0.

1. `cp -r versions/3.44.0 versions/3.45.0`
2. Edit `versions/3.45.0/sdk.lock` — update the engine ref to the new Flutter git tag `3.45.0` (and `ENGINE_COMMIT` to the SHA that tag points at). For `DART_COMMIT` and `SKIA_COMMIT`, read the new monorepo's `DEPS` file (at its root for the post-monorepo layout) to find what gclient will resolve — keep them in sync.
3. `python engine.py fetch 3.45.0` — pulls the new upstream commits.
4. `python engine.py apply 3.45.0` — tries to apply the old patches onto the new sources.
5. Expect conflicts. Resolve them in `./sources/` using normal git tools (`git am --3way --continue`, `git apply --3way --reject` + manual fixup). Write the fixes **as source-tree edits**.
6. `python engine.py regenerate 3.45.0` — captures the new patch series, now pinned to the new upstream bases.
7. If a variant's gn args / ninja targets changed for the new release, edit the variant table in `versions/3.45.0/build.py` (carried over by the `cp` in step 1).
8. Build each variant (`python engine.py build 3.45.0 tvos_release` etc.), verify the app still runs on simulator + device.
9. Commit `versions/3.45.0/` to this repo. Leave `versions/3.44.0/` alone — we keep history per version.

## Variants we build

Variants are declared in `versions/<v>/build.py` as a `VARIANTS` table keyed by host platform (`darwin` for the tvOS set, `win32` for the Windows set), each entry giving the gn flags, ninja targets, whether to override `verify_sdk_hash`, and what to promote to `out/`. The generic gn → ninja → promote pipeline lives once in `Ctx.build_variant` in `engine.py`; `build.py` is just data. `host_release` deliberately means different things per host (macOS host tools vs the Windows engine), so the host OS selects the table.

The standard four (tvOS, macOS host) are:

| Variant                        | Purpose                                  |
|-------------------------------|------------------------------------------|
| `tvos_debug_sim_unopt_arm64`  | Sim dev iteration (JIT, fast rebuild)    |
| `tvos_debug_unopt`            | Device debug (rarely useful — mprotect RX is blocked on tvOS, so no real JIT) |
| `tvos_release`                | Device / TestFlight AOT build            |
| `host_release`                | macOS host tools (frontend_server, gen_snapshot) needed to produce AOT snapshots |

On Apple Silicon, the cross-compile `gen_snapshot_arm64` for tvOS ARM64 targets lives in `out/tvos_release/artifacts_arm64/gen_snapshot_arm64` — that's the one to invoke, **not** `host_release/clang_arm64/gen_snapshot` (which targets macOS).

## Known gotchas (spent blood learning these)

- **`verify_sdk_hash = false`** must be appended to each `args.gn` after `gn gen` — otherwise the Dart VM rejects our kernels because the prebuilt Dart SDK hash doesn't match our patched Dart. `gn gen` overwrites args.gn when run via Flutter's wrapper; append + `flutter/third_party/gn/gn gen out/<variant>` directly, then `ninja`.
- **`TARGET_OS_TV` is always defined on Apple platforms.** Checking it with `#ifdef TARGET_OS_TV` is always-true — useless. Always use `#if defined(TARGET_OS_TV) && TARGET_OS_TV`. Several LibertyGlobal patches had this bug and had to be corrected.
- **`thread_swap_exception_ports` / `thread_set_exception_ports` are unavailable on the tvOS SDK.** Dart's `virtual_memory_posix.cc` uses them behind `DART_ENABLE_RX_WORKAROUNDS`. Our patch wraps the define in `#if !(defined(TARGET_OS_TV) && TARGET_OS_TV)` — see the dart patch series.
- **tvOS device cannot JIT.** `mprotect(RW → RX)` returns `EACCES`. Release/AOT builds are the only viable device path. Debug on device will crash at `StubCode::Init()`. Sim is fine.
- **`wantsExtendedDynamicRangeContent` is unavailable on tvOS** as of SDK 26.4 — any `CAMetalLayer` subclass override in app code must be `#if os(iOS)` (not `os(iOS) || os(tvOS)`).
- **Press events on tvOS.** The original LibertyGlobal engine guarded out `pressesBegan/Changed/Ended/Cancelled` on tvOS. Our patch removes those guards so Flutter's `HardwareKeyboard` sees Siri Remote arrows / select. Without this, dpad navigation on tvOS is dead.
- **tvOS `FlutterViewController.mm` center-tap** still fires a synthetic keycode 0x17 (DPAD_CENTER) via the `flutter/keyevent` channel (LibertyGlobal's legacy path — not removed). Apps that want Material-level widgets (bottom sheets, menu items) to activate on Siri Remote Select must add a `LogicalKeyboardKey.select → ActivateIntent` shortcut mapping; the default Flutter shortcut table only covers `enter` / `space`.

## The Windows series (DComp presentation mode)

Purpose: Plezy composites HDR mpv video (its own child-HWND flip swapchain — DWM layer 3) under Flutter UI. Stock Flutter presents blt-model into the redirection surface (layer 1, bottom-most), so nothing can render below it. The patch makes the embedder present into a premultiplied `CreateSwapChainForComposition` swapchain on an `IDCompositionTarget` (`topmost=TRUE`, layer 4) instead — UI alpha-blends over the video, window capture (Discord/OBS WGC) sees everything, and the app's legacy two-window/accent-hack compositing dies.

- **Opt-in**: the mode activates only when `FLUTTER_WINDOWS_DCOMP=1` is set in the app's environment; otherwise the patched engine is behaviorally stock. Keep it that way — it is also the shape an upstream PR needs (flag-gated, no default change).
- Patch surface: `engine/src/flutter/shell/platform/windows/` only (egl/manager, egl window surface, compositor present path). No dart/skia patches — which is why the `win32` variants in `build.py` set `verify_sdk_hash=False` (prebuilt dart-sdk stays valid, unlike the tvOS variants which set it `True`).
- Variants: `host_debug` feeds the SDK cache dir `windows-x64` (used by `flutter run`); `host_release` feeds `windows-x64-release`. Build both or dev iteration will silently run a stock debug engine.
- Consumer swap: extract the packaged zip over `<flutter-sdk>\bin\cache\artifacts\engine\windows-x64{,-release}\`. The flutter tool never hashes files (stamp-string check only) but `flutter upgrade`/`precache --force` silently restores stock — re-swap after SDK updates.
- Watch out for: ANGLE's `EGL_EXPERIMENTAL_PRESENT_PATH_FAST_ANGLE` orientation flip (Y-inverted first renders), resize (`ResizeBuffers` must follow `FlutterWindowsView::ResizeRenderSurface`), and Canonical's in-flight windowing rework touching neighboring files on rebases.

## What lives in the consumer app, not here

This repo produces an engine. The consumer Flutter app builds and links against it. Don't duplicate here:

- `tvos/scripts/xcode_appletv.sh`-style build scripts that run during Xcode's Run Script phase; they copy the prebuilt engine framework and invoke `frontend_server` + `gen_snapshot` using our host tools.
- `tvos/Runner/Plugins/*` — plugin Swift ports (shared_preferences, path_provider, etc.). These are app-specific copies of pub.dev plugins with tvOS guards, not engine work.
- `tvos/Runner/AppDelegate.swift` — plugin registration.
- App-level UI adaptations (viewport scaling, Apple TV detection, Siri Remote shortcut mappings).

If you're asked to "make videos smoother on tvOS" or "add a new plugin on Apple TV", 90% of the time the work is in the app repo, not here. Check first.

## Build the prebuilt engine

```bash
python engine.py fetch 3.44.0        # one-time per version; ~20 min
python engine.py apply 3.44.0
python engine.py build 3.44.0 host_release
python engine.py build 3.44.0 tvos_debug_sim_unopt_arm64
python engine.py build 3.44.0 tvos_release
python engine.py package 3.44.0              # → out/packages/flutter-tvos-3.44.0.tar.gz
```

Then upload the tarball to a GitHub Release on this repo. Consumer apps point `FLUTTER_LOCAL_ENGINE` at the extracted tarball.
