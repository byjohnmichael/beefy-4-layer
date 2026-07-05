export type Suit = 'hearts' | 'diamonds' | 'clubs' | 'spades';
export type Rank =
    | 'A'
    | '2'
    | '3'
    | '4'
    | '5'
    | '6'
    | '7'
    | '8'
    | '9'
    | '10'
    | 'J'
    | 'Q'
    | 'K'
    | 'JOKER';

export interface Card {
    id: string;
    rank: Rank;
    suit: Suit | null; // null for Jokers
}

export type PlayerId = 'P1' | 'P2';

export interface PlayerState {
    faceDown: (Card | null)[]; // null for empty slots
    hand: Card[];
}

export interface GameState {
    deck: Card[];
    centerPiles: Card[][];
    players: {
        P1: PlayerState;
        P2: PlayerState;
    };
    currentPlayer: PlayerId;
    log: string[];
    winner: PlayerId | null;
    selectedCard: { source: 'hand' | 'faceDown'; index: number } | null;
    revealedCard: Card | null; // For face-down reveal animation
    pendingPileIndex: number | null; // For resolving face-down plays
    pendingDrawGamble: Card | null; // Card being gambled from deck draw
}

export type GameAction =
    | { type: 'START_GAME' }
    | { type: 'RESET_GAME' }
    | { type: 'SELECT_HAND_CARD'; index: number }
    | { type: 'SELECT_FACEDOWN_CARD'; index: number }
    | { type: 'SELECT_PILE'; pileIndex: number }
    | { type: 'CLEAR_SELECTIONS' }
    | { type: 'DRAW_FROM_DECK' }
    | { type: 'START_DRAW_GAMBLE' }
    | { type: 'CANCEL_DRAW_GAMBLE' }
    | { type: 'PLAY_DRAW_GAMBLE'; pileIndex: number }
    | { type: 'SET_FIRST_PLAYER'; player: PlayerId }
    | { type: 'SYNC_STATE'; state: GameState };
