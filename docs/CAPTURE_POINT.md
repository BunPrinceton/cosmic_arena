# Capture Point System

## Overview
The capture point is a neutral objective located in the center lane that grants a **+50% energy regeneration bonus** to whichever team controls it.

## How It Works

### Capture Mechanics
- Units and commanders within **100 units** of the capture point contribute to capture progress
- Capture progress ranges from **-100** (enemy) to **+100** (player)
- Capture rate: **1 point per second per unit**
- Net capture = (player units - enemy units) × capture rate

### Ownership States
- **Neutral**: Capture progress between -25 and +25
- **Player Controlled**: Capture progress ≥ 75
- **Enemy Controlled**: Capture progress ≤ -75

### Energy Bonus
When a team controls the capture point:
- **Player**: Energy regen increases from 1.5/s to 2.25/s (+50%)
- **Enemy**: Energy regen increases from 1.2/s to 1.8/s (+50%)

## Files

### Core Implementation
- `scripts/capture_point.gd` - Main capture point logic
- `scenes/capture_point.tscn` - Visual representation (ColorRect, ProgressBar, Label)

### Integration
- `scripts/main.gd:111-128` - Energy bonus application on ownership change
- `scripts/commanders/ai_commander.gd:63-78` - AI contesting logic
- `ui/hud.gd:108-121` - HUD status display

## Configuration

All parameters are exported in `capture_point.gd`:

```gdscript
@export var capture_radius: float = 100.0      # Capture range
@export var capture_rate: float = 1.0          # Points/sec/unit
@export var energy_bonus: float = 0.5          # 50% bonus
```

## AI Behavior
The AI commander periodically checks the capture point (0.25% chance per frame during patrol):
- If not owned by AI → moves toward capture point
- If owned by AI → patrols around home position

## HUD Indicator
The HUD displays current ownership with color coding:
- **Gray**: "Objective: Neutral"
- **Green**: "Objective: Player Controlled (+50% Energy)"
- **Red**: "Objective: Enemy Controlled"

## Signals

```gdscript
signal ownership_changed(new_owner: int)  # -1 = neutral, 0 = player, 1 = enemy
```

Connected in `main.gd` to:
1. Apply energy regeneration bonuses
2. Update HUD display

## Adding More Capture Points
To add multiple capture points:

1. Duplicate `CapturePoint` node in main.tscn
2. Position at desired location
3. Connect the `ownership_changed` signal in `main.gd`
4. Modify bonus stacking logic as needed

## Future Enhancements
- Multiple capture points with different bonuses
- Contested state effects (slow capture when both teams present)
- Visual capture beam effects
- Audio feedback on ownership change
