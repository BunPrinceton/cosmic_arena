# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Cosmic Arena** is a 1v1 real-time strategy game built with Godot 4.x and GDScript. It features deck-building, commander control, unit deployment, and a Force Arena-style UI.

**CRITICAL VERSION REQUIREMENT**: This project uses **Godot 4.3** exactly (specified in `.godot-version`). Opening in Godot 4.4+ or 5.x will auto-upgrade scene files and break compatibility.

**PROJECT STATUS**: The 2D game (`main.tscn`) is deprecated. All active development focuses on the 3D prototype (`main_3d.tscn`) with Force Arena-style gameplay.

## Running the Game

```bash
# Run the game (starts at main menu)
godot --path .

# Run the 3D battle scene directly
godot --path . scenes/main_3d.tscn

# In Godot editor:
# - F5: Run main scene (main_menu.tscn)
# - F6: Run currently open scene
```

**Entry Point**: Game starts at `scenes/main_menu.tscn` (configured in project.godot). From there:
- Click "1 vs 1" or "TRAINING" → launches `scenes/main_3d.tscn`
- Press ESC during 3D battle → returns to main menu

## Scene Flow (Current)

```
main_menu.tscn (Force Arena-style menu)
    ├── Left sidebar: Navigation (Battle, Rewards, Deck, Shop, Trade, Guild)
    ├── Center: 3D character viewport with commander preview
    ├── Right: Game mode buttons (1v1, 2vs2, Team Up, Training)
    └── Click 1v1/Training → main_3d.tscn
                                ↓
                        3D Battle Scene
                                ↓
                        ESC → main_menu.tscn
```

## Core Architecture

### Data-Driven Resource System

The game uses a **resource-based architecture** similar to Unity's ScriptableObjects:

- **Unit Stats**: Defined in `.tres` files (`resources/units/*.tres`), not hardcoded
- **Commander Data**: Defined in `.tres` files (`resources/commanders/*.tres`)
- **Player Data**: `scripts/resources/player_data.gd` tracks progression, rank, currencies

**Key Pattern**:
```gdscript
@export var unit_data: UnitData

func _ready():
    if unit_data:
        max_health = unit_data.max_health
        move_speed = unit_data.move_speed
```

### Pure Systems Architecture (`scripts/systems/`)

The `systems/` directory contains **pure, headless modules** - zero UI dependencies:

- **Extends RefCounted** (not Node/Control) - no scene tree needed
- **Static methods preferred** - can be called from anywhere
- **No signals** - pure functions return data
- **Deterministic** - same input always produces same output (with seeding)
- **Testable** - can run without game engine via example scripts

**Why separate?**
- UI can change without touching game logic
- Logic can be unit tested independently
- Systems can run headless (server-side, CLI tools)
- Clear separation: UI presents, Systems compute, Resources define

**Pattern**: UI layer calls System layer, System returns pure data, UI displays it.

### Critical Naming Conflicts

**IMPORTANT**: Two different "GameState" concepts exist:

1. **GameState (autoload singleton)**: `scripts/game_state.gd` - Stores decks, commanders, available units
2. **MatchState (enum)**: Inside `GameManager` class - Tracks match state (PLAYING, PLAYER_WON, ENEMY_WON)

**Never** rename the GameManager enum back to "GameState" - it causes type resolution conflicts.

### Main Menu System

The Force Arena-style main menu (`scenes/main_menu.tscn`, `scripts/main_menu.gd`):

- **Left sidebar**: Navigation buttons with inverted selection style (white bg/black text when selected)
- **Top bar**: Player info (name, title, level, XP), rank display (emblem, tier, points), currencies
- **Center**: 3D character viewport via SubViewport showing selected commander with idle animation
- **Commander selector**: 4 circles with faction emblems (light/dark), golden ring highlight
- **Right panel**: Game mode buttons

**Key UI Pattern** - Inverted button selection:
```gdscript
func _apply_nav_button_style(button: Button, selected: bool, enabled: bool) -> void:
    if selected:
        stylebox.bg_color = Color(1.0, 1.0, 1.0, 1.0)  # White bg
        button.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 1.0))  # Black text
    else:
        stylebox.bg_color = Color(0.12, 0.12, 0.15, 0.8)  # Dark bg
        button.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))  # White text
```

### 3D Character Viewport

`scenes/ui/character_viewport.tscn` displays 3D characters in 2D UI:

- SubViewport with transparent background
- **Pivot-based camera system** to avoid mesh clipping during zoom
- Idle animation loops via `Animation.LOOP_LINEAR`
- Script: `scripts/ui/character_viewport.gd`

**Key Pattern - Pivot-Based Camera Zoom**:
```gdscript
# DON'T move camera Z to zoom (causes mesh clipping)
# DO move a pivot node up/down to frame different parts of character

var camera_pivot: Node3D  # Parent of Camera3D
const PIVOT_BATTLE_POS = Vector3(0, 0.5, 0)  # Full body view
const PIVOT_DECK_POS = Vector3(0, 1.0, 0)    # Upper body view

# Camera stays at fixed offset, pivot moves
func zoom_in_for_deck() -> void:
    tween.tween_property(camera_pivot, "position", PIVOT_DECK_POS, ZOOM_DURATION)

# Camera must look_at pivot target when pivot moves
func _update_camera_look() -> void:
    camera.look_at(camera_pivot.global_position, Vector3.UP)
```

### Deck View Transitions

The main menu transitions between BATTLE and DECK views:
- **BATTLE view**: Game mode buttons on right, character centered
- **DECK view**: Cards at bottom, character moved right, zoomed in

**Key Pattern - Reparenting for Animation**:
```gdscript
# Elements in VBoxContainer can't be freely positioned
# Reparent to deck_panel before animating
if commander_name_label.get_parent() == center_area:
    var global_pos = commander_name_label.global_position
    commander_name_label.reparent(deck_panel)
    commander_name_label.global_position = global_pos
```

### Camera Systems

**3D Camera (main_3d.tscn)**: Force Arena-style diagonal isometric:
- Script: `scripts/camera_3d_follow.gd`
- Positioned southeast of player (+X, +Z offset) looking northwest
- Locked follow in `_physics_process`

**Character Viewport Camera**: Pivot-based system:
- Camera at fixed local position: `Vector3(0, 0.5, 3.0)`
- FOV: 45°
- Pivot moves to frame different parts of character
- Camera must `look_at()` pivot target when pivot moves

### Signal-Based Communication

```
Core.health_changed → HUD.update_health()
Core.core_destroyed → GameManager._on_core_destroyed() → game_over.emit()
EnergySystem.energy_changed → HUD._on_energy_changed()
CapturePoint.ownership_changed → Main._on_capture_point_ownership_changed()
```

### Collision Layers (Physics)

- **Layer 1**: Player (player units, player commander, player core)
- **Layer 2**: Enemy (enemy units, enemy commander, enemy core)
- **Layer 3**: Neutral (capture point, obstacles)

## Commander System

Commanders use a three-resource system:
- **CommanderTrait**: Passive bonuses (energy regen, unit buffs)
- **CommanderAbility**: Active skill (AOE damage, heal, speed boost)
- **CommanderData**: Combines stats + trait + ability

Available commanders in `GameState.AVAILABLE_COMMANDERS`:
- Light side: Assault Commander, Tactical Commander
- Dark side: Dark Enforcer, Shadow Lord

## Player Data System

`scripts/resources/player_data.gd` tracks:
- **Identity**: player_name, player_title
- **Progression**: level, current_xp, xp_to_next_level
- **Rank**: rank_tier ("BRONZIUM"), rank_tier_level (1-5), rank_points
- **Currencies**: credits, gems, gold

## Pack Opening System

The game features a complete card pack system with three pure, headless layers:

### Architecture Overview

```
PackShop (UI) → PackOpening (UI + Animation) → PackGenerator (Pure Logic)
                                              ↓
                                    PlayerCollection (Pure Data)
                                              ↓
                                        CardData (Resources)
```

### PackGenerator (`scripts/systems/pack_generator.gd`)

**Pure, deterministic pack generation system** - completely UI-independent.

- **Function**: `PackGenerator.generate_pack(pack_type, card_pool, seed) -> Array[CardData]`
- **Pack Types**: BASIC (4 cards), PREMIUM (5 cards, rare+ guaranteed), LEGENDARY (6 cards, epic+ guaranteed)
- **Seeding**: Pass `seed != -1` for deterministic generation (testing, server-side validation)
- **No Dependencies**: No UI, no signals, no side effects

**Key Design**: Extracts all game logic from UI layer. Can be unit tested without running the game.

### PlayerCollection (`scripts/systems/player_collection.gd`)

**Pure ownership tracking system** - stores only card IDs and counts.

- **Data Structure**: `Dictionary { card_id: count }` - never stores CardData objects
- **Function**: `collection.add_cards(cards) -> { "added": [...], "duplicates": [...] }`
- **Save/Load**: `to_dict()` and `from_dict()` for serialization
- **Why IDs only?**: 98% smaller save files, no memory leaks, CardData loaded on-demand

**Key Design**: Separates ownership data from resource definitions. Save-friendly, testable.

### PackOpening (`scripts/pack_opening.gd`)

**UI layer with animations** - handles presentation only.

- **Animations**: Shake, glow burst, card flip, sparkles, screen shake (rarity-based)
- **Skip Support**: Skip and normal paths produce identical results (cards generated once)
- **Integration**: Calls `PackGenerator.generate_pack()` then `PlayerCollection.add_cards()`

**Key Pattern**: After `_finish_reveal()`, cards are added to collection and logged to console.

### Testing Pack System

```bash
# Standalone pack opening test
godot --path . scenes/pack_opening_test.tscn

# PackGenerator examples (determinism)
godot --path . --script scripts/systems/pack_generator_example.gd

# PlayerCollection examples (ownership tracking)
godot --path . --script scripts/systems/player_collection_example.gd
```

### CardData Resource (`scripts/resources/card_data.gd`)

Defines individual cards with rarity system:

- **Rarities**: COMMON (60% weight), RARE (25%), EPIC (12%), LEGENDARY (3%)
- **Types**: UNIT, COMMANDER, ABILITY, EQUIPMENT
- **Factory Methods**: `CardData.from_unit_data()`, `CardData.from_commander_data()`
- **Display Helpers**: `get_rarity_color()`, `get_glow_color()`, `get_rarity_name()`

### Integration with Main Menu

From main menu → "Shop" navigation → PackShop opens → Purchase pack → PackOpening animates → Collection updated

**Important**: PackShop must call `set_player_collection()` to enable ownership tracking.

## 3D Battle Scene (main_3d.tscn)

The active game scene with Force Arena-style gameplay:

- **Ground**: 60×100 battlefield
- **3 Lanes**: At X=-12, 0, 12
- **Bases**: Player (Z=50), Enemy (Z=-50)
- **Player**: 3D character with WASD movement, sprint animation
- **Camera**: Diagonal isometric following player

### Player 3D Controls

Script: `scripts/player_3d.gd`
- WASD/Arrow keys for movement
- Right-click to move
- ESC to return to main menu
- Animations: "sprint" when moving, "idle-unarmed" when stationary

## Common Godot 4.x Pitfalls

### Method Name Conflicts
**Never** create methods that conflict with Node API:
- ❌ `get_owner()` - conflicts with `Node.get_owner()`
- ✅ `get_current_owner()` - safe custom name

### Animation Looping
Set loop mode before playing:
```gdscript
var anim = anim_player.get_animation(anim_name)
if anim:
    anim.loop_mode = Animation.LOOP_LINEAR
anim_player.play(anim_name)
```

### Global vs Local Position
Always use global space for cameras:
```gdscript
camera.global_position = target.global_position + offset  # ✅ Correct
camera.position = target.position + offset  # ❌ Wrong
```

## Modifying Game Balance

All stats in `.tres` resource files - edit in Godot Inspector, no code changes needed:
- Unit stats: `resources/units/*.tres`
- Commander data: `resources/commanders/*.tres`
- Player defaults: `scripts/resources/player_data.gd`

## Adding New Features

### Adding a New Commander

1. Create trait: `resources/commanders/new_trait.tres`
2. Create ability: `resources/commanders/new_ability.tres`
3. Create commander data: `resources/commanders/new_commander.tres`
4. Add to `GameState.AVAILABLE_COMMANDERS` array

### Adding UI Elements to Main Menu

1. Add nodes to `scenes/main_menu.tscn`
2. Get references in `scripts/main_menu.gd:_setup_*()` functions
3. Update in `_update_player_stats()` if data-driven

## File Organization

```
cosmic_arena/
├── project.godot         # Main scene: scenes/main_menu.tscn
├── scenes/
│   ├── main_menu.tscn   # Force Arena-style menu (entry point)
│   ├── main_3d.tscn     # 3D battle scene (active development)
│   ├── main.tscn        # 2D battle (deprecated)
│   ├── pack_shop.tscn   # Pack shop UI
│   ├── pack_opening.tscn # Pack opening UI with animations
│   ├── pack_opening_test.tscn # Standalone pack testing scene
│   ├── ui/
│   │   └── character_viewport.tscn  # 3D character preview
│   └── ...
├── scripts/
│   ├── main_menu.gd     # Menu controller
│   ├── player_3d.gd     # 3D player controller
│   ├── camera_3d_follow.gd
│   ├── game_state.gd    # Autoload singleton
│   ├── pack_shop.gd     # Pack shop controller
│   ├── pack_opening.gd  # Pack opening UI + animations
│   ├── resources/
│   │   ├── player_data.gd  # Player progression
│   │   └── card_data.gd    # Card definitions
│   ├── systems/         # Pure logic systems (no UI dependencies)
│   │   ├── pack_generator.gd # Pure pack generation
│   │   └── player_collection.gd # Pure ownership tracking
│   ├── ui/
│   │   └── character_viewport.gd
│   ├── units/           # Unit classes
│   └── commanders/      # Commander classes
├── resources/
│   ├── units/           # Unit stat .tres files
│   └── commanders/      # Commander .tres files
└── docs/                # Technical documentation
    ├── pack_generator_integration.md
    ├── player_collection_system.md
    └── pack_collection_integration.md
```

## Code Style

- `PascalCase` for classes and resources
- `snake_case` for variables, functions, signals
- `UPPER_SNAKE_CASE` for constants
- Type hints: `var target: Node3D = null`
- Export variables: `@export var max_health: float = 100.0`
