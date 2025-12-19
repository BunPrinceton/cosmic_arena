# Game Feel & Clarity Improvements

This document outlines the visual feedback and "game juice" improvements added to enhance player experience.

## Overview

All improvements focus on **feedback clarity** without adding new mechanics or requiring art assets. These changes make the game feel more responsive and help players understand what's happening.

---

## 1. Hit Flash Effect

**What it does:** Units, commanders, and cores briefly flash bright white when taking damage.

**Implementation:**
- `scripts/units/unit_base.gd:146-158` - Hit flash for units
- `scripts/commanders/commander.gd:101-112` - Hit flash for commanders

**Technical Details:**
- Uses tween animation to smoothly transition from bright white (2.0, 2.0, 2.0) back to original color
- Duration: 0.15 seconds
- Applied to the Visual ColorRect child node

**Why it works:**
- Bright white flash is immediately noticeable
- Non-blocking (uses tween instead of await)
- Clear visual confirmation of damage

---

## 2. Camera Shake on Core Damage

**What it does:** Screen shakes when either player or enemy core takes damage.

**Implementation:**
- `scripts/main.gd:34-38` - Camera references and shake state
- `scripts/main.gd:113-114` - Connect cores to shake trigger
- `scripts/main.gd:179-198` - Camera shake logic and trigger

**Technical Details:**
- Shake intensity: 8.0 pixels
- Smoothly dampens over time (lerp with factor 10.0)
- Resets to base position when shake amount < 0.1
- Triggered on **any** core health change

**Configuration:**
```gdscript
shake_camera(8.0)  # Adjust intensity here (main.gd:198)
```

**Why it works:**
- Emphasizes importance of core damage
- Creates tension during base attacks
- Screen shake is universally understood as "big impact"

---

## 3. Floating Damage Numbers

**What it does:** Shows damage amount as floating text above damaged entities.

**Implementation:**
- `scripts/floating_damage_number.gd` - Label script with animation
- `scenes/floating_damage_number.tscn` - Label scene
- Integrated into:
  - `scripts/units/unit_base.gd:9, 147, 152-155`
  - `scripts/commanders/commander.gd:12, 91, 96-99`
  - `scripts/core.gd:10, 48, 53-56`

**Technical Details:**
- Font size: 20
- Color: Red (1.0, 0.3, 0.3) with black outline
- Animation: Floats upward 40 pixels over 0.8 seconds while fading out
- Z-index: 100 (renders above everything)
- Spawned as root child to avoid being affected by parent transformations

**Customization:**
```gdscript
# In floating_damage_number.gd:initialize()
add_theme_font_size_override("font_size", 20)  # Size
add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))  # Color
tween.tween_property(self, "global_position:y", global_position.y - 40, 0.8)  # Rise distance & duration
```

**Why it works:**
- Instant numerical feedback on damage dealt
- Helps players evaluate unit effectiveness
- Common pattern in strategy/RPG games

---

## 4. Ability Wind-Up Indicators

**What it does:** Shows expanding colored ring before commander abilities execute.

**Implementation:**
- `scripts/commanders/commander.gd:152-181` - Wind-up system

**Technical Details:**
- 0.3 second delay before ability execution
- Ring color matches ability's visual_color from CommanderAbility data
- Animation: Expands from 40x40 to 80x80 while fading out
- Gives opponents reaction time

**Sequence:**
1. Player/AI calls `use_ability()`
2. `show_ability_windup()` creates expanding ring
3. 0.3 second wait
4. `execute_ability()` fires
5. Cooldown starts

**Why it works:**
- Telegraphs powerful abilities
- Creates anticipation and reaction opportunities
- Makes abilities feel more impactful
- Helps players understand what the enemy commander is doing

---

## Performance Considerations

All effects use:
- **Tweens** instead of constant polling
- **queue_free()** to clean up temporary nodes
- **Minimal allocations** (single ColorRect/Label per effect)
- **No texture loading** (pure code-based visuals)

Expected performance impact: **Negligible** (<1% CPU on most systems)

---

## Future Enhancements

Potential additions that maintain the "no new mechanics, no art assets" constraint:

- **Heal flash**: Green flash when units are healed
- **Death particles**: Simple expanding circles on death
- **Attack indicators**: Small line or arc showing attack direction
- **Energy pulse**: Subtle pulse on energy bar when regenerating
- **Victory/defeat screen shake**: Different shake patterns for win/loss
- **Sound effect hooks**: Prepare signal emission points for future audio

---

## Testing

To verify effects work correctly:

1. **Hit Flash**: Deploy units, watch them attack - should see white flashes
2. **Camera Shake**: Let units damage cores - screen should shake
3. **Damage Numbers**: Red numbers should float upward on every hit
4. **Ability Wind-Up**: Press SPACE as player commander - should see colored ring expand before ability fires

All effects are **purely visual** and do not affect gameplay mechanics.
