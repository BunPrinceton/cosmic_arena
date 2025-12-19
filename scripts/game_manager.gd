extends Node
class_name GameManager

## Manages the overall game state, win/loss conditions, and game flow

signal game_over(player_won: bool)

enum MatchState {
	PLAYING,
	PLAYER_WON,
	ENEMY_WON
}

var current_state: MatchState = MatchState.PLAYING
var player_core: Node2D
var enemy_core: Node2D

func _ready() -> void:
	pass

func register_player_core(core: Node2D) -> void:
	player_core = core
	if core.has_signal("core_destroyed"):
		core.core_destroyed.connect(_on_player_core_destroyed)

func register_enemy_core(core: Node2D) -> void:
	enemy_core = core
	if core.has_signal("core_destroyed"):
		core.core_destroyed.connect(_on_enemy_core_destroyed)

func _on_player_core_destroyed() -> void:
	if current_state == MatchState.PLAYING:
		current_state = MatchState.ENEMY_WON
		game_over.emit(false)
		print("Game Over - Enemy Wins!")

func _on_enemy_core_destroyed() -> void:
	if current_state == MatchState.PLAYING:
		current_state = MatchState.PLAYER_WON
		game_over.emit(true)
		print("Game Over - Player Wins!")

func is_game_over() -> bool:
	return current_state != MatchState.PLAYING

func reset_game() -> void:
	current_state = MatchState.PLAYING
	get_tree().reload_current_scene()
