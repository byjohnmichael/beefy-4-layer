import type { GameState, GameAction } from './types';
import { getLegalPiles } from './engine/rules';

/**
 * Simple bot AI that makes reasonable moves
 * Strategy:
 * 1. If we have legal hand plays, make one (prioritize getting rid of cards)
 * 2. If we have face-down cards, gamble on one
 * 3. Otherwise, draw from deck
 */
export function getBotMove(state: GameState): GameAction | null {
    if (state.currentPlayer !== 'P2') return null;
    if (state.winner) return null;

    const bot = state.players.P2;

    // Strategy 1: Play from hand if we have legal moves
    if (bot.hand.length > 0) {
        for (let i = 0; i < bot.hand.length; i++) {
            const card = bot.hand[i];
            const legalPiles = getLegalPiles(card, state.centerPiles);
            if (legalPiles.length > 0) {
                // Return the hand card selection, then we'll need to select pile
                return { type: 'SELECT_HAND_CARD', index: i };
            }
        }
    }

    // Strategy 2: Gamble with face-down card
    const faceDownIndices = bot.faceDown
        .map((card, index) => (card !== null ? index : -1))
        .filter((i) => i !== -1);

    if (faceDownIndices.length > 0) {
        // Pick a random face-down card
        const randomIndex = faceDownIndices[Math.floor(Math.random() * faceDownIndices.length)];
        return { type: 'SELECT_FACEDOWN_CARD', index: randomIndex };
    }

    // Strategy 3: Draw and gamble from deck
    if (state.deck.length > 0) {
        return { type: 'START_DRAW_GAMBLE' };
    }

    return null;
}

/**
 * Get the pile selection for bot after selecting a card or starting draw gamble
 */
export function getBotPileSelection(state: GameState): GameAction | null {
    if (state.currentPlayer !== 'P2') return null;

    // Handle draw gamble pile selection
    if (state.pendingDrawGamble) {
        // Pick a random pile for draw gamble
        const randomPile = Math.floor(Math.random() * 4);
        return { type: 'PLAY_DRAW_GAMBLE', pileIndex: randomPile };
    }

    if (!state.selectedCard) return null;

    const { source, index } = state.selectedCard;
    const bot = state.players.P2;

    if (source === 'hand') {
        // For hand plays, pick a legal pile
        const card = bot.hand[index];
        if (!card) return null;

        const legalPiles = getLegalPiles(card, state.centerPiles);
        if (legalPiles.length > 0) {
            // Pick first legal pile (could be smarter about this)
            return { type: 'SELECT_PILE', pileIndex: legalPiles[0] };
        }
    } else {
        // For face-down gamble, pick a random pile
        // Could be smarter: analyze which pile has cards closest to average
        const randomPile = Math.floor(Math.random() * 4);
        return { type: 'SELECT_PILE', pileIndex: randomPile };
    }

    return null;
}
