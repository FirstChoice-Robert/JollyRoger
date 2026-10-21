extends CharacterBody2D

@export_category("Locomotion")
@export var _speed : float = 8	
@export var _acceleration : float = 16
@export var _deceleration : float = 32
## 1.0 = normal. Lower = slower AND jumps lower; higher = faster and jumps higher.
@export_range(0.1, 3.0, 0.05) var _speed_scale : float = 1.0

@export_category("Jump")
@export var _jump_height : float = 2.5
@export var _air_control :float = 0.5
@export var _jump_dust : PackedScene

@export_category("Swim")
## How far (tiles) the feet sit below the water surface when floating.
@export var _float_depth : float = 0.5
## Horizontal speed in water compared with on land.
@export_range(0.1, 1.0, 0.05) var _swim_speed_scale : float = 0.6
## Gravity in water compared with in air.
@export_range(0.0, 1.0, 0.05) var _water_gravity_scale : float = 0.25
## Upward push (tiles / s²) when deeper than the float depth.
@export var _buoyancy : float = 50.0
## How quickly vertical movement is slowed in water (higher = thicker water).
@export var _water_drag : float = 4.0
## Upward speed (tiles / s) from pressing jump while under the surface.
@export var _swim_stroke : float = 5.0
## Fastest sinking speed in water (tiles / s), e.g. after falling in.
@export var _max_sink_speed : float = 5.0
## Speed (tiles / s) when swimming down (holding Down / S).
@export var _swim_down_speed : float = 4.0

@export_category("Sprite")
@export var _sprite_faces_left : bool = false

@export_category("Animation")
@export var _random_anim_offset : bool = false

@onready var _sprite : Sprite2D = $Sprite2D
@onready var _anim_tree : AnimationTree = $Sprite2D/AnimationPlayer/AnimationTree
var _is_facing_left : bool = false

var gravity : float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _jump_velocity : float
var _direction : float
var _swim_down : float = 0.0     # 0..1, how hard "down" is held

var _waters : Array[Node] = []     # water areas currently overlapping
var _leaving_water : bool = false  # jumped out; ignore water until falling


func _ready() -> void:
	_speed *= Global.ppt * _speed_scale
	_acceleration *= Global.ppt * _speed_scale
	_deceleration *= Global.ppt * _speed_scale
	_jump_height *= Global.ppt * _speed_scale
	_jump_velocity = sqrt(_jump_height * gravity * 2) * -1
	_float_depth *= Global.ppt
	_buoyancy *= Global.ppt
	_swim_stroke *= Global.ppt
	_max_sink_speed *= Global.ppt
	_swim_down_speed *= Global.ppt
	if _random_anim_offset:
		_anim_tree.active = false
		await get_tree().create_timer(randf_range(0.0, 0.9)).timeout
		_anim_tree.active = true

func _physics_process(delta: float) -> void:
	if sign(_direction) == -1:
		face_left()
	elif sign(_direction) == 1:
		face_right()
		
	if _leaving_water and (velocity.y >= 0.0 or is_on_floor()):
		_leaving_water = false

	if is_in_water():
		_water_physics(delta)
	elif is_on_floor():
		_ground_physics(delta)
	else:
		_air_physics(delta)
	move_and_slide()
	
func _ground_physics(delta : float):
	if _direction == 0:
		velocity.x = move_toward(velocity.x, 0, _deceleration * delta)
		# speed up from not moving or moving in same direction
	elif velocity.x == 0 or sign(_direction) == sign(velocity.x):
		velocity.x = move_toward(velocity.x, _direction * _speed, _acceleration * delta)
	# slowing if trying to move in opposite direction
	else:
		velocity.x = move_toward(velocity.x, _direction * _speed, _deceleration * delta)
	
func _air_physics(delta : float):
	velocity.y += gravity * delta
	if _direction:
		velocity.x = move_toward(velocity.x, _direction * _speed, _acceleration * _air_control * delta)

func _water_physics(delta : float):
	# Paddle sideways at reduced speed.
	var swim_speed : float = _speed * _swim_speed_scale
	velocity.x = move_toward(velocity.x, _direction * swim_speed, _acceleration * _swim_speed_scale * delta)
	if _swim_down > 0.0:
		# Holding down: swim towards the bottom.
		velocity.y = move_toward(velocity.y, _swim_down_speed * _swim_down, _buoyancy * delta)
	else:
		# Sink gently; below the float depth, buoyancy pushes back up so we bob at the surface.
		velocity.y += gravity * _water_gravity_scale * delta
		if _depth() > _float_depth:
			velocity.y -= _buoyancy * delta
		velocity.y = lerpf(velocity.y, 0.0, 1.0 - exp(-_water_drag * delta))
	velocity.y = minf(velocity.y, _max_sink_speed)
	# Never swim out through the bottom of the water.
	var bottom : float = _waters.back().get_bottom_y_at(global_position)
	if not is_nan(bottom) and velocity.y > 0.0:
		velocity.y = minf(velocity.y, maxf(bottom - 2.0 - global_position.y, 0.0) / delta)

## How far (pixels) the feet are below the surface of the water we're in
## (0 or less = not under the surface).
func _depth() -> float:
	if _waters.is_empty():
		return 0.0
	var surface : float = _waters.back().get_surface_y_at(global_position)
	if is_nan(surface):
		return 0.0
	return global_position.y - surface

# Region Public Methods
## True while the character's feet are under the surface of a water area.
func is_in_water() -> bool:
	return not _waters.is_empty() and not _leaving_water and _depth() > 0.0

func enter_water(water : Node):
	if not _waters.has(water):
		_waters.append(water)

func exit_water(water : Node):
	_waters.erase(water)

func face_left():
	_is_facing_left = true
	_sprite.flip_h = not _sprite_faces_left

func face_right():
	_is_facing_left = false
	_sprite.flip_h = _sprite_faces_left

func jump():
	if is_in_water():
		if _depth() <= _float_depth + 4.0:
			# At the surface: full jump out of the water.
			velocity.y = _jump_velocity
			_leaving_water = true
		else:
			# Under water: swim stroke upwards.
			velocity.y = minf(velocity.y, -_swim_stroke)
		return
	if is_on_floor():
		velocity.y = _jump_velocity
		_spawn_dust(_jump_dust)

func stop_jump():
	if is_in_water():
		return
	if velocity.y <0:
		velocity.y = 0

func run(direction : float):
	_direction = direction

## 0..1: how hard "down" is held. Only has an effect in water.
func swim(down : float):
	_swim_down = down


func _spawn_dust(dust : PackedScene):
	
	if not is_on_floor():
		return
	
	var _dust = dust.instantiate()
	_dust.position = position
	_dust.flip_h = _is_facing_left
	get_parent().add_child(_dust)
	
