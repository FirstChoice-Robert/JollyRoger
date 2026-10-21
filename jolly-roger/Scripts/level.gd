class_name Level
extends Node2D
## Root script for every level scene. Main reads these to set up the
## player and camera when the level is loaded.

## The level's main ground TileMapLayer (used by the camera to frame the floor).
@export var ground_layer : TileMapLayer
## Work out the camera's left / right / bottom limits from the painted ground.
@export var auto_camera_limits : bool = true
## How far up the camera may go (world pixels). Used with auto limits.
@export var camera_limit_top : int = -1000
## Camera limits to use when auto_camera_limits is off.
@export var manual_camera_limits : Rect2i = Rect2i(-128, -1000, 6400, 1768)


## Where the player starts: the PlayerStart marker, or the level origin.
func get_player_start() -> Vector2:
	var marker := get_node_or_null("PlayerStart") as Node2D
	return marker.global_position if marker else global_position


## Camera limits as a rectangle in world pixels.
func get_camera_limits() -> Rect2i:
	if not auto_camera_limits or ground_layer == null:
		return manual_camera_limits
	var used : Rect2i = ground_layer.get_used_rect()
	var ts : Vector2i = ground_layer.tile_set.tile_size
	var top_left : Vector2 = ground_layer.to_global(Vector2(used.position * ts))
	var bottom_right : Vector2 = ground_layer.to_global(Vector2(used.end * ts))
	var left : int = int(top_left.x)
	var right : int = int(bottom_right.x)
	var bottom : int = int(bottom_right.y)
	return Rect2i(left, camera_limit_top, right - left, bottom - camera_limit_top)
