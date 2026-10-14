# 0.7.15 checkpoint

User requested Pokégear label ink matching, GB channel-loss fix (Pokémart), walking stutter fix, persistent field shadows, follower grass rustles, and planned source ability assignment. Only latest G1R is to be tested. Latest verified release is 0.3.86, commit 49d289ce9c00d9586c8b39a44a305c16f38b7b8e; pinned source HnS 167aa6d537b109bb229c231ddce4616974c4da71.

Reapplied runtime/converter/tests after session restart. Build succeeds; converter 19 tests pass. Full suite/source audits/CPU captures/install compression still need completion. Runtime manifest intentionally remains 0.7.14 to prevent publishing unfinished work. Update to 0.7.15 / cart 1.0.14 only when release is ready. README, TESTING.md, release notes and validation report need updates. Remove confirmed sounds and follower running tests; retain walking, shadows, grass and GB listening checks. Remove this checkpoint file in final release.

Build with build_port.py --source ../pokehns-expansion --engine ../gen1recomp-latest --out ../build/hns_v0715_release. Run tests/test_native.lua with default and mounted roots from that engine directory; tests/test_installed_assets.py against same latest engine; seven check_*.py audits and render_source_ui.py; strict Modkit and release.py. Do not package resume_probe after runtime refresh; use canonical fresh build.

Publish using GitHub connector create_tree/create_commit/update_ref. User authorizes main commits/releases. Workflow triggers on runtime/manifest.json. Wait for CI and verify published ZIP/cart SHA256 against local deterministic release. Reserve Mod 1.0 for full parity. Expanded effect/acquisition/randomizer/weather rules remain unfinished.
