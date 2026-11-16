# The strip's prototype

`strip.html` is the strip as it was felt in the browser (DESIGN.md, "The
strip" and "How the strip moves"): open it in a browser to try it. The Swift
strip is checked against it frame by frame, through recordings of it.

`record.mjs` drives it in headless Chromium, on Playwright's fake clock at
16ms a frame, through scripted scenarios, and `fixture.mjs` writes what it
recorded into the app's tests:

- a JSON file per scenario in `app/Tests/SitRepPanelTests/Recorded/Strip`,
  which the strip's timeline tests play the model against;
- the declarations in `app/Tests/SitRepPanelTests/StripRecording.swift`,
  above its hand-written loader: each scenario's, the values beside them,
  and `widths`, each tab's width as the browser measured its words, which
  `StripLab` measures the model's tabs by.

## Recording again

On a Mac, with Bun, from this folder, once:

```bash
bun install
bunx playwright-core install chromium-headless-shell
```

Then, after changing the prototype:

```bash
bun record.mjs > recording.json
bun fixture.mjs recording.json
```

and run the app's tests. `recording.json` is git's to ignore. The fixture
needs every scenario: it writes nothing from a recording that lacks one, as
`bun record.mjs hover` makes to look at, nor into a `StripRecording.swift`
that has lost its declarations' place.

## Its sessions

The prototype's sessions are placeholders, never Lee's real projects or work
(`tests/real-names.txt`). Their words decide the tabs' widths and so their
timelines: renamed, they were chosen so each recorded tab measures what it
did, so the recordings stayed the same frame for frame. A scenario's pointer
finds a mark by its letters (`'Wi'`, `'Lu'`, `'BY'`, `'Co'` in
`record.mjs`), so a project renamed there moves with its steps.
