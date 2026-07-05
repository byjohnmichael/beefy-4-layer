import type { Card } from '../types';
import { shuffle, drawCards } from './deck';

export function refreshCenterPiles(centerPiles: Card[][]): {
    newDeck: Card[];
    newCenterPiles: Card[][];
} {
    // Collect ALL cards from center piles
    const allCards: Card[] = [];
    for (const pile of centerPiles) {
        allCards.push(...pile);
    }

    // Shuffle to form new deck
    const shuffledDeck = shuffle(allCards);

    // Deal 4 new face-up cards as center piles
    const { drawn, remaining } = drawCards(shuffledDeck, 4);

    const newCenterPiles = drawn.map((card) => [card]);

    return {
        newDeck: remaining,
        newCenterPiles,
    };
}
