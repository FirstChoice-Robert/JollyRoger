@tool
class_name WaterLayer
extends TileMapLayer
## Paint water like any tilemap, any size or shape.
## Paint with any water tile: the layer automatically uses the animated
## surface tiles on top and the deep-water tile underneath, so the waves
## always line up.
## At runtime it builds the swim area from the painted cells, adds light
## reflections, and plays splashes when characters fall in or jump out.

const DEEP_TILE := Vector2i(0, 3)
const SURFACE_ROWS := 3          # atlas rows 0..2 = left / middle / right slice of the wave
const SPLASH_IN : Array[Texture2D] = [
	preload("res://Treasure Hunters/Merchant Ship/Sprites/Water/Water Splash 1/1.png"),
	preload("res://Treasure Hunters/Merchant Ship/Sprites/Water/Water Splash 1/2.png"),
	preload("res://Treasure Hunters/Merchant Ship/Sprites/Water/Water Splash 1/3.png"),
	preload("res://Treasure Hunters/Merchant Ship/Sprites/Water/Water Splash 1/4.png"),
	preload("res://Treasure Hunters/Merchant Ship/Sprites/Water/Water Splash 1/5.png"),
]
const SPLASH_OUT : Array[Texture2D] = [
	preload("res://Treasure Hunters/Merchant Ship/Sprites/Water/Water Splash 2/1.png"),
	preload("res://Treasure Hunters/Merchant Ship/Sprites/Water/Water Splash 2/2.png"),
	preload("res://Treasure Hunters/Merchant Ship/Sprites/Water/Water Splash 2/3.png"),
	preload("res://Treasure Hunters/Merchant Ship/Sprites/Water/Water Splash 2/4.png"),
]
const REFLEX_DIRS : Array[String] = [
	"res://Treasure Hunters/Merchant Ship/Sprites/Water/Reflexes 1/",
	"res://Treasure Hunters/Merchant Ship/Sprites/Water/Reflexes 2/",
]

## Automatically pick surface / deep tiles while painting.
@export var auto_tile : bool = true
## Optional ground layer. Water directly under solid ground (flooded caves,
## underwater tunnels) uses the deep tile instead of the wave surface.
@export var solid_layer : TileMapLayer
## Place an animated light reflection every this many columns (0 = none).
## Only in water at least 2 tiles deep.
@export var reflection_every : int = 3
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

var _area : Area2D
var _splash_frames : SpriteFrames
var _retiling : bool = false


func _ready() -> void:
	changed.connect(_on_changed)
	_retile()
	if Engine.is_editor_hint():
		return
	_build_area()
	_build_reflections()


# ---------- Painting ----------

func _on_changed() -> void:
	if auto_tile and not _retiling:
		_retiling = true
		_retile.call_deferred()


func _retile() -> void:
	_retiling = true
	if auto_tile:
		for cell in get_used_cells():
			var want : Vector2i = DEEP_TILE
			if not _is_water(cell + Vector2i.UP) and not _is_solid(cell + Vector2i.UP):
				want = Vector2i(0, posmod(cell.x, SURFACE_ROWS))
			if get_cell_atlas_coords(cell) != want:
				set_cell(cell, get_cell_source_id(cell), want)
	_retiling = false


func _is_water(cell : Vector2i) -> bool:
	return get_cell_source_id(cell) != -1


## True if solid_layer has ground at this cell of the water layer.
func _is_solid(cell : Vector2i) -> bool:
	if solid_layer == null:
		return false
	var world : Vector2 = to_global(map_to_local(cell))
	return solid_layer.get_cell_source_id(solid_layer.local_to_map(solid_layer.to_local(world))) != -1


# ---------- Queries used by characters ----------

## World y of the water surface above (or just below) world_pos, or NAN if there is no water there.
func get_surface_y_at(world_pos : Vector2) -> float:
	var cell : Vector2i = local_to_map(to_local(world_pos))
	if not _is_water(cell):
		cell += Vector2i.DOWN          # feet just above the surface
		if not _is_water(cell):
			return NAN
	while _is_water(cell + Vector2i.UP):
		cell += Vector2i.UP
	var top_local : Vector2 = map_to_local(cell) - Vector2(0, tile_set.tile_size.y * 0.5)
	return to_global(top_local).y


## World y of the bottom of the water column at world_pos, or NAN if there is no water there.
func get_bottom_y_at(world_pos : Vector2) -> float:
	var cell : Vector2i = local_to_map(to_local(world_pos))
	if not _is_water(cell):
		cell += Vector2i.DOWN
		if not _is_water(cell):
			return NAN
	while _is_water(cell + Vector2i.DOWN):
		cell += Vector2i.DOWN
	var bottom_local : Vector2 = map_to_local(cell) + Vector2(0, tile_set.tile_size.y * 0.5)
	return to_global(bottom_local).y


# ---------- Runtime setup ----------

func _build_area() -> void:
	_area = Area2D.new()
	_area.name = "SwimArea"
	add_child(_area)
	var ts : Vector2 = Vector2(tile_set.tile_size)
	# One rectangle per vertical run of water cells in each column.
	var cols : Dictionary = {}
	for cell in get_used_cells():
		if not cols.has(cell.x):
			cols[cell.x] = []
		cols[cell.x].append(cell.y)
	for x in cols:
		var ys : Array = cols[x]
		ys.sort()
		var start : int = ys[0]
		var prev : int = ys[0]
		for i in range(1, ys.size() + 1):
			if i < ys.size() and ys[i] == prev + 1:
				prev = ys[i]
				continue
			var shape := RectangleShape2D.new()
			shape.size = Vector2(ts.x, ts.y * (prev - start + 1))
			var cs := CollisionShape2D.new()
			cs.shape = shape
			var top_left : Vector2 = map_to_local(Vector2i(x, start)) - ts * 0.5
			cs.position = top_left + shape.size * 0.5
			_area.add_child(cs)
			if i < ys.size():
				start = ys[i]
				prev = ys[i]
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)


func _build_reflections() -> void:
	if reflection_every <= 0:
		return
	var frames := SpriteFrames.new()
	for d in REFLEX_DIRS.size():
		var anim : StringName = StringName("reflex_%d" % d)
		frames.add_animation(anim)
		frames.set_animation_speed(anim, 8.0)
		for n in range(1, 7):
			frames.add_frame(anim, load(REFLEX_DIRS[d] + "%d.png" % n))
	var i : int = 0
	for cell in get_used_cells():
		var is_surface : bool = not _is_water(cell + Vector2i.UP)
		if not is_surface or posmod(cell.x, reflection_every) != 0:
			continue
		if not _is_water(cell + Vector2i.DOWN):
			continue      # needs 2+ tiles of depth
		var r := AnimatedSprite2D.new()
		r.sprite_frames = frames
		r.position = map_to_local(cell) + Vector2(0, 22)
		add_child(r)
		r.play(StringName("reflex_%d" % (i % 2)))
		r.frame = (i * 2) % 6
		i += 1


func _on_body_entered(body : Node2D) -> void:
	if body.has_method("enter_water"):
		body.enter_water(self)
	# Any entry with some speed splashes: falling in, jumping in, or walking/swimming in from the side.
	if body is CharacterBody2D and body.velocity.length() > splash_min_speed:
		splash(body.global_position, &"in")


func _on_body_exited(body : Node2D) -> void:
	if body.has_method("exit_water"):
		body.exit_water(self)
	if body is CharacterBody2D and body.velocity.y < -splash_min_speed:
		splash(body.global_position, &"out")


## Play a splash on the surface nearest to world_pos. kind = &"in" or &"out".
func splash(world_pos : Vector2, kind : StringName) -> void:
	var surface : float = get_surface_y_at(world_pos)
	if is_nan(surface):
		surface = get_surface_y_at(world_pos + Vector2(0, tile_set.tile_size.y))
		if is_nan(surface):
			return
	if _splash_frames == null:
		_splash_frames = SpriteFrames.new()
		_splash_frames.remove_animation(&"default")
		for pair in [[&"in", SPLASH_IN], [&"out", SPLASH_OUT]]:
			_splash_frames.add_animation(pair[0])
			_splash_frames.set_animation_speed(pair[0], 12.0)
			_splash_frames.set_animation_loop(pair[0], false)
			for tex in pair[1]:
				_splash_frames.add_frame(pair[0], tex)
	var s := AnimatedSprite2D.new()
	s.sprite_frames = _splash_frames
	add_child(s)
	s.global_position = Vector2(world_pos.x, surface - 6.0)
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
