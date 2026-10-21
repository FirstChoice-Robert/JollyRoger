class_name PlatformerCamera
extends Camera2D
## Mario / Sonic style follow camera for a side-scrolling platformer.
##
## Horizontal: the target can move inside a dead zone without the camera
## scrolling; once it pushes past the edge the camera is dragged along
## (Super Mario World). The camera also pans ahead in the direction of
## travel so more of the level in front is visible (Sonic / SMW look-ahead).
##
## Vertical: the camera frames the GROUND, not the player. It looks down the
## ground tilemap beneath the target and keeps the lowest floor that fits on
## screen (with the target still visible) near the bottom of the view. So when
## standing on a floating platform or the top of a staircase the main floor
## stays in shot. Jumping never raises the camera; it only rises after the
## target lands somewhere higher. Falling is always followed.

## Node to follow. Usually the player's CharacterBody2D.
@export var target : Node2D
## The level's ground TileMapLayer. Used to find the floor beneath the target.
## If left empty the camera frames the target's feet instead.
@export var ground_layer : TileMapLayer

@export_category("Horizontal")
## Half-width (world pixels) of the box the target can move in before the camera scrolls.
@export var dead_zone_half_width : float = 12.0
## How far (world pixels) the camera pans ahead in the direction of travel.
@export var look_ahead_distance : float = 48.0
## Speed (world pixels / second) the look-ahead pans when direction changes.
@export var look_ahead_pan_speed : float = 160.0
## Target must move faster than this (pixels / second) to change look-ahead direction.
@export var look_ahead_min_speed : float = 30.0
## If true the look-ahead drifts back to centre when the target stands still.
@export var recentre_when_idle : bool = false

@export_category("Vertical")
## World pixels of ground shown below the floor surface.
@export var ground_space_below : float = 64.0
## Minimum gap (world pixels) kept between the target and the top of the screen.
@export var top_edge_padding : float = 96.0
## Minimum gap (world pixels) kept between the target and the bottom of the screen
## (used while falling or when no floor is found).
@export var bottom_edge_padding : float = 32.0
## How many tiles below the target to search for floor.
@export var ground_search_tiles : int = 20
## How many tiles above the target to look for platforms. If one is found on
## screen, the camera rises so it and the space above it are visible.
@export var look_up_tiles : int = 6
## Platforms more than this many tiles BEHIND the target (opposite to the direction
## of travel) are ignored, so the view drops when moving away from them.
@export var look_up_behind_tiles : int = 1
## World pixels kept visible above a platform found overhead.
@export var space_above_platform : float = 64.0
## How quickly the camera eases to a new height (higher = snappier).
@export var vertical_ease_speed : float = 6.0

var _focus_x : float
var _bottom : float          # world y of the bottom edge of the view
var _look_ahead : float = 0.0
var _look_dir : float = 1.0


func _ready() -> void:
	# Run after the player has moved this physics frame, avoiding a one-frame lag / jitter.
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	process_physics_priority = 100
	position_smoothing_enabled = false
	snap_to_target()


func _physics_process(delta : float) -> void:
	if not is_instance_valid(target):
		return

	var target_pos : Vector2 = target.global_position
	var velocity_x : float = 0.0
	var on_floor : bool = true
	if target is CharacterBody2D:
		velocity_x = target.velocity.x
		on_floor = target.is_on_floor()

	_update_horizontal(target_pos.x, velocity_x, delta)
	_update_vertical(target_pos, on_floor, delta)
	_apply_position()
	# Push the new position to the view now, not next frame, so anything parented
	# to the camera (the background) doesn't lag a frame behind and "bounce back".
	force_update_scroll()


func _update_horizontal(target_x : float, velocity_x : float, delta : float) -> void:
	# Dead zone: drag the focus point only when the target pushes past an edge.
	if target_x > _focus_x + dead_zone_half_width:
		_focus_x = target_x - dead_zone_half_width
	elif target_x < _focus_x - dead_zone_half_width:
		_focus_x = target_x + dead_zone_half_width

	# Look-ahead: pan towards the direction of travel at a constant rate.
	var desired : float
	if absf(velocity_x) > look_ahead_min_speed:
		_look_dir = signf(velocity_x)
		desired = _look_dir * look_ahead_distance
	elif recentre_when_idle:
		desired = 0.0
	else:
		desired = _look_dir * look_ahead_distance
	_look_ahead = move_toward(_look_ahead, desired, look_ahead_pan_speed * delta)


func _update_vertical(target_pos : Vector2, on_floor : bool, delta : float) -> void:
	var desired : float = _desired_bottom(target_pos)
	var t : float = 1.0 - exp(-vertical_ease_speed * delta)

	if on_floor:
		_bottom = lerpf(_bottom, desired, t)
	elif desired > _bottom:
		# Airborne: may move DOWN to show lower ground (walked off a ledge),
		# but never rises until the target lands.
		_bottom = lerpf(_bottom, desired, t)

	# Hard limits so the target never leaves the screen.
	var view_h : float = _view_height()
	var max_bottom : float = target_pos.y + view_h - top_edge_padding
	var min_bottom : float = target_pos.y + bottom_edge_padding
	_bottom = clampf(_bottom, min_bottom, maxf(min_bottom, max_bottom))


## Bottom edge the camera would like: the lowest floor anywhere across the
## screen width that still fits on screen together with the target. So when
## standing on a pillar, step or floating platform, the main floor beside it
## stays in view.
func _desired_bottom(target_pos : Vector2) -> float:
	var max_bottom : float = target_pos.y + _view_height() - top_edge_padding
	var nearest_own : float = INF   # nearest floor directly under the target
	var lowest_fit : float = -INF   # lowest floor on screen that fits
	var highest_above : float = INF # highest platform above the target on screen
	if is_instance_valid(ground_layer):
		var view_half_w : float = get_viewport_rect().size.x / zoom.x * 0.5
		var centre_x : float = _focus_x + _look_ahead
		var own_cell : Vector2i = _cell_at(target_pos + Vector2(0, -2))
		var first_col : int = _cell_at(Vector2(centre_x - view_half_w, target_pos.y)).x
		var last_col : int = _cell_at(Vector2(centre_x + view_half_w, target_pos.y)).x
		for col in range(mini(first_col, own_cell.x), maxi(last_col, own_cell.x) + 1):
			# Floors below the target.
			for s in _surfaces_in_column(col, own_cell.y + 1, own_cell.y + ground_search_tiles):
				var b : float = s + ground_space_below
				if col == own_cell.x and s < nearest_own:
					nearest_own = s
				if b <= max_bottom and b > lowest_fit:
					lowest_fit = b
			# Platforms above the target - only ahead in the direction of travel
			# (plus a small margin behind), so heading away from them lowers the view.
			if (col - own_cell.x) * int(_look_dir) < -look_up_behind_tiles:
				continue
			for s in _surfaces_in_column(col, own_cell.y - look_up_tiles, own_cell.y - 1):
				highest_above = minf(highest_above, s)

	var desired : float
	if lowest_fit > -INF:
		desired = lowest_fit
	elif nearest_own < INF:
		desired = minf(nearest_own + ground_space_below, max_bottom)
	else:
		desired = target_pos.y + ground_space_below

	# Raise the view (giving up some floor if needed) so a platform above is visible.
	if highest_above < INF:
		desired = minf(desired, highest_above - space_above_platform + _view_height())
	return desired


## World y of every surface (solid tile with empty space above it) in one tile
## column between first_row and last_row (inclusive).
func _surfaces_in_column(col : int, first_row : int, last_row : int) -> Array[float]:
	var result : Array[float] = []
	var half_tile : float = ground_layer.tile_set.tile_size.y * 0.5
	var above_solid : bool = ground_layer.get_cell_source_id(Vector2i(col, first_row - 1)) != -1
	for row in range(first_row, last_row + 1):
		var cell : Vector2i = Vector2i(col, row)
		var solid : bool = ground_layer.get_cell_source_id(cell) != -1
		if solid and not above_solid:
			var local_top : Vector2 = ground_layer.map_to_local(cell) - Vector2(0, half_tile)
			result.append(ground_layer.to_global(local_top).y)
		above_solid = solid
	return result


func _cell_at(world_pos : Vector2) -> Vector2i:
	return ground_layer.local_to_map(ground_layer.to_local(world_pos))


func _view_height() -> float:
	return get_viewport_rect().size.y / zoom.y


func _apply_position() -> void:
	global_position = Vector2(_focus_x + _look_ahead, _bottom - _view_height() * 0.5)


## Jump the camera straight to the target (use after respawn / teleport).
func snap_to_target() -> void:
	if not is_instance_valid(target):
		return
	_focus_x = target.global_position.x
	_look_ahead = _look_dir * look_ahead_distance
	_bottom = _desired_bottom(target.global_position)
	_apply_position()
	reset_smoothing()
