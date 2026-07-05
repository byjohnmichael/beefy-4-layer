import type { GameState, GameAction, PlayerId, Card } from './types';
import { createInitialState } from './initialState';
import { canPlay, getLegalPiles, getRankDisplay } from './engine/rules';
import { drawOne } from './engine/deck';
import { refreshCenterPiles } from './engine/refresh';

function checkWinner(state: GameState): PlayerId | null {
    for (const playerId of ['P1', 'P2'] as PlayerId[]) {
        const player = state.players[playerId];
        const hasFaceDown = player.faceDown.some((card) => card !== null);
        if (!hasFaceDown && player.hand.length === 0) {
            return playerId;
        }
    }
    return null;
}

function getOpponent(player: PlayerId): PlayerId {
    return player === 'P1' ? 'P2' : 'P1';
}

function addLog(state: GameState, message: string): GameState {
    return {
        ...state,
        log: [...state.log, message],
    };
}

function getPileTopRank(pile: Card[]): string {
    if (pile.length === 0) return '?';
    return getRankDisplay(pile[pile.length - 1].rank);
}

export function gameReducer(state: GameState, action: GameAction): GameState {
    switch (action.type) {
        case 'START_GAME':
        case 'RESET_GAME':
            return createInitialState();

        case 'SELECT_HAND_CARD': {
            if (state.winner) return state;

            const player = state.players[state.currentPlayer];
            const card = player.hand[action.index];
            if (!card) return state;

            // Check if card has any legal plays
            const legalPiles = getLegalPiles(card, state.centerPiles);
            if (legalPiles.length === 0) {
                // Card has no legal plays, cannot select
                return state;
            }

            return {
                ...state,
                selectedCard: { source: 'hand', index: action.index },
                revealedCard: null,
                pendingPileIndex: null,
            };
        }

        case 'SELECT_FACEDOWN_CARD': {
            if (state.winner) return state;

            const player = state.players[state.currentPlayer];
            const card = player.faceDown[action.index];
            if (!card) return state; // Empty slot

            return {
                ...state,
                selectedCard: { source: 'faceDown', index: action.index },
                revealedCard: null,
                pendingPileIndex: null,
            };
        }

        case 'SELECT_PILE': {
            if (state.winner) return state;
            if (!state.selectedCard) return state;

            const { source, index } = state.selectedCard;
            const player = state.players[state.currentPlayer];
            const pile = state.centerPiles[action.pileIndex];
            const pileTop = pile[pile.length - 1];

            if (source === 'hand') {
                // Hand play - must be legal (already checked when selecting)
                const card = player.hand[index];
                if (!card || !canPlay(card, pileTop)) {
                    return state;
                }

                // Success! Place card on pile
                const newHand = [...player.hand];
                newHand.splice(index, 1);

                const newCenterPiles = [...state.centerPiles];
                newCenterPiles[action.pileIndex] = [...pile, card];

                let newState: GameState = {
                    ...state,
                    centerPiles: newCenterPiles,
                    players: {
                        ...state.players,
                        [state.currentPlayer]: {
                            ...player,
                            hand: newHand,
                        },
                    },
                    selectedCard: null,
                };

                newState = addLog(
                    newState,
                    `${state.currentPlayer} played ${getRankDisplay(card.rank)} on pile ${getPileTopRank([pileTop])} (success)`,
                );

                // Check for win
                const winner = checkWinner(newState);
                if (winner) {
                    newState = addLog(newState, `${winner} wins!`);
                    return { ...newState, winner };
                }

                // Extra turn - stay on same player
                return newState;
            } else {
                // Face-down gamble play
                const card = player.faceDown[index];
                if (!card) return state;

                // Reveal the card
                const isSuccess = canPlay(card, pileTop);

                if (isSuccess) {
                    // Success! Place card on pile, remove from face-down row
                    const newFaceDown = [...player.faceDown];
                    newFaceDown[index] = null;

                    const newCenterPiles = [...state.centerPiles];
                    newCenterPiles[action.pileIndex] = [...pile, card];

                    let newState: GameState = {
                        ...state,
                        centerPiles: newCenterPiles,
                        players: {
                            ...state.players,
                            [state.currentPlayer]: {
                                ...player,
                                faceDown: newFaceDown,
                            },
                        },
                        selectedCard: null,
                        revealedCard: card,
                        pendingPileIndex: action.pileIndex,
                    };

                    newState = addLog(
                        newState,
                        `${state.currentPlayer} flipped ${getRankDisplay(card.rank)} on pile ${getPileTopRank([pileTop])} (success)`,
                    );

                    // Check for win
                    const winner = checkWinner(newState);
                    if (winner) {
                        newState = addLog(newState, `${winner} wins!`);
                        return { ...newState, winner };
                    }

                    // Extra turn - stay on same player
                    return newState;
                } else {
                    // Failure! Card goes to hand, draw replacement
                    const newHand = [...player.hand, card];
                    const newFaceDown = [...player.faceDown];

                    // Draw replacement card
                    let { card: replacementCard, remaining: newDeck } = drawOne(state.deck);
                    let newCenterPiles = state.centerPiles;

                    // Check if deck is now empty - trigger refresh
                    let refreshLog: string | null = null;
                    if (newDeck.length === 0 && replacementCard !== null) {
                        // The deck just became empty after drawing - refresh!
                        const refreshed = refreshCenterPiles(state.centerPiles);
                        newDeck = refreshed.newDeck;
                        newCenterPiles = refreshed.newCenterPiles;
                        refreshLog = 'Deck refreshed (center piles reshuffled)';
                    }

                    // Place replacement in face-down slot
                    newFaceDown[index] = replacementCard;

                    let newState: GameState = {
                        ...state,
                        deck: newDeck,
                        centerPiles: newCenterPiles,
                        players: {
                            ...state.players,
                            [state.currentPlayer]: {
                                ...player,
                                hand: newHand,
                                faceDown: newFaceDown,
                            },
                        },
                        currentPlayer: getOpponent(state.currentPlayer),
                        selectedCard: null,
                        revealedCard: card,
                        pendingPileIndex: action.pileIndex,
                    };

                    newState = addLog(
                        newState,
                        `${state.currentPlayer} flipped ${getRankDisplay(card.rank)} on pile ${getPileTopRank([pileTop])} (fail), moved to hand`,
                    );

                    if (refreshLog) {
                        newState = addLog(newState, refreshLog);
                    }

                    newState = addLog(newState, `${newState.currentPlayer}'s turn`);

                    return newState;
                }
            }
        }

        case 'CLEAR_SELECTIONS':
            return {
                ...state,
                selectedCard: null,
                revealedCard: null,
                pendingPileIndex: null,
                pendingDrawGamble: null,
            };

        case 'DRAW_FROM_DECK': {
            if (state.winner) return state;
            if (state.deck.length === 0) return state;

            const player = state.players[state.currentPlayer];

            // Draw one card from deck
            let { card: drawnCard, remaining: newDeck } = drawOne(state.deck);
            if (!drawnCard) return state;

            let newCenterPiles = state.centerPiles;
            let refreshLog: string | null = null;

            // Check if deck is now empty - trigger refresh
            if (newDeck.length === 0) {
                const refreshed = refreshCenterPiles(state.centerPiles);
                newDeck = refreshed.newDeck;
                newCenterPiles = refreshed.newCenterPiles;
                refreshLog = 'Deck refreshed (center piles reshuffled)';
            }

            const newHand = [...player.hand, drawnCard];

            let newState: GameState = {
                ...state,
                deck: newDeck,
                centerPiles: newCenterPiles,
                players: {
                    ...state.players,
                    [state.currentPlayer]: {
                        ...player,
                        hand: newHand,
                    },
                },
                currentPlayer: getOpponent(state.currentPlayer),
                selectedCard: null,
            };

            newState = addLog(newState, `${state.currentPlayer} drew a card from deck`);

            if (refreshLog) {
                newState = addLog(newState, refreshLog);
            }

            newState = addLog(newState, `${newState.currentPlayer}'s turn`);

            return newState;
        }

        case 'START_DRAW_GAMBLE': {
            if (state.winner) return state;
            if (state.deck.length === 0) return state;

            // Peek at the top card of the deck (don't remove it yet)
            const cardToGamble = state.deck[state.deck.length - 1];

            return {
                ...state,
                pendingDrawGamble: cardToGamble,
                selectedCard: null, // Clear any hand/face-down selection
            };
        }

        case 'CANCEL_DRAW_GAMBLE': {
            return {
                ...state,
                pendingDrawGamble: null,
            };
        }

        case 'PLAY_DRAW_GAMBLE': {
            if (state.winner) return state;
            if (!state.pendingDrawGamble) return state;

            const card = state.pendingDrawGamble;
            const player = state.players[state.currentPlayer];
            const pile = state.centerPiles[action.pileIndex];
            const pileTop = pile[pile.length - 1];

            // Remove the card from deck
            const newDeck = state.deck.slice(0, -1);

            // Check if play is successful
            const isSuccess = canPlay(card, pileTop);

            if (isSuccess) {
                // Success! Place card on pile
                const newCenterPiles = [...state.centerPiles];
                newCenterPiles[action.pileIndex] = [...pile, card];

                let newState: GameState = {
                    ...state,
                    deck: newDeck,
                    centerPiles: newCenterPiles,
                    pendingDrawGamble: null,
                    revealedCard: card,
                    pendingPileIndex: action.pileIndex,
                };

                newState = addLog(
                    newState,
                    `${state.currentPlayer} drew and played ${getRankDisplay(card.rank)} on pile ${getPileTopRank([pileTop])} (success)`,
                );

                // Check for win (unlikely from draw but possible)
                const winner = checkWinner(newState);
                if (winner) {
                    newState = addLog(newState, `${winner} wins!`);
                    return { ...newState, winner };
                }

                // Extra turn - stay on same player
                return newState;
            } else {
                // Failure! Card goes to hand
                const newHand = [...player.hand, card];

                // Check if deck is now empty - trigger refresh
                let finalDeck = newDeck;
                let newCenterPiles = state.centerPiles;
                let refreshLog: string | null = null;

                if (finalDeck.length === 0) {
                    const refreshed = refreshCenterPiles(state.centerPiles);
                    finalDeck = refreshed.newDeck;
                    newCenterPiles = refreshed.newCenterPiles;
                    refreshLog = 'Deck refreshed (center piles reshuffled)';
                }

                let newState: GameState = {
                    ...state,
                    deck: finalDeck,
                    centerPiles: newCenterPiles,
                    players: {
                        ...state.players,
                        [state.currentPlayer]: {
                            ...player,
                            hand: newHand,
                        },
                    },
                    currentPlayer: getOpponent(state.currentPlayer),
                    pendingDrawGamble: null,
                    revealedCard: card,
                    pendingPileIndex: action.pileIndex,
                };

                newState = addLog(
                    newState,
                    `${state.currentPlayer} drew and played ${getRankDisplay(card.rank)} on pile ${getPileTopRank([pileTop])} (fail), moved to hand`,
                );

                if (refreshLog) {
                    newState = addLog(newState, refreshLog);
                }

                newState = addLog(newState, `${newState.currentPlayer}'s turn`);

                return newState;
            }
        }

        case 'SET_FIRST_PLAYER': {
            return {
                ...state,
                currentPlayer: action.player,
            };
        }

        case 'SYNC_STATE': {
            // Replace entire state with synced state from server
            return action.state;
        }

        default:
            return state;
    }
}
