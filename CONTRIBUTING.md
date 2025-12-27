# Contributing to Cosmic Arena

## Version Requirements

**CRITICAL**: All contributors MUST use **Godot 4.3** exactly.

- ✅ **Allowed**: Godot 4.3.x (any patch version)
- ❌ **Not Allowed**: Godot 4.4+, Godot 5.x, or any dev/beta builds

### Why This Matters

Opening the project in a newer Godot version will:
1. Auto-upgrade scene files (.tscn)
2. Update project.godot with new features
3. Break compatibility for teammates on 4.3
4. Cause merge conflicts and broken builds

## Before You Start

1. **Check your Godot version**: Open Godot → Help → About
2. **Verify it's 4.3.x**: If not, download 4.3 from [Godot's archive](https://godotengine.org/download/archive/)
3. **Never open the project in a different version**

## Git Workflow

### Before Committing

1. Test your changes in-game (press F5)
2. Check for errors in Output panel
3. Only commit files you actually modified

### Avoid Accidental Upgrades

If you see many `.tscn` files changed in git diff but you only edited one scene:
- ❌ **DO NOT COMMIT** - You accidentally upgraded the project
- ✔️ Run `git reset --hard` to undo
- Use the correct Godot version

## Collaboration Best Practices

1. **Communicate changes**: Let team know before major refactors
2. **Pull before working**: Always `git pull` before starting work
3. **Test before pushing**: Run the game to ensure it works
4. **Branch for features**: Use branches for experimental work

## Need Help?

Ask in team chat before:
- Upgrading Godot version
- Adding new plugins/assets
- Changing project settings
- Major architecture changes

---

**Remember**: Using the wrong Godot version is the #1 cause of broken projects in team development.
