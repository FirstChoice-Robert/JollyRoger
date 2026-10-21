class_name PlatformerCamera
extends Camera2D
## Platformer follow camera (Super Mario World style). Works on any level layout:
## it follows the player, not the shape of the terrain.
##
## Horizontal: the player moves freely inside a small dead zone; past it the
## camera is dragged along, and it pans ahead in the direction of travel.
##
## Vertical ("platform snap"): the camera frames the height the player last
## stood (or swam) at, with the feet at `feet_screen_position` on screen.
## Jumping does not move it. When the player lands somewhere higher or lower it
## eases to the new height. In mid-air it only follows if the player climbs or
## falls outside an allowance band, and it never lets the player leave the screen.
## Holding Down while standing still lets the player look below.

## Node to follow (the player).
@export var target : Node2D

@export_category("Horizontal")
## Half-width (pixels) of the box the player moves in before the camera scrolls.
@export var dead_zone_half_width : float = 12.0
## How far (pixels) the camera pans ahead in the direction of travel.
@export var look_ahead_distance : float = 48.0
## Speed (pixels / second) the look-ahead pans when direction changes.
@export var look_ahead_pan_speed : float = 160.0
## Player must move faster than this (pixels / second) to change look-ahead direction.
@export var look_ahead_min_speed : float = 30.0
## If true the look-ahead drifts back to centre when the player stands still.
@export var recentre_when_idle : bool = false

@export_category("Vertical")
## Where the player's feet sit on screen when standing: 0 = top, 1 = bottom.
## Higher values show more of what is above.
@export_range(0.3, 0.9, 0.01) var feet_screen_position : float = 0.55
## How quickly the camera eases to a new height (higher = snappier).
@export var vertical_ease_speed : float = 5.0
## In mid-air, follow upwards once the player is this far (pixels) above the last ground height.
@export var air_up_allowance : float = 112.0
## In mid-air, follow downwards once the player is this far (pixels) below the last ground height.
@export var air_down_allowance : float = 16.0
## Keep at least this many pixels between the player and the top / bottom of the screen.
@export var screen_edge_padding : float = 40.0

@export_category("Look down")
## How far (pixels) the view moves down when looking down. 0 = off.
@export var look_down_distance : float = 96.0
## Seconds Down must be held (standing still) before the view moves.
@export var look_down_delay : float = 0.35
## Input action used to look down.
@export var look_down_action : StringName = &"move_down"

## Kept so older scenes / scripts that set it still work. Not used any more.
var ground_layer : TileMapLayer

var _focus_x : float
var _look_ahead : float = 0.0
var _look_dir : float = 1.0
var _ground_y : float          # height the camera wants to frame (player feet)
var _frame_y : float           # smoothed version of _ground_y
var _look_down_timer : float = 0.0
var _look_down : float = 0.0


func _ready() -> void:
	# Run after the player has moved this physics frame, avoiding a one-frame lag / jitter.
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	process_physics_priority = 100
	position_smoothing_enabled = false
	snap_to_target()


func _physics_process(delta : float) -> void:
	if not is_instance_valid(target):
		return
	var pos : Vector2 = target.global_position
	var vel : Vector2 = Vector2.ZERO
	var on_floor : bool = true
	if target is CharacterBody2D:
		vel = target.velocity
		on_floor = target.is_on_floor()
	var in_water : bool = target.has_method("is_in_water") and target.is_in_water()

	_update_horizontal(pos.x, vel.x, delta)
	_update_vertical(pos.y, on_floor or in_water, delta)
	_update_look_down(on_floor and absf(vel.x) < 1.0, delta)
	_apply_position(pos.y)
	force_update_scroll()


func _update_horizontal(x : float, vx : float, delta : float) -> void:
	if x > _focus_x + dead_zone_half_width:
		_focus_x = x - dead_zone_half_width
	elif x < _focus_x - dead_zone_half_width:
		_focus_x = x + dead_zone_half_width
	var desired : float
	if absf(vx) > look_ahead_min_speed:
		_look_dir = signf(vx)
		desired = _look_dir * look_ahead_distance
	elif recentre_when_idle:
		desired = 0.0
	else:
		desired = _look_dir * look_ahead_distance
	_look_ahead = move_toward(_look_ahead, desired, look_ahead_pan_speed * delta)


func _update_vertical(feet_y : float, grounded : bool, delta : float) -> void:
	if grounded:
		_ground_y = feet_y                          # standing / swimming: frame this height
	elif feet_y < _ground_y - air_up_allowance:
		_ground_y = feet_y + air_up_allowance       # climbing high (spring, tall jump chain)
	elif feet_y > _ground_y + air_down_allowance:
		_ground_y = feet_y - air_down_allowance     # falling / dropping off a ledge
	var t : float = 1.0 - exp(-vertical_ease_speed * delta)
	_frame_y = lerpf(_frame_y, _ground_y, t)


func _update_look_down(can_look : bool, delta : float) -> void:
	var holding : bool = can_look and look_down_distance > 0.0 \
		and InputMap.has_action(look_down_action) and Input.is_action_pressed(look_down_action)
	_look_down_timer = _look_down_timer + delta if holding else 0.0
	var want : float = look_down_distance if _look_down_timer >= look_down_delay else 0.0
	_look_down = move_toward(_look_down, want, 240.0 * delta)


func _apply_position(feet_y : float) -> void:
	var view_h : float = get_viewport_rect().size.y / zoom.y
	var centre_y : float = _frame_y - view_h * (feet_screen_position - 0.5) + _look_down
	# Never let the player leave the screen (fast falls, big jumps).
	var head_y : float = feet_y - 32.0
	var min_centre : float = feet_y + screen_edge_padding - view_h * 0.5     # feet above bottom edge
	var max_centre : float = head_y - screen_edge_padding + view_h * 0.5    # head below top edge
	if min_centre <= max_centre:
		centre_y = clampf(centre_y, min_centre, max_centre)
	global_position = Vector2(_focus_x + _look_ahead, centre_y)


## Jump the camera straight to the target (after loading a level, respawn, teleport).
func snap_to_target() -> void:
	if not is_instance_valid(target):
		return
	_focus_x = target.global_position.x
	_look_ahead = _look_dir * look_ahead_distance
	_ground_y = target.global_position.y
	_frame_y = _ground_y
	_look_down = 0.0
	_apply_position(target.global_position.y)
	reset_smoothing()
