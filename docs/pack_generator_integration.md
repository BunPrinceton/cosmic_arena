# PackGenerator System - Integration Guide

## Overview

The `PackGenerator` system is a **pure, UI-independent module** for generating card pack contents. It extracts all game logic from `PackOpening.gd` into a testable, deterministic system.

## Files Created

### 1. `scripts/systems/pack_generator.gd`
- **Class:** `PackGenerator` (extends RefCounted)
- **Purpose:** Pure pack generation logic
- **Key Feature:** Deterministic with optional seeding

### 2. `scripts/systems/pack_generator_example.gd`
- **Purpose:** Demonstrates usage patterns
- **Shows:** Random vs seeded generation, batch operations, determinism verification

## Core API

### Main Function

```gdscript
static func generate_pack(
    pack_type: PackType,
    card_pool: Array[CardData],
    seed: int = -1
) -> Array[CardData]
```

**Parameters:**
- `pack_type`: BASIC, PREMIUM, or LEGENDARY
- `card_pool`: Array of available CardData to draw from
- `seed`: RNG seed (-1 = random, any other int = deterministic)

**Returns:** Sorted array of cards (common → legendary)

**Guarantees:**
- Same seed + same pool = identical results every time
- No side effects
- No UI dependencies
- No signals
- Pure function

### Helper Functions

```gdscript
# Generate multiple packs at once
static func generate_multiple_packs(
    pack_type: PackType,
    card_pool: Array[CardData],
    count: int,
    base_seed: int = -1
) -> Array

# Get pack configuration details
static func get_pack_odds(pack_type: PackType) -> Dictionary
```

## Usage Examples

### Example 1: Random Pack (Current Behavior)

```gdscript
var card_pool = GameState.get_card_pool()
var pack = PackGenerator.generate_pack(
    PackGenerator.PackType.PREMIUM,
    card_pool,
    -1  # Random
)
# Returns: Array[CardData] with 5 random cards
```

### Example 2: Deterministic Pack (Testing)

```gdscript
# Generate a specific pack for unit testing
var pack = PackGenerator.generate_pack(
    PackGenerator.PackType.BASIC,
    test_card_pool,
    12345  # Fixed seed
)
# Always returns the same 4 cards in same order
```

### Example 3: Server-Side Generation

```gdscript
# Server generates pack with seed
var server_seed = 98765
var server_pack = PackGenerator.generate_pack(
    PackGenerator.PackType.LEGENDARY,
    full_card_pool,
    server_seed
)

# Client verifies with same seed
var client_pack = PackGenerator.generate_pack(
    PackGenerator.PackType.LEGENDARY,
    full_card_pool,
    server_seed
)

# server_pack == client_pack (guaranteed identical)
```

## Integration Plan

### Current State
- ✅ `PackGenerator` system created and ready
- ✅ Comments added to `PackOpening.gd` showing integration points
- ⚠️ **PackOpening.gd still uses old logic** (not yet refactored)

### Functions Marked for Removal

The following functions in `PackOpening.gd` will be **removed** after integration:

1. `_generate_pack_cards()` - Replace with `PackGenerator.generate_pack()`
2. `_roll_card()` - Logic moved to `PackGenerator._roll_card()`
3. `_roll_rarity()` - Logic moved to `PackGenerator._roll_rarity()`
4. `_create_placeholder_card()` - Logic moved to `PackGenerator._create_placeholder_card()`

### Future Integration (2-line change)

In `PackOpening.gd`, replace entire `_generate_pack_cards()` function body with:

```gdscript
func _generate_pack_cards() -> void:
    var pack_type_mapped = current_pack_type as PackGenerator.PackType
    opened_cards = PackGenerator.generate_pack(pack_type_mapped, card_pool, -1)
    pack_opened.emit(opened_cards)
```

**Impact:** ~80 lines of code removed, logic centralized

## Benefits

### 1. **Testability**
```gdscript
func test_legendary_guarantees():
    var pack = PackGenerator.generate_pack(
        PackGenerator.PackType.LEGENDARY,
        test_pool,
        42
    )
    assert(pack.any(func(c): return c.rarity == CardData.Rarity.EPIC))
```

### 2. **Reproducibility**
- Same seed always produces identical results
- Can audit/verify pack openings
- Replay pack animations with known results

### 3. **Separation of Concerns**
- Game logic: `PackGenerator` (pure)
- Presentation: `PackOpening` (UI only)
- Data: `CardData` (resources)

### 4. **Server-Client Validation**
- Server generates pack with seed
- Sends seed + results to client
- Client verifies by regenerating with same seed
- Anti-cheat protection

## Migration Checklist

When ready to integrate:

- [ ] Update `PackOpening._generate_pack_cards()` to call `PackGenerator.generate_pack()`
- [ ] Remove `_roll_card()`, `_roll_rarity()`, `_create_placeholder_card()` from PackOpening
- [ ] Update `PackType` enum references (currently duplicated)
- [ ] Update `PACK_CONFIG` references (currently duplicated)
- [ ] Add unit tests for `PackGenerator`
- [ ] Test UI integration (ensure animations work identically)
- [ ] Verify skip vs normal animation produce same results

## Testing PackGenerator

Run the example script:

```bash
godot --path . --script scripts/systems/pack_generator_example.gd
```

Expected output:
- Random pack generation
- Deterministic pack generation
- Identical results verification
- Batch generation
- Odds analysis

## Key Design Decisions

### Why `RefCounted` instead of `Node`?
- No need for scene tree
- Pure utility class
- Lower memory overhead
- Signals not needed (pure functions)

### Why static methods?
- No instance state needed
- Can be called from anywhere
- Thread-safe (each call gets own RNG)
- Easier to test

### Why separate RNG per call?
- Thread safety
- Determinism (seed controls everything)
- No shared global state
- Parallel generation possible

### Why sort by rarity?
- Maintains current UI behavior
- Dramatic reveals (legendary last)
- Consistent display order
- Easy to reverse if needed

## Architecture Diagram

```
┌─────────────────┐
│   PackShop      │
│   (UI Layer)    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐      ┌──────────────────┐
│  PackOpening    │◄─────┤ PackGenerator    │
│  (UI Layer)     │      │ (Logic Layer)    │
└────────┬────────┘      └────────┬─────────┘
         │                        │
         ▼                        ▼
┌─────────────────────────────────────┐
│           CardData                  │
│        (Data Layer)                 │
└─────────────────────────────────────┘
```

**Current:** PackOpening contains both UI and logic (coupled)
**Future:** PackOpening calls PackGenerator (separated)

## Notes

- PackGenerator has **zero dependencies** on Godot UI nodes
- Can be unit tested without running the game
- Can be used from server/headless environments
- RNG seed can be saved for audit trails
- All pack configuration centralized in `PACK_CONFIG`
