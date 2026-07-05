// Prints mulberry32 output (as exact 32-bit integer numerators) for a few
// seeds, to diff against godot/tests/rng_parity.gd.
import { mulberry32 } from './mulberry32.mjs';

for (const seed of [0, 1, 42, 123456789, 4294967295]) {
    const rng = mulberry32(seed);
    const parts = [];
    for (let i = 0; i < 60; i++) {
        parts.push(String(Math.floor(rng() * 4294967296)));
    }
    console.log(`${seed}:${parts.join(',')}`);
}
