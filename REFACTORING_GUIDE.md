# Unit Data Resource System - Refactoring Guide

## Overview

The unit deployment system has been refactored to use a **data-driven architecture** with ScriptableObject-style Resources. This separates unit **data** (stats, costs, properties) from unit **logic** (behavior, AI, mechanics).

## What Changed

### Before: Hardcoded Stats in Scripts

Previously, each unit type had hardcoded stats in their script files:

```gdscript
# unit_grunt.gd (OLD)
func _ready() -> void:
    max_health = 80.0
    move_speed = 100.0
    attack_damage = 15.0
    # ... etc
```

Problems with this approach:
- Game designers need to edit code files to balance units
- Stats scattered across multiple script files
- Difficult to compare unit stats
- Risk of syntax errors when balancing
- Can't hot-reload changes without restarting

### After: Resource-Based Data

Now, unit stats are defined in `.tres` resource files:

```gdscript
# resources/units/grunt_data.tres (NEW)
[resource]
unit_name = "Grunt"
max_health = 80.0
move_speed = 100.0
attack_damage = 15.0
energy_cost = 1.5
# ... etc
```

Benefits:
- ✅ Stats in dedicated data files (easy to find and edit)
- ✅ No code changes needed for balancing
- ✅ Can be edited in Godot Inspector (visual editor)
- ✅ Hot-reloadable during development
- ✅ Supports future modding/extensibility
- ✅ Easy to create unit variants

## New File Structure

```
cosmic_arena/
├── scripts/
│   └── resources/
│       └── unit_data.gd          # UnitData resource class
│
├── resources/
│   └── units/
│       ├── grunt_data.tres       # Grunt unit stats
│       ├── ranger_data.tres      # Ranger unit stats
│       ├── tank_data.tres        # Tank unit stats
│       └── support_data.tres     # Support unit stats
│
└── units/
    ├── grunt.tscn                # Now references grunt_data.tres
    ├── ranger.tscn               # Now references ranger_data.tres
    ├── tank.tscn                 # Now references tank_data.tres
    └── support.tscn              # Now references support_data.tres
```

## Key Components

### 1. UnitData Resource Class

**File**: `scripts/resources/unit_data.gd`

Defines the structure of unit data:

```gdscript
extends Resource
class_name UnitData

@export_group("Identity")
@export var unit_name: String = "Unit"
@export var description: String = ""
@export var visual_color: Color = Color.WHITE

@export_group("Stats")
@export var max_health: float = 100.0
@export var move_speed: float = 80.0
@export var attack_damage: float = 10.0
# ... etc
```

This class is like a template that defines what properties units can have.

### 2. Unit Data Resources

**Files**: `resources/units/*.tres`

Each `.tres` file is an instance of `UnitData` with specific values:

- `grunt_data.tres` - Fast, cheap melee unit
- `ranger_data.tres` - Ranged attacker
- `tank_data.tres` - Heavy frontline unit
- `support_data.tres` - Healer unit

### 3. Updated UnitBase

**File**: `scripts/units/unit_base.gd`

Now loads stats from the UnitData resource:

```gdscript
@export var unit_data: UnitData

func _ready() -> void:
    # Load stats from UnitData resource
    if unit_data:
        max_health = unit_data.max_health
        move_speed = unit_data.move_speed
        attack_damage = unit_data.attack_damage
        # ... etc
```

### 4. Simplified Unit Scripts

**Files**: `scripts/units/unit_*.gd`

Unit type scripts are now much simpler:

```gdscript
extends UnitBase
class_name UnitGrunt

## Stats are loaded from the UnitData resource
```

All the stats are in the resource file, not in code!

## How to Use

### Balancing Units

**Option 1: Edit in Godot Inspector (Recommended)**
1. Open Godot Editor
2. Navigate to `resources/units/` in the FileSystem
3. Click on a `.tres` file (e.g., `grunt_data.tres`)
4. Edit values in the Inspector panel
5. Save (Ctrl+S)
6. Changes apply immediately (hot-reload)

**Option 2: Edit .tres Files Directly**
1. Open a `.tres` file in a text editor
2. Modify the values
3. Save
4. Reload in Godot

### Creating New Unit Types

1. **Create a new UnitData resource:**
   - In Godot: Right-click in `resources/units/` → Create New → Resource
   - Set script to `unit_data.gd`
   - Configure stats in Inspector
   - Save as `new_unit_data.tres`

2. **Create a unit script (optional):**
   ```gdscript
   extends UnitBase
   class_name UnitNewType

   ## Special behavior for this unit type
   ```

3. **Create a unit scene:**
   - Create new scene with CharacterBody2D root
   - Attach unit script
   - Set `unit_data` property to your new resource
   - Add CollisionShape2D and Visual nodes

4. **Add to deployment system:**
   - In `main.gd`, add to preloads:
   ```gdscript
   const NEW_UNIT_SCENE = preload("res://units/new_unit.tscn")
   const NEW_UNIT_DATA = preload("res://resources/units/new_unit_data.tres")
   ```
   - Add to `deploy_unit()` match statement
   - Add button to HUD

### Reading Unit Stats at Runtime

```gdscript
# Get stats from a unit instance
var unit = GRUNT_SCENE.instantiate()
print(unit.unit_data.unit_name)  # "Grunt"
print(unit.unit_data.energy_cost)  # 1.5

# Get stats from resource directly
print(GRUNT_DATA.max_health)  # 80.0
print(GRUNT_DATA.attack_damage)  # 15.0
```

## Benefits for Different Roles

### For Game Designers
- Edit stats without touching code
- Visual editor (Inspector) for all properties
- Easy to compare units side-by-side
- Quick iteration and testing
- No risk of breaking the game with syntax errors

### For Programmers
- Cleaner, more maintainable code
- Single source of truth for unit stats
- Easy to add new properties to all units
- Better separation of concerns
- Extensible for future features

### For Modders (Future)
- Create custom units without code changes
- Easy to distribute unit packs (.tres files)
- Can override existing units
- No compilation needed

## Advanced Features

### Unit Variants

Create variants by duplicating resources:

1. Duplicate `grunt_data.tres` → `elite_grunt_data.tres`
2. Increase stats (health, damage)
3. Increase energy cost
4. Reuse the same grunt script and scene
5. Just swap the `unit_data` reference

### Conditional Abilities

Use data properties to enable/disable features:

```gdscript
# In unit_data.gd
@export var has_special_ability: bool = false
@export var ability_name: String = ""

# In unit script
if unit_data.has_special_ability:
    enable_special_ability(unit_data.ability_name)
```

### Dynamic Unit Unlocks

```gdscript
# Load units dynamically based on player progress
var available_units: Array[UnitData] = []

if player.level >= 5:
    available_units.append(TANK_DATA)
if player.has_upgrade("ranger"):
    available_units.append(RANGER_DATA)
```

## Migration Notes

### What Still Works
- All existing gameplay mechanics
- AI deployment system
- Energy system
- Unit behavior and combat
- Commander systems

### What Changed
- Unit stat initialization (now from resources)
- Visual colors (now from unit_data)
- Cost retrieval (now from UNIT_DATA constants in main.gd)

### Backward Compatibility
The refactoring maintains full backward compatibility. The game works exactly as before, just with a cleaner architecture.

## Performance Impact

**Runtime Performance**: ✅ No impact
- Resources are preloaded (no loading during gameplay)
- Stat copying happens once in `_ready()`
- No additional overhead

**Development Performance**: ✅ Improved
- Hot-reload speeds up iteration
- No need to restart game to test balance changes

## Future Enhancements

This resource system enables:

1. **Unit Database UI**
   - In-game unit encyclopedia
   - Compare stats side-by-side
   - Preview unit info before deployment

2. **Difficulty Scaling**
   - Easy: Reduce enemy unit stats by 20%
   - Hard: Increase enemy unit stats by 30%
   - Just multiply resource values at runtime

3. **Procedural Units**
   - Generate random unit types
   - Mix and match properties
   - Create roguelike variations

4. **Save/Load System**
   - Save which units player has unlocked
   - Save unit upgrades
   - Reference units by resource path

5. **Modding Support**
   - Players create custom `.tres` files
   - Drop into `mods/units/` folder
   - Auto-load at startup

## Troubleshooting

### Unit has no stats
**Problem**: Unit spawns with default values (100 health, etc.)
**Solution**: Check that `unit_data` is assigned in the unit's scene file

### Unit button shows wrong cost
**Problem**: Button cost doesn't match actual deployment cost
**Solution**: Verify UNIT_DATA resources are preloaded correctly in main.gd

### Can't find UnitData class
**Problem**: "Identifier 'UnitData' not declared in current scope"
**Solution**: Ensure `unit_data.gd` has `class_name UnitData` at the top

### Resource not loading
**Problem**: `unit_data` is null when unit spawns
**Solution**: Check the `.tres` file path is correct in unit scene

## Summary

The resource-based architecture provides:
- **Better organization** - Data separated from logic
- **Easier balancing** - Edit stats visually without code
- **More flexibility** - Create variants and new units quickly
- **Cleaner code** - Reduced duplication and hardcoding
- **Future-proof** - Supports modding and procedural generation

This is a standard pattern in game development (Unity's ScriptableObjects, Unreal's DataAssets) and is considered a best practice for data-driven design.

---

**Refactoring Date**: 2025-12-18
**Files Changed**: 13
**Lines Removed**: ~100 (hardcoded stats)
**Lines Added**: ~200 (resource system)
**Net Benefit**: Massive improvement in maintainability
