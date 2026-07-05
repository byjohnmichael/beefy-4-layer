# Task: Build the "Beefy 4 Layer" Godot 4 Prototype

You are working in the repo for beefy4layer.com — a React/TypeScript web version of a real-life card game. Your job is to build a **singleplayer Godot 4 prototype** of this game in a new `godot/` directory at the repo root. This is a base prototype we will build the real iOS/Android (and later console) releases on top of, so correctness and clean architecture matter more than feature count.

## Ground rules

- **The TypeScript game logic is the authoritative spec.** Read `src/game/` first: `types.ts`, `reducer.ts`, `initialState.ts`, `bot.ts`, and `engine/rules.ts`, `engine/deck.ts`, `engine/refresh.ts`. It is pure TS (no React/DOM) — every rule you need is there. Do not invent or "fix" rules; port them exactly.
- **Do not change web app behavior.** You may make minimal refactors to `src/game/` for testability (see RNG injection below) but defaults must preserve current behavior, and `npm run build` + `npm run lint` must still pass.
- **Out of scope:** multiplayer/Supabase, sound, multiple themes, coin-flip fanfare, iOS/Android export, app store anything. Singleplayer vs. the existing bot only.
- Work on a branch `godot-prototype`. Commit at each milestone below.

## Rules summary (verify every detail against the source)

- Deck: 52 cards + 2 Jokers. Setup: each player gets 4 face-down cards ("layers"), 4 center piles each start with one face-up card, rest is the draw deck. Coin flip decides first player (in the prototype: random, brief indicator, no fanfare).
- Legality: a card plays on a pile if its rank is ±1 from the pile's top (A=1 … K=13, with K↔A wrap). Jokers are wild both ways (playing one, or playing onto one).
- Turn actions:
  1. **Hand play** — only selectable if it has a legal pile; success = extra turn (chain plays).
  2. **Face-down gamble** — flip one of your layers onto a chosen pile blind. Success: it stays, extra turn. Failure: card goes into your hand, the slot is **refilled from the deck**, turn passes.
  3. **Draw to hand** — take top deck card into hand, turn passes.
  4. **Draw gamble** — flip the top deck card onto a chosen pile. Success: extra turn. Failure: it joins your hand, turn passes.
- Deck refresh: whenever the deck empties, all center-pile cards are collected, shuffled into a new deck, and 4 new single-card piles are dealt. (Note the exact trigger points in the reducer — it happens mid-transition in several places.)
- Win: a player with an empty hand and no face-down cards wins. Wins can occur mid-chain; check the reducer's `checkWinner` placement.

## Milestone 1 — Engine port + conformance proof (do this before ANY UI)

Port the sim to GDScript under `godot/sim/`: card/state types, `reducer` (state, action) → state, rules, deck, refresh, and the bot. Requirements:

- Pure logic: no Node/rendering/scene dependencies. Static typing throughout. Deterministic given an injected RNG.
- **RNG injection (the subtle part):** the TS engine calls `Math.random` inside `shuffle` (used by `createInitialState` and `refreshCenterPiles`, which runs *inside* reducer transitions). For cross-language conformance you need identical randomness:
  1. In `src/game/engine/deck.ts`, add a module-level injectable RNG (e.g. `setRng(fn)`) defaulting to `Math.random` — web behavior unchanged.
  2. Implement the same seedable PRNG (mulberry32) in both TS (test-only) and GDScript, and port the Fisher–Yates `shuffle` loop *exactly* (same iteration order, same index math) so identical seeds produce identical shuffles.
- **Vector generation:** write `scripts/generate-vectors.mjs` (run with the repo's Node toolchain; the TS engine can be imported via `tsx` or compiled with `tsc`) that plays ~200 seeded games using random legal actions and records transitions as JSON into `godot/tests/vectors/`. Before each transition, re-seed the shared PRNG with a fresh recorded seed and store it in the vector: `{ seed, preState, action, postState }`. This makes every transition independently reproducible, including the shuffles inside refresh.
- **Conformance runner:** `godot/tests/` GDScript script runnable headless (`godot --headless --script ...` or gdUnit4 if you prefer) that loads every vector, seeds the PRNG, applies the action to preState, and deep-compares against postState. **100% must pass.** Also add property checks across full simulated games: total card multiset is conserved (54 cards, no dupes/losses), games terminate, only legal states reachable.
- Also run bot-vs-bot autoplay headless for ~1,000 games as a crash/termination soak test.

**Checkpoint: report conformance results before starting UI.**

## Milestone 2 — Playable UI

Portrait, mobile-first. Base resolution **1080×1920**, `canvas_items` stretch mode, `expand` aspect so it letterboxes gracefully in a desktop window.

Layout (top → bottom): opponent's face-down row + hand-size indicator · deck + 4 center piles in the middle band · your 4 face-down slots · your hand fanned at the bottom, thumb-reachable.

Interactions (mirror the web version's flow — skim `src/screens/Game.tsx` for reference, but simplify freely):
- Tap a hand card → select + highlight legal piles → tap pile to play. Tap elsewhere/again to deselect. Cards with no legal play are visibly dimmed/unselectable.
- Tap a face-down card → select → tap any pile to gamble.
- Deck offers both actions: draw-to-hand and draw-gamble (e.g. tap deck → small two-option prompt). Keep it one-tap-ish and obvious.
- Bot moves on a short delay so its turns are readable.

Visual direction: **fresh, minimal, flat** — but smooth and snappy, and structured to restyle later. Put every color/radius/font/duration in a single theme resource (`godot/ui/theme/`) — design tokens, not hardcoded values. Draw card faces procedurally or as simple vector-style assets (rank + suit glyph, rounded rect); gold star for Jokers. Clean win overlay with a play-again button.

Animations (tweens, ~150–300ms, ease-out, snappy — never block input longer than necessary): opening deal, card flying from hand to pile, face-down flip reveal (succeed → settles on pile; fail → flies to your hand and replacement slides into the slot), draw to hand, draw-gamble flip, deck refresh gather-and-redeal, subtle turn indicator.

The scene layer must be a **pure view over the sim**: UI dispatches actions, renders resulting state, and animates the diff. No game rules in UI code.

## Milestone 3 — Verify, polish, deliver

- Launch the real rendered game yourself, screenshot key states (title, mid-game, selection highlights, gamble reveal, win overlay), and inspect/iterate on layout and readability. Play at least one full game end-to-end via scripted input or manual-style interaction if possible.
- Re-run the full conformance + soak suites.
- Produce a runnable macOS export (download export templates headlessly) or, at minimum, verify the project runs cleanly from the Godot editor/CLI and document the exact run command.
- Final report: what was built, test results (conformance pass count, soak stats), screenshots, how to run it, and a short list of known rough edges / suggested next steps.

## Environment notes

- Godot is installed at `/Applications/Godot.app` (binary: `/Applications/Godot.app/Contents/MacOS/Godot`). **Verify it's 4.x** (`--version`); if it's 3.x, `brew install --cask godot` for 4.x. Xcode 26 and Homebrew are present. Node/npm work in this repo.
- Godot runs headless with `--headless`; use that for all automated testing.
- `.tscn`/`.tres` are text formats — author them directly; keep scenes small and composable (Card, Pile, Hand, FaceDownRow, GameScreen, TitleScreen).

## Working style

- Checkpoint with the user after Milestone 1 (conformance proof) and Milestone 2 (first playable screenshots). Otherwise work autonomously — build, run, screenshot, fix in a loop rather than assuming things render correctly.
- If the TS source and this document ever disagree, the TS source wins — flag the discrepancy in your report.
