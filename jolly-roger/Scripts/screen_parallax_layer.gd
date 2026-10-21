class_name ScreenParallaxLayer
extends Node2D
## Parallax layer for a background that lives under the Camera2D.
##
## Each physics frame - straight after the camera has moved - the layer pins
## itself to the centre of what the camera actually shows (so it stays put when
## the camera hits its limits), then slides its child sprites by a fraction of
## the camera's movement:
##   0.0 = fixed to the screen (like the sky), 1.0 = moves with the level.
## Children wrap around every `wrap_width` pixels so the layer never runs out.

## How much the layer moves with the camera. Far ~0.02-0.1, near ~0.2-0.4.
@export_range(0.0, 1.0, 0.01) var parallax_factor : float = 0.2
## Constant drift in pixels per second (negative = drifts left).
@export var drift_speed : float = 0.0
## Children are wrapped into a band this wide (world pixels), centred on the screen.
## Must be wider than the screen plus the widest child, or sprites pop in/out. 0 = no wrapping.
@export var wrap_width : float = 0.0

var _base_offset : Vector2
var _base_x : Dictionary = {}   # child Node2D -> original local x
var _drift : float = 0.0


func _ready() -> void:
	# Run after the camera (PlatformerCamera uses priority 100) so both move in the same step.
	process_physics_priority = 200
	_base_offset = position
	for child in get_children():
		if child is Node2D:
			_base_x[child] = child.position.x


func _physics_process(delta : float) -> void:
	var cam : Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return
	var centre : Vector2 = _screen_centre(cam)
	global_position = centre + _base_offset

	_drift += drift_speed * delta
	if wrap_width > 0.0:
		_drift = fposmod(_drift, wrap_width)
	var scroll : float = centre.x * parallax_factor - _drift

	for child in _base_x:
		var x : float = _base_x[child] - scroll
		if wrap_width > 0.0:
			x = fposmod(x + wrap_width * 0.5, wrap_width) - wrap_width * 0.5
		child.position.x = x


## Centre of the area actually being drawn this frame (includes camera limits),
## read from the viewport's canvas transform so it always matches the screen.
func _screen_centre(_cam : Camera2D) -> Vector2:
	var view : Transform2D = get_viewport().get_canvas_transform()
	return view.affine_inverse() * (get_viewport_rect().size * 0.5)
