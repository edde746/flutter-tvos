# Flutter-tvOS engine patches — maintainer guide

This repo holds the **patch series** needed to build a Flutter engine that targets Apple TV (tvOS). It does **not** contain any upstream Flutter / Dart / Skia source — those are fetched on demand via gclient and patched locally.

If you are an agent asked to "bump to Flutter X.Y" or "fix a tvOS regression", read this whole file before touching anything.

## Requirements

- macOS with Xcode installed (provides the Apple SDKs that Flutter's engine build expects).
- Python 3, git. No separate depot_tools install needed — `fetch-sources.sh` auto-clones it into `./depot_tools/` if `gclient` isn't already on `PATH`.
- ~10 GB of free disk per version (engine clone + dart + skia + prebuilt toolchains + build output).

## Repo layout

```
flutter-tvos/
├── CLAUDE.md                         # ← you are here
├── README.md                         # human-facing quickstart
├── scripts/
│   ├── fetch-sources.sh <version>    # gclient sync the Flutter monorepo + deps into ./sources/<version>/
│   ├── apply-patches.sh <version>    # git am the patch series onto the synced trees
│   ├── regenerate-patches.sh <version>  # CAPTURE your source edits back into the patch series
│   ├── build-engine.sh <version> <variant>  # wraps gn + ninja
│   └── package.sh <version>          # tars the framework + gen_snapshot for release
├── versions/
│   └── 3.41.6/
│       ├── sdk.lock                  # pinned engine/dart/skia commit SHAs
│       ├── build.sh                  # variant-specific build orchestration for this release
│       └── patches/
│           ├── engine/               # Flutter monorepo patches (git-format-patch series, NNNN-name.patch)
│           ├── dart/                 # Dart SDK patches
│           └── skia/                 # Skia patches
├── depot_tools/                      # (gitignored) auto-cloned if gclient not on PATH
├── sources/                          # (gitignored) gclient-synced upstream trees
└── out/                              # (gitignored) ninja build output promoted here per variant
```

After `fetch-sources.sh` finishes, source paths look like:

- `sources/<v>/engine/src/flutter/`                — engine source (its own git repo)
- `sources/<v>/engine/src/flutter/third_party/dart/`  — dart SDK (its own git repo)
- `sources/<v>/engine/src/flutter/third_party/skia/`  — skia (its own git repo)
- `sources/<v>/engine/src/flutter/prebuilts/`      — Apple SDKs, toolchains (CIPD-managed, not git)

The monorepo root (`sources/<v>/`, where `.gclient` lives) is **also** a git repo — the top-level Flutter monorepo. Engine patches target that root (paths like `a/engine/src/flutter/...`).

## The one rule

**Never hand-write or hand-edit the `.patch` files.**

The workflow is always:

1. `scripts/fetch-sources.sh 3.41.6` — gclient-sync upstream into `./sources/3.41.6/`
2. `scripts/apply-patches.sh 3.41.6` — git-am the current patch series
3. Edit freely inside `sources/3.41.6/` (engine patches), `sources/3.41.6/engine/src/flutter/third_party/dart/`, or `.../skia/`. Commit your changes **inside those checkouts** (`git commit` in the source tree, not in this repo).
4. `scripts/regenerate-patches.sh 3.41.6` — writes the updated patch series back into `versions/3.41.6/patches/` by running `git format-patch` against the pinned bases in `sdk.lock`.
5. `git add versions/ && git commit` in this repo.

Why this matters: the patch files are *generated artifacts*. Editing them by hand will drift from what the source tree actually builds, conflicts will bite on the next rebase, and the engine you ship will not match the diff you think you're shipping. If you see a patch that needs changing, make the change in `./sources/` and regenerate.

## Bumping to a new Flutter version

Example: bump 3.41.6 → 3.44.0.

1. `cp -r versions/3.41.6 versions/3.44.0`
2. Edit `versions/3.44.0/sdk.lock` — update the engine ref to the new Flutter git tag `3.44.0` (and `ENGINE_COMMIT` to the SHA that tag points at). For `DART_COMMIT` and `SKIA_COMMIT`, read the new monorepo's `DEPS` file (at its root for the post-monorepo layout) to find what gclient will resolve — keep them in sync.
3. `scripts/fetch-sources.sh 3.44.0` — pulls the new upstream commits.
4. `scripts/apply-patches.sh 3.44.0` — tries to apply the old patches onto the new sources.
5. Expect conflicts. Resolve them in `./sources/` using normal git tools (`git am --3way --continue`, `git apply --3way --reject` + manual fixup). Write the fixes **as source-tree edits**.
6. `scripts/regenerate-patches.sh 3.44.0` — captures the new patch series, now pinned to the new upstream bases.
7. Build each variant (`scripts/build-engine.sh 3.44.0 tvos_release` etc.), verify the app still runs on simulator + device.
8. Commit `versions/3.44.0/` to this repo. Leave `versions/3.41.6/` alone — we keep history per version.

## Variants we build

Each variant has its own GN config. The standard four are:

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

## What lives in the consumer app, not here

This repo produces an engine. The consumer Flutter app builds and links against it. Don't duplicate here:

- `tvos/scripts/xcode_appletv.sh`-style build scripts that run during Xcode's Run Script phase; they copy the prebuilt engine framework and invoke `frontend_server` + `gen_snapshot` using our host tools.
- `tvos/Runner/Plugins/*` — plugin Swift ports (shared_preferences, path_provider, etc.). These are app-specific copies of pub.dev plugins with tvOS guards, not engine work.
- `tvos/Runner/AppDelegate.swift` — plugin registration.
- App-level UI adaptations (viewport scaling, Apple TV detection, Siri Remote shortcut mappings).

If you're asked to "make videos smoother on tvOS" or "add a new plugin on Apple TV", 90% of the time the work is in the app repo, not here. Check first.

## Build the prebuilt engine

```bash
./scripts/fetch-sources.sh 3.41.6        # one-time per version; ~20 min
./scripts/apply-patches.sh 3.41.6
./scripts/build-engine.sh 3.41.6 host_release
./scripts/build-engine.sh 3.41.6 tvos_debug_sim_unopt_arm64
./scripts/build-engine.sh 3.41.6 tvos_release
./scripts/package.sh 3.41.6              # → out/packages/flutter-tvos-3.41.6.tar.gz
```

Then upload the tarball to a GitHub Release on this repo. Consumer apps point `FLUTTER_LOCAL_ENGINE` at the extracted tarball.
