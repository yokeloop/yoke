---
name: game-event
description: Understanding the poker game event system and type adapters
user-invocable: false
---

# Game Event System

## Event Flow

```
Poker Server → WebSocket/EventSource → Room.tsx → gameEventReducer → GameContext → UI Components
                                                 → chatReducer → ChatContext
```

## Event Types

Events have a `$type` field. Key types in `src/reducers/gameEventReducer.ts`:

| Event | Purpose |
|-------|---------|
| `Init` | Initialize table with settings, seats, button position |
| `Me` | Synthetic event identifying current player (from JWT) |
| `Start` | New hand begins, resets wagers/cards |
| `NextRound` | Betting round changes (preflop→flop→turn→river) |
| `DealPocketCards` | Player receives hole cards |
| `DealBoardCards` | Community cards dealt |
| `RequireBet` | Player must act, includes `amount_to_call` and `raise_range` |
| `AddBet` | Player action recorded (fold/check/call/raise) |
| `ShowCards` | Showdown card reveals |
| `Winner` | Pot awarded to winner(s) |
| `ReturnUncalled` | Uncalled bet returned |
| `StackChange` | Player stack updated (rebuy/addon) |
| `RequireRebuy` | Player needs to rebuy chips |
| `SetAutoPlay` | Auto-play mode changed |

## Dual Type System

The codebase bridges server and UI types:

1. **Server Types** (`src/lib/types.ts`)
   - Match WebSocket payload format
   - snake_case field names
   - `GameState` is raw server state

2. **UI Types** (`src/lib/poker-types.ts`)
   - Designed for React components
   - camelCase field names
   - `Card`, `Seat`, `Player` structures

3. **Adapters** (`src/lib/adapters/v0-adapters.ts`)
   - `toV0Seat()` - converts server seat to UI seat
   - `toPokerTableProps()` - converts state to table props
   - `toBettingPanelProps()` - converts state to betting panel props
   - `parseCards()` - converts "AhKd" notation to Card objects

## Adding New Events

1. Add type to `GameEvent` union in `src/lib/types.ts`
2. Add handler case in `gameEventReducer.ts`
3. If UI-facing, update adapters in `v0-adapters.ts`
4. Update UI types in `poker-types.ts` if needed
