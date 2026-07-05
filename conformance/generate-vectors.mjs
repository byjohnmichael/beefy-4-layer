// Generates cross-language conformance vectors for the Godot port.
//
// Plays seeded games using random legal actions (plus occasional no-op /
// guard-clause actions for coverage) against the TS engine, recording every
// transition as { seed, preState, action, postState }. Before each transition
// the shared PRNG is re-seeded with a fresh recorded seed, so every
// transition - including the shuffles inside deck refresh - is independently
// reproducible in GDScript.
//
// Run with: cd conformance && npm install && npx tsx generate-vectors.mjs
// Output: ../tests/vectors/game-NNN.json.gz (one file per game)
//
// ts-engine/ is a snapshot of src/game/ from byjohnmichael/beefy4layer.com
// (plus the test-only setRng() injection in engine/deck.ts). If the web
// engine changes, refresh the snapshot and regenerate.

import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { fileURLToPath } from 'node:url';
import { gameReducer } from './ts-engine/reducer';
import { setRng } from './ts-engine/engine/deck';
import { getLegalPiles } from './ts-engine/engine/rules';
import { mulberry32 } from './mulberry32.mjs';

const NUM_GAMES = 200;
const MAX_TRANSITIONS_PER_GAME = 400;
const OUT_DIR = path.join(
    path.dirname(fileURLToPath(import.meta.url)),
    '..',
    'tests',
    'vectors',
);

// Deterministic seed stream for reducer transitions (recorded per vector).
const seedStream = mulberry32(0x5eed5eed);
function nextSeed() {
    return Math.floor(seedStream() * 4294967296) >>> 0;
}

let vectors = [];
let state = null;

function dispatch(action) {
    const seed = nextSeed();
    setRng(mulberry32(seed));
    const post = gameReducer(state, action);
    vectors.push({ seed, preState: state, action, postState: post });
    state = post;
    return post;
}

// Picks the next action for the driver: mostly sensible play, with a sprinkle
// of cancels, deselects, and guard-clause no-ops for reducer coverage.
function chooseAction(rnd) {
    if (state.pendingDrawGamble) {
        if (rnd() < 0.08) return { type: 'CANCEL_DRAW_GAMBLE' };
        return { type: 'PLAY_DRAW_GAMBLE', pileIndex: Math.floor(rnd() * 4) };
    }

    if (state.selectedCard) {
        if (rnd() < 0.05) return { type: 'CLEAR_SELECTIONS' };
        const { source, index } = state.selectedCard;
        if (source === 'hand') {
            const card = state.players[state.currentPlayer].hand[index];
            const legal = getLegalPiles(card, state.centerPiles);
            if (rnd() < 0.05) {
                // Occasionally aim at an illegal pile: reducer must no-op.
                return { type: 'SELECT_PILE', pileIndex: Math.floor(rnd() * 4) };
            }
            return { type: 'SELECT_PILE', pileIndex: legal[Math.floor(rnd() * legal.length)] };
        }
        // Face-down gamble: any pile is a valid target
        return { type: 'SELECT_PILE', pileIndex: Math.floor(rnd() * 4) };
    }

    // Guard-clause coverage: actions the reducer should treat as no-ops.
    const noopRoll = rnd();
    if (noopRoll < 0.02) return { type: 'SELECT_PILE', pileIndex: Math.floor(rnd() * 4) };
    if (noopRoll < 0.03) return { type: 'CLEAR_SELECTIONS' };
    if (noopRoll < 0.035) return { type: 'CANCEL_DRAW_GAMBLE' };
    if (noopRoll < 0.04 && state.deck.length === 0) return { type: 'DRAW_FROM_DECK' };
    if (noopRoll < 0.045) {
        // Selecting a hand card with no legal play (or an empty slot) no-ops.
        const hand = state.players[state.currentPlayer].hand;
        if (hand.length > 0) {
            return { type: 'SELECT_HAND_CARD', index: Math.floor(rnd() * hand.length) };
        }
    }

    const player = state.players[state.currentPlayer];
    const candidates = [];
    player.hand.forEach((card, i) => {
        if (getLegalPiles(card, state.centerPiles).length > 0) {
            candidates.push({ type: 'SELECT_HAND_CARD', index: i });
        }
    });
    player.faceDown.forEach((card, i) => {
        if (card !== null) {
            candidates.push({ type: 'SELECT_FACEDOWN_CARD', index: i });
        }
    });
    if (state.deck.length > 0) {
        candidates.push({ type: 'DRAW_FROM_DECK' });
        candidates.push({ type: 'START_DRAW_GAMBLE' });
    }
    if (candidates.length === 0) return null; // stuck (empty deck, no moves)
    return candidates[Math.floor(rnd() * candidates.length)];
}

fs.rmSync(OUT_DIR, { recursive: true, force: true });
fs.mkdirSync(OUT_DIR, { recursive: true });

// Dummy pre-state for START_GAME vectors (the reducer ignores it).
setRng(mulberry32(0));
state = gameReducer(null, { type: 'START_GAME' });
const dummyState = state;

let totalVectors = 0;
let finished = 0;
let stuck = 0;
let capped = 0;

for (let g = 0; g < NUM_GAMES; g++) {
    const rnd = mulberry32(0xac710000 + g); // action-choice RNG, per game
    vectors = [];
    state = dummyState;

    dispatch({ type: 'START_GAME' });
    if (rnd() < 0.3) {
        dispatch({ type: 'SET_FIRST_PLAYER', player: rnd() < 0.5 ? 'P1' : 'P2' });
    }

    let steps = 0;
    while (!state.winner && steps < MAX_TRANSITIONS_PER_GAME) {
        const action = chooseAction(rnd);
        if (!action) {
            stuck++;
            break;
        }
        dispatch(action);
        steps++;
    }
    if (state.winner) finished++;
    if (steps >= MAX_TRANSITIONS_PER_GAME) capped++;

    const json = JSON.stringify({ game: g, vectors });
    fs.writeFileSync(
        path.join(OUT_DIR, `game-${String(g).padStart(3, '0')}.json.gz`),
        zlib.gzipSync(json),
    );
    totalVectors += vectors.length;
}

console.log(
    `Generated ${totalVectors} vectors across ${NUM_GAMES} games ` +
        `(${finished} finished with a winner, ${capped} hit the ${MAX_TRANSITIONS_PER_GAME}-step cap, ${stuck} stuck/no-moves)`,
);
