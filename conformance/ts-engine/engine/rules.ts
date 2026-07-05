import type { Card, Rank } from '../types';

// Rank values for adjacency checking (A=1, J=11, Q=12, K=13)
const RANK_VALUES: Record<Rank, number> = {
    A: 1,
    '2': 2,
    '3': 3,
    '4': 4,
    '5': 5,
    '6': 6,
    '7': 7,
    '8': 8,
    '9': 9,
    '10': 10,
    J: 11,
    Q: 12,
    K: 13,
    JOKER: 0, // Special case
};

/**
 * Check if two ranks are adjacent (wrap-around enabled)
 * A is adjacent to K and 2
 * K is adjacent to Q and A
 */
export function isAdjacent(rank1: Rank, rank2: Rank): boolean {
    // Jokers are always adjacent to everything
    if (rank1 === 'JOKER' || rank2 === 'JOKER') {
        return true;
    }

    const val1 = RANK_VALUES[rank1];
    const val2 = RANK_VALUES[rank2];

    const diff = Math.abs(val1 - val2);

    // Adjacent if difference is 1, or wrap-around (K-A = 12)
    return diff === 1 || diff === 12;
}

/**
 * Check if a card can be played on a pile
 */
export function canPlay(card: Card | undefined | null, pileTop: Card | undefined | null): boolean {
    // Safety check - if either card is missing, can't play
    if (!card || !pileTop) {
        console.warn('[canPlay] Missing card or pileTop:', { card, pileTop });
        return false;
    }

    // Joker card can always be played (wild)
    if (card.rank === 'JOKER') {
        return true;
    }

    // Joker on top means any card can be played (free space)
    if (pileTop.rank === 'JOKER') {
        return true;
    }

    // Check adjacency
    return isAdjacent(card.rank, pileTop.rank);
}

/**
 * Get all legal pile indices for a card
 */
export function getLegalPiles(card: Card | undefined | null, centerPiles: Card[][]): number[] {
    // Safety check - if card is missing, no legal piles
    if (!card) {
        console.warn('[getLegalPiles] Card is undefined or null');
        return [];
    }

    const legalPiles: number[] = [];

    for (let i = 0; i < centerPiles.length; i++) {
        const pile = centerPiles[i];
        if (pile.length > 0) {
            const topCard = pile[pile.length - 1];
            if (canPlay(card, topCard)) {
                legalPiles.push(i);
            }
        }
    }

    return legalPiles;
}

/**
 * Check if a player has any legal hand plays
 */
export function hasLegalHandPlay(hand: Card[], centerPiles: Card[][]): boolean {
    for (const card of hand) {
        if (getLegalPiles(card, centerPiles).length > 0) {
            return true;
        }
    }
    return false;
}

// Unicode Variation Selector-15 forces text rendering instead of emoji on mobile
export const VS15 = '\uFE0E';

// Pre-built symbols with VS15 for convenience
export const SYMBOLS = {
    spade: '♠' + '\uFE0E',
    heart: '♥' + '\uFE0E',
    diamond: '♦' + '\uFE0E',
    club: '♣' + '\uFE0E',
    star: '★' + '\uFE0E',
} as const;

/**
 * Get rank display string
 */
export function getRankDisplay(rank: Rank): string {
    if (rank === 'JOKER') return '★' + VS15;
    return rank;
}

/**
 * Get back symbol (with VS15 to prevent emoji rendering on mobile)
 */
export function getBackSymbol(symbol: 'spade' | 'diamond'): string {
    return symbol === 'spade' ? '♠' + VS15 : '♦' + VS15;
}

/**
 * Get suit symbol (with VS15 to prevent emoji rendering on mobile)
 */
export function getSuitSymbol(suit: string | null): string {
    switch (suit) {
        case 'hearts':
            return '♥' + VS15;
        case 'diamonds':
            return '♦' + VS15;
        case 'clubs':
            return '♣' + VS15;
        case 'spades':
            return '♠' + VS15;
        default:
            return '';
    }
}

/**
 * Get card color (red or black)
 */
export function getCardColor(card: Card): 'red' | 'black' | 'gold' {
    if (card.rank === 'JOKER') return 'gold';
    if (card.suit === 'hearts' || card.suit === 'diamonds') return 'red';
    return 'black';
}
