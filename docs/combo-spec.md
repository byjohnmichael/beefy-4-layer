# Combo Mode — Design Spec

Combo mode layers a speed/combo system on top of the base rules. Classic mode
is untouched and stays conformant with the TS engine; combo mode is a rules
fork gated by `SimState.combo_mode`.

## The combo

- A player's first successful placement in a turn starts a combo (combo = 1).
- Every subsequent successful placement (hand play, face-down flip, or
  draw-gamble) adds +1 and refills the combo timer.
- The combo timer only drains while the player can act (UI freezes it during
  animations and the opponent's turn). When it empties, the combo ends —
  the **turn does not**: the player just loses the fire and any unspent
  tolerance (`COMBO_TIMEOUT` action).
- Any failed placement ends the combo (and the turn, per base rules).
- Drawing to hand ends the combo (it ends the turn).

## Tolerance

- Tolerance is the adjacency window: at tolerance T a card within ±T of the
  pile top is playable (wrap-around included; same rank never plays).
  Base tolerance is 1.
- Every `COMBO_STEP` chained cards (test value: 3 — i.e. combo 3, 6, 9 …)
  raises tolerance by +1, capped at `TOLERANCE_MAX` (3).
- Tolerance is **live, not banked**: it lasts only until the combo ends.
- Tolerance is **consumed by use**: playing a card that needed more than ±1
  drops tolerance back to 1 immediately. Continuing the combo can re-earn it.

## The flip as climax

- The intended arc: chain cards to build tolerance, then spend it on a
  face-down flip (measured via tests/flip_stats.gd with the 52-card
  jokerless deck: ~18% at ±1, ~32% at ±2, ~46% at ±3).
- A successful flip extends the chain (+1, timer refill) and keeps the turn,
  so a monster turn chains straight through its face-down cards. A failed
  flip ends the combo and the turn.

## Sim implementation

- `SimState` gains `combo_mode: bool`, `combo: int`, `tolerance: int`.
  The fields serialize only when `combo_mode` is true, so classic-mode
  states remain byte-identical to the TS shape (conformance-safe).
- `{"type": "START_GAME", "comboMode": true}` starts a combo-mode game.
- `{"type": "COMBO_TIMEOUT"}` ends a running combo (UI dispatches it when
  the timer empties).
- All legality checks take tolerance as a parameter, defaulting to 1.

## Tuning knobs

| Knob | Location | Test value |
|---|---|---|
| Combo step (cards per tolerance tier) | `SimRules.COMBO_STEP` | 3 |
| Tolerance cap | `SimRules.TOLERANCE_MAX` | 3 |
| Combo timer window | `DesignTokens.combo_window` | 4.0 s |
