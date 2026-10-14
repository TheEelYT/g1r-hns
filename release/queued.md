# Queued for the next gameplay release

The user requested bundling this correction into the next substantive update, without a title-only release. Mod 0.7.10 and cart 1.0.9 remain the published versions.

- Restore the original source `v2.0.6` OAM banner, including its blink synchronized with PRESS START.
- Show the manifest-derived `Mod vX.Y.Z` separately in the lower-right corner without blinking; retain source palette shading and screen fades.
- Trim the custom `0` glyph's neighboring period so version numbers have single separators.

Focused verification: 1,123 native title checks over both blink phases on each of G1R 0.3.44 and 0.3.53, 1,120 independent source glyph-mask checks, and the 19 converter tests. The new shared title checks also run in the complete native release suite. Full release validation and player confirmation belong to the next gameplay build.

Before the next release, fold these entries into `release/changes.md`, refresh README and TESTING for the actual release, and remove this queued file. Continue the existing field/terrain battle work before the next version bump.
