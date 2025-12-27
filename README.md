# Cosmic Arena

A 1v1 real-time arena strategy game inspired by the mechanics of mobile RTS games, built with Godot 4.x and GDScript.

## Overview

Cosmic Arena is an original sci-fi real-time strategy game where you control a Commander and deploy units across three lanes to destroy the enemy Core. **Build your deck** before each match, manage your energy wisely, position your Commander strategically, and use your special ability at the right moment to achieve victory!

## Features

- **Deck Building System**: Select 3-6 units before each battle for strategic customization
- **Commander Control**: Player-controlled hero with WASD movement, click-to-move support, and a powerful area-of-effect ability
- **Unit Deployment**: Choose from 4 different unit types to build your deck:
  - **Grunt** (1.5 energy): Fast, cheap melee unit
  - **Ranger** (2.5 energy): Ranged attacker with long range
  - **Tank** (4.0 energy): Heavy, high-health frontline unit
  - **Support** (3.0 energy): Heals nearby friendly units
- **Dynamic UI**: Unit buttons generated based on your selected deck
- **Energy System**: Energy regenerates over time; manage it to deploy units effectively
- **Smart AI**: AI opponent builds random decks and adapts its deployment strategy
- **Win Condition**: Destroy the enemy Core to win!

## How to Run

### Prerequisites
- **Godot 4.3** (REQUIRED - do not use newer versions without team coordination)
- Download from: https://godotengine.org/download

### ⚠️ Version Compatibility Warning
**IMPORTANT FOR COLLABORATORS**: This project is locked to **Godot 4.3**. Opening it in a newer version (4.4, 5.x, etc.) and saving changes will break compatibility for team members using 4.3. Always use the version specified in `.godot-version` file.

### Opening the Project

1. Open Godot Engine
2. Click "Import" in the project manager
3. Navigate to the `cosmic_arena` folder
4. Select the `project.godot` file
5. Click "Import & Edit"
6. Once the project opens, press **F5** or click the "Play" button to run the game

### Alternative: Command Line

```bash
cd cosmic_arena
godot project.godot
```

To run directly without opening the editor:
```bash
godot --path cosmic_arena
```

## Controls

### Deck Building (Pre-Match)
- **Click Unit Cards**: Add units to your deck (max 6)
- **Click Deck Units**: Remove units from your deck
- **Start Battle Button**: Begin match (requires 3-6 units selected)

### In-Match Controls

#### Commander
- **W/A/S/D**: Move Commander up/left/down/right
- **Right Click**: Click-to-move (Commander moves to mouse position)
- **Space**: Use Commander ability (Shield Pulse - AOE damage)

#### Unit Deployment
- **1**: Select left lane
- **2**: Select center lane (default)
- **3**: Select right lane
- **Click Unit Buttons**: Deploy selected unit type in the currently selected lane
  - Only units in your deck appear as buttons
  - Units will auto-deploy in the center lane by default
  - Change lanes with number keys before clicking a unit button

### General
- **F5**: Run game (when in editor)
- **Escape**: Quit game (when running)

## Gameplay Tips

1. **Deck Building Strategy**:
   - **Balanced Deck**: 1-2 of each unit type for flexibility
   - **Aggressive Deck**: Multiple Grunts + 1-2 Tanks for early pressure
   - **Defensive Deck**: Tanks + Supports + Rangers for sustain
   - **Economy Deck**: Focus on cheap units (Grunts) for constant deployment
2. **Energy Management**: Energy regenerates at 1.5/second. Don't spend it all at once!
3. **Lane Strategy**: Spread units across lanes or focus on one lane for a concentrated push
4. **Commander Positioning**: Your Commander is powerful but vulnerable - keep them safe!
5. **Unit Composition**:
   - Use Grunts for cheap, fast pressure
   - Rangers provide ranged damage
   - Tanks absorb damage and protect squishier units
   - Supports keep your army healthy
6. **Ability Timing**: The Commander's Shield Pulse ability has a 10-second cooldown - use it when enemies cluster!
7. **Core Defense**: If the enemy is pushing hard, fall back to defend your Core
8. **Deck Flexibility**: Remember you can only deploy units in your deck - choose wisely!

## Project Structure

```
cosmic_arena/
├── project.godot          # Godot project configuration (includes GameState autoload)
├── icon.svg              # Project icon
├── main.tscn             # Main game scene
├── README.md             # This file
├── REFACTORING_GUIDE.md  # Guide to resource-based unit system
├── DECK_BUILDING_GUIDE.md # Guide to deck-building system
│
├── scripts/
│   ├── game_manager.gd   # Manages game state and win/loss
│   ├── game_state.gd     # Global state singleton (autoload) - stores decks
│   ├── energy_system.gd  # Energy regeneration and spending
│   ├── ai_controller.gd  # AI unit deployment logic
│   ├── arena.gd          # Arena layout and lane positions
│   ├── core.gd           # Base/Core that must be destroyed
│   ├── deck_builder.gd   # Deck builder UI controller
│   ├── main.gd           # Main scene controller (uses deck system)
│   │
│   ├── commanders/
│   │   ├── commander.gd          # Base commander class
│   │   ├── player_commander.gd   # Player-controlled commander
│   │   └── ai_commander.gd       # AI-controlled commander
│   │
│   ├── units/
│   │   ├── unit_base.gd    # Base unit class (loads from UnitData)
│   │   ├── unit_grunt.gd   # Grunt unit
│   │   ├── unit_ranger.gd  # Ranger unit
│   │   ├── unit_tank.gd    # Tank unit
│   │   └── unit_support.gd # Support unit
│   │
│   └── resources/
│       ├── unit_data.gd    # UnitData resource class (ScriptableObject-style)
│       └── deck.gd         # Deck resource class
│
├── resources/
│   └── units/
│       ├── grunt_data.tres    # Grunt stats (editable resource)
│       ├── ranger_data.tres   # Ranger stats
│       ├── tank_data.tres     # Tank stats
│       └── support_data.tres  # Support stats
│
├── scenes/
│   ├── arena.tscn        # Arena scene with lane markers
│   ├── core.tscn         # Core/Base scene
│   └── deck_builder.tscn # Deck builder UI (starting scene)
│
├── units/
│   ├── grunt.tscn        # Grunt unit scene (references grunt_data.tres)
│   ├── ranger.tscn       # Ranger unit scene
│   ├── tank.tscn         # Tank unit scene
│   └── support.tscn      # Support unit scene
│
└── ui/
    ├── hud.gd            # HUD script
    └── hud.tscn          # HUD scene (energy bar, health, buttons)
```

## Game Systems Explained

### Energy System
- Max Energy: 10
- Regen Rate: 1.5 energy/second
- Starting Energy: 5
- Unit costs range from 1.5 (Grunt) to 4.0 (Tank)

### Commander System
- Player Commander:
  - Health: 500
  - Movement Speed: 200
  - Attack Damage: 30
  - Ability: Shield Pulse (150 range AOE, 50 damage, 10s cooldown)
- AI Commander:
  - Similar stats but different ability (Energy Blast)
  - AI behaviors: Patrol, Attack, Retreat (when health < 30%)

### Unit Stats

| Unit    | Health | Speed | Damage | Range | Cost |
|---------|--------|-------|--------|-------|------|
| Grunt   | 80     | 100   | 15     | 40    | 1.5  |
| Ranger  | 100    | 70    | 25     | 120   | 2.5  |
| Tank    | 250    | 50    | 35     | 50    | 4.0  |
| Support | 120    | 80    | 5      | 50    | 3.0  |

Support units heal allies for 20 HP every 2 seconds within 100 range.

### AI Behavior
- Deploys units every 3-4 seconds if energy permits
- Randomly selects lanes
- Commander patrols, attacks nearby enemies, and retreats when damaged
- Uses abilities when enemies are in range

### Resource-Based Unit System

The game uses a **data-driven architecture** with UnitData resources:
- Unit stats are defined in `.tres` resource files (not hardcoded in scripts)
- Easy to balance: edit `resources/units/*.tres` files in Godot Inspector
- Hot-reloadable during development
- Supports creating unit variants without code changes

**For Balancing Units**:
1. Open Godot Editor
2. Navigate to `resources/units/` folder
3. Click on a unit data file (e.g., `grunt_data.tres`)
4. Edit stats in the Inspector panel
5. Changes apply immediately!

See `REFACTORING_GUIDE.md` for detailed information about the resource system.

## Known Limitations

1. **No Networking**: This is a local 1v1 game against AI only
2. **Placeholder Graphics**: Uses simple colored rectangles and shapes
3. **Basic AI**: AI uses simple heuristics rather than advanced strategy
4. **No Audio**: No sound effects or music
5. **No Persistence**: No save system or progression between games
6. **Limited Polish**: Minimal animations and effects
7. **Commander Health Display**: Commander health bars are basic visual indicators

## Future Enhancement Ideas

If you want to extend this project:
- Add more unit types (flying units, AoE attackers, etc.)
- Implement unit upgrades or multiple commander choices
- Add special abilities for each unit type
- Create multiple maps/arenas with different layouts
- Add particle effects and better visual feedback
- Implement a campaign mode or multiple difficulty levels
- Add sound effects and background music
- Create a unit card system with random draws (deck-building)
- Add online multiplayer support

## Technical Notes

### Godot Version
- Built and tested with Godot 4.3
- Should work with any Godot 4.x version

### Performance
- Designed for desktop (PC)
- Should run smoothly on most modern computers
- No heavy 3D rendering or complex physics

### Code Structure
- Object-oriented design with base classes for units and commanders
- Signal-based communication between systems
- Scene instancing for unit deployment
- Resource preloading for optimal performance

## Troubleshooting

### Game won't run
- Ensure you're using Godot 4.x (not Godot 3.x)
- Check that all scripts are properly attached in the scene tree
- Look for errors in the Output panel at the bottom of the editor

### Units not deploying
- Check that you have enough energy (shown in top-left)
- Ensure you're clicking the unit buttons (not just hovering)
- Verify that the game hasn't ended

### Commander not moving
- Make sure the game is running and not paused
- Check that you're using WASD or right-clicking in the game viewport
- Verify the commander is still alive (health > 0)

### Performance issues
- Close other applications
- Reduce window size if needed
- Check Task Manager for high CPU/memory usage from other apps

## Credits

**Design & Development**: Created as a clean-room MVP implementation
**Engine**: Godot Engine 4.x
**Art**: Procedural/placeholder graphics (colored primitives)
**Inspiration**: Mobile RTS arena games (mechanics only, no IP used)

## License

This project is provided as-is for educational and demonstration purposes. All code and assets are original and contain no proprietary or licensed content.

---

**Enjoy Cosmic Arena!** May your strategy lead you to victory! 🚀
