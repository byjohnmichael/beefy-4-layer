# Beefy 4 Layer

Godot 4 build of Beefy 4 Layer — a card game where players race to empty
their hand and four face-down "layers" onto center piles (±1 rank adjacency,
K↔A wraps, Jokers wild). Singleplayer vs bot; targeting iOS/Android, console
later.

The game rules are a verified 1:1 port of the TypeScript engine from
[byjohnmichael/beefy4layer.com](https://github.com/byjohnmichael/beefy4layer.com)
(`src/game/`), proven by replaying 70k+ recorded engine transitions through
the GDScript reducer (see Tests).

Requires **Godot 4.x** (built against 4.6.1, binary at
`/Applications/Godot.app/Contents/MacOS/Godot`).

## Run the game

```bash
# From the repo root:
/Applications/Godot.app/Contents/MacOS/Godot --path .

# Or export a macOS app (needs export templates; see below):
mkdir -p dist/macos
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "macOS"
open dist/macos/Beefy4Layer.app
```

Export templates: download `Godot_v4.6.1-stable_export_templates.tpz` from the
Godot GitHub releases, then unzip `templates/macos.zip` (and `templates/ios.zip`
for iPhone) into
`~/Library/Application Support/Godot/export_templates/4.6.1.stable/`.

## Run on iPhone

The iOS preset generates an Xcode project (it does not build an .ipa directly):

```bash
mkdir -p dist/ios
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "iOS"
open dist/ios/Beefy4Layer.xcodeproj
```

In Xcode: select the Beefy4Layer target → Signing & Capabilities → pick your
team, plug in your iPhone, select it as the run destination, and hit Run.
First deploy to a personal device needs Settings → General → VPN & Device
Management → trust the developer cert.

Notes:
- The generated project under `dist/` is a build artifact — regenerate after
  any game change (the .pck is baked at export time).
- Device (arm64) builds verified working; the iOS **Simulator** is not — the
  stock Godot template ships an x86_64-only simulator library. Test on device.
- App icon is `icon_1024.png`, regenerable via
  `godot --headless --path . --script res://tests/make_icon.gd`.

## Architecture

- `sim/` — pure game logic, no scene/rendering dependencies. Mirrors the web
  engine file-for-file (`sim_reducer.gd` ↔ `reducer.ts`, etc.).
  `mulberry32.gd` is a seedable PRNG bit-identical to
  `conformance/mulberry32.mjs`; `SimDeck.set_rng()` mirrors `setRng()` in the
  TS engine so identical seeds produce identical shuffles across languages.
- `ui/` — pure view layer. Screens dispatch action dictionaries to
  `SimReducer`, render the resulting state, and animate the diff. No game
  rules in UI code. Every color/radius/font size/duration lives in
  `ui/theme/tokens.tres` (`DesignTokens`).
- `conformance/` — vector generator + `ts-engine/`, a snapshot of the web
  repo's `src/game/` (the authoritative rules spec) with a test-only
  `setRng()` addition. If the web engine changes, refresh the snapshot and
  regenerate vectors.
- `docs/prototype-spec.md` — the original prototype build spec.

## Tests

```bash
# 1. Generate conformance vectors from the TS engine:
cd conformance && npm install && npx tsx generate-vectors.mjs && cd ..

# 2. Replay every recorded TS transition through the GDScript reducer:
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/conformance_runner.gd

# 3. Bot-vs-bot soak + invariants (1,000 games):
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/soak_test.gd

# 4. RNG parity spot check (diff against: node conformance/rng-parity.mjs):
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/rng_parity.gd

# 5. Screenshot harness — drives a real rendered game (not headless):
/Applications/Godot.app/Contents/MacOS/Godot --path . res://tests/screenshot_harness.tscn
```

Vectors land in `tests/vectors/` (gitignored, regenerable); screenshots in
`screenshots/`.
