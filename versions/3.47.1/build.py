"""Build variants for the Flutter 3.44.0 engine.

Loaded on demand by engine.py `build`. VARIANTS is keyed by host platform —
tvOS device/sim + macOS host tools build on macOS; the DComp-patched Windows
embedder builds on Windows. The generic gn -> ninja -> promote pipeline lives
in engine.py's Ctx.build_variant; this file is just the variant table.

  python engine.py build 3.44.0 <variant>
"""

VARIANTS = {
    # macOS host: tvOS engines + the host tools (frontend_server, gen_snapshot)
    # that turn Dart into AOT snapshots. Every variant overrides verify_sdk_hash
    # because our patched Dart's SDK hash won't match the prebuilt dart-sdk.
    "darwin": {
        "tvos_debug_sim_unopt_arm64": dict(  # sim dev iteration (JIT, fast rebuild)
            gn_flags=["--tvos", "--tvos-simulator", "--simulator-cpu=arm64",
                      "--unoptimized", "--no-lto", "--runtime-mode=debug"],
            ninja_targets=["flutter"],
            verify_sdk_hash=True,
            promote="all",
        ),
        "tvos_debug_unopt": dict(  # device debug — academic; tvOS blocks JIT RX
            gn_flags=["--tvos", "--unoptimized", "--no-lto", "--runtime-mode=debug"],
            ninja_targets=["flutter"],
            verify_sdk_hash=True,
            promote="all",
        ),
        "tvos_release": dict(  # device / TestFlight AOT (needs host_release too)
            gn_flags=["--tvos", "--no-lto", "--runtime-mode=release"],
            ninja_targets=["flutter"],
            verify_sdk_hash=True,
            promote="all",
        ),
        "host_release": dict(  # macOS host tools
            gn_flags=["--no-lto", "--runtime-mode=release"],
            # Only the tarball's host tools (dart-sdk, flutter_patched_sdk,
            # arm64 gen_snapshot). The full `flutter` target additionally links
            # FlutterMacOS.framework, whose 3.47 module-verify step passes
            # -fatal_warnings and dies on hosts without /usr/local/lib.
            ninja_targets=["dart-sdk", "flutter/lib/snapshot:strong_platform",
                           "clang_arm64/gen_snapshot"],
            verify_sdk_hash=True,
            promote="all",
        ),
    },
    # Windows host: gn args + ninja targets mirror the engine's own CI builder
    # windows_host_engine.json. No verify_sdk_hash override — the Windows series
    # doesn't touch Dart, so the prebuilt dart-sdk hash stays valid.
    # archives:windows_flutter emits the cache-layout zip package.py repacks.
    "win32": {
        "host_debug": dict(   # what `flutter run` loads from cache\...\windows-x64\
            gn_flags=["--runtime-mode=debug", "--no-lto"],
            ninja_targets=["windows", "gen_snapshot",
                           "flutter/build/archives:windows_flutter"],
            verify_sdk_hash=False,
            promote=["zip_archives", "flutter_windows.dll", "flutter_windows.dll.lib",
                     "flutter_windows.dll.pdb", "gen_snapshot.exe"],
        ),
        "host_release": dict(  # what `flutter build windows --release` loads
            gn_flags=["--runtime-mode=release", "--no-lto"],
            ninja_targets=["windows", "gen_snapshot",
                           "flutter/build/archives:windows_flutter"],
            verify_sdk_hash=False,
            promote=["zip_archives", "flutter_windows.dll", "flutter_windows.dll.lib",
                     "flutter_windows.dll.pdb", "gen_snapshot.exe"],
        ),
        # arm64 cross-builds from this x64 host (--windows-cpu arm64). The gn
        # wrapper appends "arm64" to the out dir (host_<mode>_arm64) and the
        # windows_flutter archive target emits windows-arm64-flutter.zip. Mirrors
        # the engine's own windows_arm_host_engine.json builder, minus --rbe (we
        # build locally, same as the x64 variants above).
        "host_debug_arm64": dict(   # cache\...\windows-arm64\
            gn_flags=["--runtime-mode=debug", "--no-lto", "--windows-cpu", "arm64"],
            ninja_targets=["windows", "gen_snapshot",
                           "flutter/build/archives:windows_flutter"],
            verify_sdk_hash=False,
            promote=["zip_archives", "flutter_windows.dll", "flutter_windows.dll.lib",
                     "flutter_windows.dll.pdb", "gen_snapshot.exe"],
        ),
        "host_release_arm64": dict(  # cache\...\windows-arm64-release\
            gn_flags=["--runtime-mode=release", "--no-lto", "--windows-cpu", "arm64"],
            ninja_targets=["windows", "gen_snapshot",
                           "flutter/build/archives:windows_flutter"],
            verify_sdk_hash=False,
            promote=["zip_archives", "flutter_windows.dll", "flutter_windows.dll.lib",
                     "flutter_windows.dll.pdb", "gen_snapshot.exe"],
        ),
    },
}


def build(ctx, variant):
    table = VARIANTS.get(ctx.platform)
    if not table:
        ctx.die(f"no build variants for host '{ctx.platform}' in 3.44.0 "
                f"(have: {', '.join(sorted(VARIANTS))})")
    cfg = table.get(variant)
    if cfg is None:
        ctx.die(f"unknown variant {variant!r} for {ctx.platform}; "
                f"choices: {', '.join(sorted(table))}")
    ctx.build_variant(variant, **cfg)
