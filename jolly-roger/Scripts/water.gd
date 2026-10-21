@tool
class_name Water
extends Area2D
## A body of water built from the Merchant Ship water sprites.
## Characters inside float at the surface, can swim, and jump out at the surface.
## Splashes play when something falls in or jumps out.
## The node's origin is the top-left corner of the water surface.
## Resize it with `size` in the Inspector (not by scaling the node).

const TOP_FRAMES : Array[Texture2D] = [
	preload("res://Treasure Hunters/Merchant Ship/Sprites/Water/Water/Top/1.png"),
	preload("res://Treasure Hunters/Merchant Ship/Sprites/Water/Water/Top/2.png"),
	preload("res://Treasure Hunters/Merchant Ship/Sprites/Water/Water/Top/3.png"),
	preload("res://Treasure Hunters/Merchant Ship/Sprites/Water/Water/Top/4.png"),
]
const TOP_HEIGHT : float = 32.0

## Width and depth of the water in pixels.
@export var size : Vector2 = Vector2(96, 112):
	set(value):
		size = value.max(Vector2(16, TOP_HEIGHT))
		_update_layout()
## Surface wave animation speed (frames per second).
@export var wave_fps : float = 6.0
## Pixels between the animated light reflections under the surface. 0 = none.
@export var reflection_spacing : float = 96.0:
	set(value):
		reflection_spacing = value
		_update_layout()
## Minimum falling / rising speed (pixels per second) that makes a splash.
@export var splash_min_speed : float = 60.0
## Sound played with each splash.
@export var splash_sound : AudioStream = preload("res://Sounds/Water/water_splash_clean.wav")
## Splash volume in dB.
@export_range(-40.0, 6.0, 0.5) var splash_volume_db : float = -6.0
## Random pitch change (+/-) so repeated splashes don't sound identical.
@export_range(0.0, 0.5, 0.01) var splash_pitch_variation : float = 0.1
## Also play the sound when jumping out of the water.
@export var splash_sound_on_exit : bool = false

var _reflections : Array[Node] = []
var _wave_time : float = 0.0


func _ready() -> void:
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)
	_update_layout()


func _process(delta : float) -> void:
	_wave_time += delta
	$Top.texture = TOP_FRAMES[int(_wave_time * wave_fps) % TOP_FRAMES.size()]


## World y of the water surface.
func get_surface_y() -> float:
	return global_position.y


## Same as get_surface_y(); matches WaterLayer so characters can use either.
func get_surface_y_at(_world_pos : Vector2) -> float:
	return global_position.y


## World y of the bottom of the water.
func get_bottom_y_at(_world_pos : Vector2) -> float:
	return global_position.y + size.y


func _on_body_entered(body : Node2D) -> void:
	if body.has_method("enter_water"):
		body.enter_water(self)
	# Any entry with some speed splashes: falling in, jumping in, or walking/swimming in from the side.
	if body is CharacterBody2D and body.velocity.length() > splash_min_speed:
		splash(body.global_position.x, &"in")


func _on_body_exited(body : Node2D) -> void:
	if body.has_method("exit_water"):
		body.exit_water(self)
	if body is CharacterBody2D and body.velocity.y < -splash_min_speed:
		splash(body.global_position.x, &"out")


## Play a splash on the surface at world x. kind = &"in" or &"out".
func splash(world_x : float, kind : StringName) -> void:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = $Splash.sprite_frames
	s.position = Vector2(world_x - global_position.x, -6.0)
	add_child(s)
	s.animation_finished.connect(s.queue_free)
	s.play(kind)

	if kind == &"in" or splash_sound_on_exit:
		_play_splash_sound(s.global_position)


func _play_splash_sound(at : Vector2) -> void:
	if splash_sound == null:
		return
	var p := AudioStreamPlayer2D.new()
	p.stream = splash_sound
	p.volume_db = splash_volume_db
	p.pitch_scale = 1.0 + randf_range(-splash_pitch_variation, splash_pitch_variation)
	add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)
	p.play()


func _update_layout() -> void:
	if not is_node_ready():
		return
	var shape_node : CollisionShape2D = $CollisionShape2D
	(shape_node.shape as RectangleShape2D).size = size
	shape_node.position = size * 0.5

	var top : Sprite2D = $Top
	top.position = Vector2.ZERO
	top.region_rect = Rect2(0, 0, size.x, TOP_HEIGHT)

	var bottom : Sprite2D = $Bottom
	bottom.position = Vector2(0, TOP_HEIGHT)
	bottom.visible = size.y > TOP_HEIGHT
	bottom.region_rect = Rect2(0, 0, size.x, maxf(size.y - TOP_HEIGHT, 1.0))

	_rebuild_reflections()


func _rebuild_reflections() -> void:
	for r in _reflections:
		r.queue_free()
	_reflections.clear()
	if reflection_spacing <= 0.0 or size.y < 56.0:
		return
	var count : int = maxi(1, int(size.x / reflection_spacing))
	for i in count:
		var r := AnimatedSprite2D.new()
		r.sprite_frames = $Reflection.sprite_frames
		r.position = Vector2((i + 0.5) * size.x / count, minf(34.0 + (i % 3) * 10.0, size.y - 20.0))
		add_child(r)   # not owned, so it is never saved into the scene
		r.play(&"reflex_1" if i % 2 == 0 else &"reflex_2")
		r.frame = (i * 2) % 6
		_reflections.append(r)
