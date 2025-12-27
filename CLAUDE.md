# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Cosmic Arena** is a 1v1 real-time strategy game built with Godot 4.x and GDScript. It features deck-building, commander control, unit deployment, and a neutral capture point objective system.

**CRITICAL VERSION REQUIREMENT**: This project uses **Godot 4.3** exactly (specified in `.godot-version`). Opening in Godot 4.4+ or 5.x will auto-upgrade scene files and break compatibility. See `CONTRIBUTING.md` for details.

## Running the Game

```bash
# Open project in Godot editor
godot project.godot

# Run the 2D game (default main scene)
godot --path .

# Run the 3D prototype scene
godot --path . scenes/main_3d.tscn

# In Godot editor:
# - F5: Run main/default scene (2D game)
# - F6: Run currently open scene (useful for 3D prototype)
```

**Entry Point**: Game starts at `scenes/deck_builder.tscn` (configured in project.godot), then transitions to `main.tscn` for the 2D battle.

**3D Prototype**: A Force Arena-style 3D scene exists at `scenes/main_3d.tscn` for testing camera angles and battlefield layout. This is NOT integrated with the main game loop yet.

## Core Architecture

### Data-Driven Resource System

The game uses a **resource-based architecture** similar to Unity's ScriptableObjects:

- **Unit Stats**: Defined in `.tres` files (`resources/units/*.tres`), not hardcoded in scripts
- **Commander Data**: Defined in `.tres` files (`resources/commanders/*.tres`)
- **Unit Scripts**: Load stats from `unit_data` resource in `_ready()`
- **Commander Scripts**: Load stats from `commander_data` resource in `_ready()`

**Key Pattern**:
```gdscript
# scripts/units/unit_base.gd
@export var unit_data: UnitData

func _ready():
    if unit_data:
        max_health = unit_data.max_health
        move_speed = unit_data.move_speed
        # ... load all stats from resource
```

### Critical Naming Conflicts

**IMPORTANT**: There are two different "GameState" concepts in the codebase:

1. **GameState (autoload singleton)**: `scripts/game_state.gd` - Stores player/AI decks and commanders across scenes
2. **MatchState (enum)**: Inside `GameManager` class - Tracks current match state (PLAYING, PLAYER_WON, ENEMY_WON)

**Never** rename the GameManager enum back to "GameState" - it causes type resolution conflicts with the autoload.

### Scene Flow

```
Startup: deck_builder.tscn
    ↓ (player selects deck)
GameState.player_deck = selected_deck
    ↓ (click "Start Battle")
get_tree().change_scene_to_file("res://main.tscn")
    ↓
main.tscn loads
main.gd._ready() reads GameState.player_deck
Battle begins
```

### Camera System

**2D Camera (main.tscn)**: The Camera2D follows the PlayerCommander using:
- `camera.global_position = player_commander.global_position` (not local position)
- `anchor_mode = 1` (DRAG_CENTER) to center viewport on camera
- Camera shake applies offset to follow position
- **Never** use `camera_base_position` as a static fallback - it must update each frame

```gdscript
# main.gd _process()
func _process(delta: float) -> void:
    if player_commander:
        var follow_pos = player_commander.global_position

        # Apply shake offset if active
        if camera_shake_amount > 0:
            follow_pos += shake_offset

        camera.global_position = follow_pos
```

**3D Camera (main_3d.tscn)**: Force Arena-style diagonal isometric camera:
- Script: `scripts/camera_3d_follow.gd`
- Positioned southeast of player (+X, +Z offset) looking northwest
- Camera angle: 22° down from horizontal, -122° yaw (facing northwest)
- Locked follow: `global_position = target.global_position + _offset` in `_physics_process`
- Uses `look_at(target.global_position, Vector3.UP)` to keep player centered
- Gameplay settings: `follow_distance=12.5`, `camera_height=7.5`
- Debug settings (saved in comments): `follow_distance=25.0`, `camera_height=15.0`

```gdscript
# camera_3d_follow.gd
func _physics_process(delta: float) -> void:
    if not target:
        return

    # Locked follow - camera stays at fixed offset from player
    global_position = target.global_position + _offset

    # Always look at the player to keep them centered in screen
    look_at(target.global_position, Vector3.UP)
```

### Signal-Based Communication

Systems communicate via signals to maintain loose coupling:

```
Core.health_changed → HUD.update_health()
Core.health_changed → Main._on_core_damaged() → shake_camera()
Core.core_destroyed → GameManager._on_core_destroyed() → game_over.emit()
EnergySystem.energy_changed → HUD._on_energy_changed()
CapturePoint.ownership_changed → Main._on_capture_point_ownership_changed()
```

### Collision Layers (Physics)

- **Layer 1**: Player (player units, player commander, player core)
- **Layer 2**: Enemy (enemy units, enemy commander, enemy core)
- **Layer 3**: Neutral (capture point, obstacles)

Units set `collision_layer` and `collision_mask` based on their `team` value (0 = player, 1 = enemy).

## Unit System

### Unit Inheritance Hierarchy

```
CharacterBody2D (Godot builtin)
    ↓
UnitBase (scripts/units/unit_base.gd)
    ├── loads stats from UnitData resource
    ├── movement AI (move toward enemy, find targets)
    ├── combat system (attack nearest enemy)
    └── damage/death handling with visual effects
    ↓
Unit Type Scripts (unit_grunt.gd, unit_ranger.gd, etc.)
    └── override _ready() to set unit_data resource reference
```

### Unit Deployment Flow

1. Player clicks unit button in HUD
2. `HUD._on_unit_button_pressed(unit_data)` calls `main.deploy_unit(unit_data)`
3. `main.deploy_unit()`:
   - Checks `unit_data in unit_scene_map` (maps UnitData → PackedScene)
   - Checks energy with `player_energy_system.can_afford(cost)`
   - Instantiates unit scene: `unit_scene_map[unit_data].instantiate()`
   - Sets `unit.team = 0` (player team)
   - Positions at `arena.get_player_deployment_position(selected_lane)`
   - Adds to scene tree with `add_child(unit)`

**Critical**: The `unit_scene_map` Dictionary in `main.gd` maps UnitData resources to PackedScene resources. This allows data-driven unit deployment.

## Commander System

### Commander Data Resources

Commanders use a three-resource system:
- **CommanderTrait** (passive bonuses): Energy regen, unit damage/health/speed buffs, cost reduction
- **CommanderAbility** (active skill): AOE damage, heal allies, speed boost, summon units, energy burst, damage buff
- **CommanderData** (combines stats + trait + ability)

### Commander Inheritance

```
CharacterBody2D
    ↓
Commander (scripts/commanders/commander.gd)
    ├── loads stats from CommanderData resource
    ├── data-driven ability execution (execute_ability)
    ├── ability wind-up indicators (0.3s telegraph)
    ├── hit flash and damage numbers
    └── health management with signals
    ↓
PlayerCommander / AICommander
    └── movement AI and input handling
```

### Ability Wind-Up System

Commander abilities show a 0.3-second visual telegraph before executing:

```gdscript
func use_ability():
    show_ability_windup()  # Expanding colored ring
    await get_tree().create_timer(0.3).timeout
    execute_ability(active_ability)
    # Start cooldown
```

## Game Feel Systems

All visual feedback effects are in `docs/GAME_FEEL_IMPROVEMENTS.md`. Key implementations:

### Hit Flash (White Flash on Damage)
- Location: `unit_base.gd:146-158`, `commander.gd:101-112`
- Uses tween to flash `Visual` node color to (2.0, 2.0, 2.0) and back over 0.15s

### Floating Damage Numbers
- Scene: `scenes/floating_damage_number.tscn`
- Script: `scripts/floating_damage_number.gd`
- Spawned by: `unit_base.gd`, `commander.gd`, `core.gd`
- Pattern: `FLOATING_DAMAGE.instantiate()` → `get_tree().root.add_child()` → `initialize(damage, position)`

### Camera Shake
- Triggered on core damage: `shake_camera(8.0)`
- Applied in `_process()` as offset to camera follow position
- Smoothly dampens with `lerp(shake_amount, 0.0, delta * 10.0)`

## Capture Point System

**Location**: Center of arena at (0, 300)
**Documentation**: `docs/CAPTURE_POINT.md`

### Mechanics
- Units within 100 units contribute to capture progress (-100 to +100)
- Ownership thresholds: ≥75 (player), ≤-75 (enemy), -25 to 25 (neutral)
- Energy bonus: +50% regen for controlling team

### Integration Points
- `scripts/capture_point.gd`: Core logic with `ownership_changed` signal
- `scripts/main.gd:123-140`: Energy bonus application on ownership change
- `scripts/commanders/ai_commander.gd:64-78`: AI contesting behavior
- `ui/hud.gd:108-121`: HUD status display

### AI Behavior
AI commander checks capture point ownership during patrol (0.25% chance per frame) and moves toward it if not owned by AI.

## 3D Prototype Scene (main_3d.tscn)

A standalone 3D scene exists for testing Force Arena-style camera and battlefield layout. **This is NOT integrated with the main 2D game** - it's a separate prototype.

### Scene Structure

- **Ground**: 60×0.5×100 green box at Y=-0.25
- **3 Lanes**: 8×0.6×100 brown boxes at X=-12, 0, 12 (left, center, right)
- **Player Base**: 15×6×15 blue box at (0, 3, 50) - bottom of battlefield
- **Enemy Base**: 15×6×15 red box at (0, 3, -50) - top of battlefield
- **Obstacles**: 5× 4×3×4 gray boxes positioned along lanes
- **Boundary Walls**: 6 yellowish-green wall segments (height=3):
  - 2 full-length side walls at X=±31
  - 4 top/bottom segments flanking the bases at Z=±51
- **Backdrop Planes**: 3 bright yellow unshaded walls behind boundaries:
  - Top: 60×80×1 at (0, 40, -55)
  - Left: 1×80×100 at (-35, 40, 0)
  - Right: 1×80×100 at (35, 40, 0)

### Player & Camera

- **Player**: Blue capsule (radius=1, height=4) spawned at (-15, 2, 35)
- **Movement**: WASD/arrow keys + right-click to move
- **Camera**: Diagonal isometric view (see Camera System section)

### Visual Orientation

From camera view:
- Player base appears at **bottom-left** of screen
- Enemy base appears at **top-right** of screen
- Battlefield runs diagonally across viewport
- Camera is southeast of player, looking northwest

### Running the 3D Scene

**CRITICAL**: The 3D scene must be run differently than the 2D game:

```bash
# Command line
godot --path . scenes/main_3d.tscn

# In Godot editor
# 1. Open scenes/main_3d.tscn
# 2. Press F6 (Run Current Scene) - NOT F5!
# F5 runs the default main scene (2D game)
# F6 runs the currently open scene
```

### Common 3D Issues

**"I ran F5 but it's showing the 2D game"**:
- Use **F6** to run the current scene, not F5
- F5 always runs `project.godot`'s configured main scene (deck_builder.tscn → main.tscn)

**"Changes to main_3d.tscn aren't showing up"**:
- Ensure you're running `scenes/main_3d.tscn` specifically
- Check that Godot saved your changes (Ctrl+S)
- Command-line runs may not reflect unsaved editor changes

**"Can't see backdrop planes"**:
- Verify material has `shading_mode = 0` (unshaded) for brightness
- Check they're positioned outside the boundary walls
- Ensure mesh dimensions are correct (thin walls, not cubes)

## Common Godot 4.x Pitfalls

### Method Name Conflicts with Node API

**Never** create methods that conflict with built-in Node methods:
- ❌ `get_owner()` - conflicts with `Node.get_owner()` which returns Node
- ✅ `get_current_owner()` - safe custom method name

**Example**: `CapturePoint.get_current_owner()` was renamed from `get_owner()` to avoid parser errors.

### Camera2D Anchor Modes (2D scenes only)

- `anchor_mode = 0` (FIXED_TOP_LEFT): Camera position is top-left of viewport
- `anchor_mode = 1` (DRAG_CENTER): Camera position is center of viewport ← **Use this for follow cameras**

### Global vs Local Position

When moving cameras to follow objects, always use global space:

```gdscript
# 2D Camera
camera.global_position = target.global_position  # ✅ Correct
camera.position = target.position  # ❌ Wrong - local space

# 3D Camera
camera.global_position = target.global_position + offset  # ✅ Correct
camera.position = target.position + offset  # ❌ Wrong - local space
```

### Camera3D Look-At (3D scenes only)

When using Camera3D with `look_at()`, the third parameter is the "up" direction:

```gdscript
camera.look_at(target.global_position, Vector3.UP)  # ✅ Correct - Y-axis up
camera.look_at(target.global_position, Vector3.FORWARD)  # ❌ Wrong - camera tilted
```

## Modifying Game Balance

All unit and commander stats are in `.tres` resource files:

1. Open Godot Editor
2. Navigate to `resources/units/` or `resources/commanders/`
3. Click a `.tres` file
4. Edit values in Inspector panel
5. Save (Ctrl+S)
6. Changes apply immediately when running game

**No code changes needed** for stat adjustments.

## Adding New Features

### Adding a New Unit Type

1. Create resource script: `scripts/resources/custom_unit_data.gd` extending `UnitData`
2. Create unit script: `scripts/units/unit_custom.gd` extending `UnitBase`
3. Create unit scene: `units/custom.tscn` with script attached
4. Create resource file: `resources/units/custom_data.tres` with stats
5. Add to `main.gd:48-51`: `unit_scene_map[CUSTOM_DATA] = CUSTOM_SCENE`
6. Add to `GameState.AVAILABLE_UNITS` array in `game_state.gd`

### Adding a New Commander

1. Create trait resource: `resources/commanders/custom_trait.tres`
2. Create ability resource: `resources/commanders/custom_ability.tres`
3. Create commander data: `resources/commanders/custom_commander.tres`
4. Add to `GameState.AVAILABLE_COMMANDERS` in `game_state.gd`
5. Optionally create custom commander script extending `Commander` for unique behavior

### Adding Multiple Capture Points

1. Duplicate `CapturePoint` node in `main.tscn`
2. Position at desired location
3. In `main.gd._ready()`, connect its `ownership_changed` signal
4. Modify energy bonus logic to handle multiple bonuses (stacking or largest)

## Testing & Debugging

### Common Issues

**"Identifier not declared" errors**:
- Check for naming conflicts with built-in methods
- Verify autoload singletons are registered in project.godot
- Ensure class_name matches filename

**Camera offset/not following player**:
- Verify `camera.global_position = player_commander.global_position` in `_process()`
- Check `anchor_mode = 1` in Camera2D properties
- Ensure camera is enabled with `camera.make_current()`

**Units spawning at wrong position**:
- Check `team` value is set before `_ready()` runs
- Verify collision layers match team (0 = layer 1, 1 = layer 2)
- Ensure `global_position` is used, not `position`

**Type mismatch with GameState**:
- Verify GameManager uses `MatchState` enum, not `GameState`
- GameState is reserved for the autoload singleton

### Quick Validation

Run game (F5) and verify:
1. Deck builder shows available units
2. Start Battle button works
3. Player commander spawns at (0, 500) and is centered on screen
4. Camera follows player movement smoothly
5. Unit buttons deploy units in selected lane
6. Energy bar regenerates
7. Capture point changes color when contested
8. Damage numbers appear when units take damage
9. Camera shakes when core takes damage
10. Victory/defeat screen shows when game ends

## Code Style & Conventions

- Use `PascalCase` for class names and resources
- Use `snake_case` for variables, functions, and signals
- Export variables for inspector-editable properties: `@export var max_health: float = 100.0`
- Use type hints: `var current_target: Node2D = null`
- Document classes with `##` comments: `## Base class for all deployable units`
- Signal naming: `signal_name` (e.g., `health_changed`, `unit_died`)
- Constant naming: `UPPER_SNAKE_CASE` (e.g., `GRUNT_SCENE`, `AVAILABLE_UNITS`)

## File Organization

```
cosmic_arena/
├── project.godot         # Godot config, autoloads, input maps
├── main.tscn            # Battle scene (player vs AI)
├── scenes/              # Reusable scenes (arena, core, deck_builder, etc.)
├── scripts/
│   ├── *.gd            # Core systems (main, game_manager, energy_system, etc.)
│   ├── units/          # Unit classes (unit_base, unit_grunt, etc.)
│   ├── commanders/     # Commander classes (commander, player_commander, ai_commander)
│   └── resources/      # Resource class definitions (unit_data, deck, commander_data, etc.)
├── resources/
│   ├── units/          # .tres files with unit stats
│   └── commanders/     # .tres files with commander data/traits/abilities
├── units/              # Unit scene instances (.tscn)
├── ui/                 # HUD and UI elements
└── docs/               # Technical documentation
```

## Performance Considerations

- Floating damage numbers self-destruct after 0.8s (no memory leaks)
- Visual effects use tweens (not per-frame updates)
- Units use spatial queries (`get_nodes_in_group`) for targeting - optimize with areas if >50 units active
- Camera shake adds minimal overhead (2 randf calls per frame when active)

## External Documentation

- Godot 4.x API: https://docs.godotengine.org/en/stable/
- Game design docs in `docs/` folder
- README.md for user-facing controls and gameplay
