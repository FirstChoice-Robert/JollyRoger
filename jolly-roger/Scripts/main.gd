class_name Main
extends Node2D
## The game's main scene. Owns everything that stays the same between levels
## (camera + background, the player) and loads the current level into LevelHolder.

## The level to start with.
@export var level_scene : PackedScene

@onready var _camera : PlatformerCamera = $Camera2D
@onready var _player : CharacterBody2D = $Roger
@onready var _holder : Node2D = $LevelHolder

## The level currently loaded.
var level : Level


func _ready() -> void:
	if level_scene:
		load_level(level_scene)


## Swap to another level scene (e.g. when reaching the end of a level).
func load_level(scene : PackedScene) -> void:
	for old in _holder.get_children():
		_holder.remove_child(old)
		old.queue_free()

	level = scene.instantiate() as Level
	_holder.add_child(level)

	# Put the player at the level's start point.
	_player.global_position = level.get_player_start()
	_player.velocity = Vector2.ZERO

	# Hook the camera up to this level.
	_camera.ground_layer = level.ground_layer
	var limits : Rect2i = level.get_camera_limits()
	_camera.limit_left = limits.position.x
	_camera.limit_top = limits.position.y
	_camera.limit_right = limits.end.x
	_camera.limit_bottom = limits.end.y
	_camera.snap_to_target()
