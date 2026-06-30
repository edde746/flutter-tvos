"""Build variants for the Flutter 3.41.6 engine (tvOS only — no Windows series).

Loaded on demand by engine.py `build`. The generic gn -> ninja -> promote
pipeline lives in engine.py's Ctx.build_variant; this file is the variant
table. Every variant overrides verify_sdk_hash because our patched Dart's SDK
hash won't match the prebuilt dart-sdk.

  python engine.py build 3.41.6 <variant>
"""

VARIANTS = {
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
        "host_release": dict(  # macOS host tools (frontend_server, gen_snapshot)
            gn_flags=["--no-lto", "--runtime-mode=release"],
            ninja_targets=["flutter"],
            verify_sdk_hash=True,
            promote="all",
        ),
    },
}


def build(ctx, variant):
    table = VARIANTS.get(ctx.platform)
    if not table:
        ctx.die(f"no build variants for host '{ctx.platform}' in 3.41.6 "
                f"(have: {', '.join(sorted(VARIANTS))})")
    cfg = table.get(variant)
    if cfg is None:
        ctx.die(f"unknown variant {variant!r} for {ctx.platform}; "
                f"choices: {', '.join(sorted(table))}")
    ctx.build_variant(variant, **cfg)
