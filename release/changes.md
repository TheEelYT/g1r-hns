Changes in 0.7.6:

- Replaces Modern terrain tile guessing with source BG3 screen blocks and the separate BG1 entry map, including wraparound, scanline scroll and source entry progression. OLD terrain keeps its existing path.
- Fixes opponent name/level fill extending eight pixels past its source border in both battle UI styles.
- Uses the source light background palette for GEN 4 names/levels, while retaining the darker HP-number strip.
- Moves focused player checks into TESTING.md, removes the confirmed R-ball prompt check, and removes publishing from the port progress checklist.

Validation uses both native cache roots, converter tests, strict Modkit validation, independent source audits, a compiled source C entry oracle and native battle CPU captures. No live Windows/GPU gameplay is available here. Sprite orchestration and remaining enhanced battle mechanics/campaign work remain in progress.
