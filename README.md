# flutter-tvos

A patch series that makes the Flutter engine build for **Apple TV (tvOS)**. No official Flutter tvOS support exists, and the upstream community fork ([DenisovAV/flutter_tv](https://github.com/DenisovAV/flutter_tv)) hasn't rebased its engine source since May 2024.

This repo is **just the diffs** — not a fork of the whole engine. Scripts fetch upstream Flutter / Dart / Skia at pinned hashes, apply our patches, and build. Prebuilt engine tarballs are published on [Releases](../../releases).

## Quickstart

```bash
./scripts/fetch-sources.sh 3.41.6    # gclient sync upstream (~10 GB, ~20 min)
./scripts/apply-patches.sh 3.41.6
./scripts/build-engine.sh 3.41.6 host_release
./scripts/build-engine.sh 3.41.6 tvos_release
./scripts/package.sh 3.41.6
```

Requirements: macOS + Xcode, Python 3, git. depot_tools is auto-installed to `./depot_tools/` if not on `PATH`.

`./sources/` (gitignored) holds the gclient-synced upstream trees.
`./out/` (gitignored) holds ninja build output.

## Supported variants

- `tvos_debug_sim_unopt_arm64` — sim dev iteration
- `tvos_release` — device / TestFlight AOT
- `host_release` — macOS host tools (frontend_server, gen_snapshot)

Device debug builds crash at Dart VM init because tvOS blocks RX mprotect. Develop on the sim; ship release.

## Consuming the engine from a Flutter app

Download the tarball from [Releases](../../releases), extract it somewhere, and point `FLUTTER_LOCAL_ENGINE` at the extracted `out/<version>/` path in your Xcode build script. The app's script phase then uses the release variant of `Flutter.framework`, invokes the bundled `dartaotruntime` + `frontend_server_aot.dart.snapshot` to produce `app.dill`, and runs `gen_snapshot_arm64` to emit the AOT assembly linked into `App.framework/App`. See any consumer's `xcode_appletv.sh` for a working recipe.

## Maintenance

See [CLAUDE.md](CLAUDE.md) for the rules around editing patches, bumping Flutter versions, and the pile of gotchas that landed the current patch series.
