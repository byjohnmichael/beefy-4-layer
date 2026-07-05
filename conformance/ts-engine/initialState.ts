import type { GameState } from './types';
import { createDeck, shuffle, drawCards } from './engine/deck';

export function createInitialState(): GameState {
    const deck = shuffle(createDeck());

    // Deal 4 face-down cards to each player
    const { drawn: p1FaceDown, remaining: afterP1 } = drawCards(deck, 4);
    const { drawn: p2FaceDown, remaining: afterP2 } = drawCards(afterP1, 4);

    // Deal 4 face-up cards as center piles
    const { drawn: centerCards, remaining: finalDeck } = drawCards(afterP2, 4);
    const centerPiles = centerCards.map((card) => [card]);

    return {
        deck: finalDeck,
        centerPiles,
        players: {
            P1: {
                faceDown: p1FaceDown,
                hand: [],
            },
            P2: {
                faceDown: p2FaceDown,
                hand: [],
            },
        },
        currentPlayer: 'P1',
        log: ["Game started! P1's turn"],
        winner: null,
        selectedCard: null,
        revealedCard: null,
        pendingPileIndex: null,
        pendingDrawGamble: null,
    };
}
