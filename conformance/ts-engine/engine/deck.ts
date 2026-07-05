import type { Card, Suit, Rank } from '../types';

const SUITS: Suit[] = ['hearts', 'diamonds', 'clubs', 'spades'];
const RANKS: Rank[] = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];

export function createDeck(): Card[] {
    const cards: Card[] = [];
    let id = 0;

    // Standard 52 cards
    for (const suit of SUITS) {
        for (const rank of RANKS) {
            cards.push({
                id: `card-${id++}`,
                rank,
                suit,
            });
        }
    }

    // Add 2 Jokers
    cards.push({ id: `card-${id++}`, rank: 'JOKER', suit: null });
    cards.push({ id: `card-${id++}`, rank: 'JOKER', suit: null });

    return cards;
}

// Injectable RNG so tests can make shuffles deterministic.
// Defaults to Math.random - web behavior is unchanged.
let rng: () => number = Math.random;

export function setRng(fn: () => number): void {
    rng = fn;
}

export function shuffle<T>(array: T[]): T[] {
    const shuffled = [...array];
    for (let i = shuffled.length - 1; i > 0; i--) {
        const j = Math.floor(rng() * (i + 1));
        [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
    }
    return shuffled;
}

export function drawCards(deck: Card[], count: number): { drawn: Card[]; remaining: Card[] } {
    const drawn = deck.slice(0, count);
    const remaining = deck.slice(count);
    return { drawn, remaining };
}

export function drawOne(deck: Card[]): { card: Card | null; remaining: Card[] } {
    if (deck.length === 0) {
        return { card: null, remaining: [] };
    }
    return { card: deck[0], remaining: deck.slice(1) };
}
