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


func _ready() -> void:
	_speed *= Global.ppt * _speed_scale
	_acceleration *= Global.ppt * _speed_scale
	_deceleration *= Global.ppt * _speed_scale
	_jump_height *= Global.ppt * _speed_scale
	_jump_velocity = sqrt(_jump_height * gravity * 2) * -1
	if _random_anim_offset:
		_anim_tree.active = false
		await get_tree().create_timer(randf_range(0.0, 0.9)).timeout
		_anim_tree.active = true

func _physics_process(delta: float) -> void:
	if sign(_direction) == -1:
		face_left()
	elif sign(_direction) == 1:
		face_right()
		
	if is_on_floor():
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
# Region Public Methods
func face_left():
	_is_facing_left = true
	_sprite.flip_h = not _sprite_faces_left

func face_right():
	_is_facing_left = false
	_sprite.flip_h = _sprite_faces_left

func jump():
	if is_on_floor():
		velocity.y = _jump_velocity
		_spawn_dust(_jump_dust)
		
func stop_jump():
	if velocity.y <0:
		velocity.y = 0

func run(direction : float):
	_direction = direction


func _spawn_dust(dust : PackedScene):
	
	if not is_on_floor():
		return
	
	var _dust = dust.instantiate()
	_dust.position = position
	_dust.flip_h = _is_facing_left
	get_parent().add_child(_dust)
	
