@tool
class_name PalmLayer
extends TileMapLayer
## Paint palm trunks with the Terrains tab (terrain "Palm Trunk").
## A palm top (with its one-way platform) is added automatically on the end of
## every trunk, so a painted trunk is a finished, jumpable tree.
## Trunk ends are worked out automatically: an end touching a cliff becomes a
## horizontal root into the rock, an end on the ground a vertical root, and a
## sideways end in the air curls up so it can carry a top.
## The tops are generated, not saved: repaint the trunk to move a tree.

const TRUNK_TILES : Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2),
	Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1),
	Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3),
	Vector2i(0, 4), Vector2i(1, 4),
]
## Tiles that point upwards, so they can carry a palm top.
const UPWARD_TILES : Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(2, 1), Vector2i(0, 3),
	Vector2i(0, 4), Vector2i(1, 4),
]

## Add a palm top on every trunk end.
@export var auto_tops : bool = true:
	set(value):
		auto_tops = value
		_queue_rebuild()
## The level's ground layer. Sideways trunk ends touching it stay as roots;
## all other sideways ends curl upwards and get a palm top.
@export var solid_layer : TileMapLayer:
	set(value):
		solid_layer = value
		_queue_rebuild()
## The scene used for each palm top.
@export var palm_scene : PackedScene = preload("res://Scenes/Decorations/palm_tree.tscn"):
	set(value):
		palm_scene = value
		_queue_rebuild()

var _tops : Array[Node] = []
var _queued : bool = false


var _last_data_hash : int = 0


func _ready() -> void:
	changed.connect(_queue_rebuild)
	set_process(Engine.is_editor_hint())
	_rebuild()


# In the editor, also watch the painted tiles directly, so treetops and roots
# always update while painting (even if the change signal is missed).
func _process(_delta : float) -> void:
	var h : int = hash(tile_map_data)
	if h != _last_data_hash:
		_last_data_hash = h
		_queue_rebuild()


func _queue_rebuild() -> void:
	if _queued or not is_inside_tree():
		return
	_queued = true
	_rebuild.call_deferred()


func _is_trunk(cell : Vector2i) -> bool:
	return get_cell_source_id(cell) != -1 and get_cell_atlas_coords(cell) in TRUNK_TILES


func _rebuild() -> void:
	_queued = false
	for t in _tops:
		if is_instance_valid(t):
			t.queue_free()
	_tops.clear()
	_curl_free_ends()
	if not auto_tops or palm_scene == null:
		return
	var i : int = 0
	for cell in get_used_cells():
		if not _is_trunk(cell) or not (get_cell_atlas_coords(cell) in UPWARD_TILES):
			continue
		if _is_trunk(cell + Vector2i.UP):
			continue      # not the end of the trunk
		var top : Node2D = palm_scene.instantiate()
		top.position = map_to_local(cell) - Vector2(tile_set.tile_size) * 0.5
		add_child(top)    # not owned, so it is never saved into the scene
		var sprite := top.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if sprite:
			sprite.frame = i % 4    # so the trees don't all sway in sync
		_tops.append(top)
		i += 1


const VERTICAL_ROOT := Vector2i(0, 1)   # trunk end going down into the ground
const ROOT_LEFT_END := Vector2i(1, 1)    # sideways root, trunk continues to the right
const ROOT_RIGHT_END := Vector2i(2, 0)   # sideways root, trunk continues to the left
const CURL_FROM_RIGHT := Vector2i(0, 4)  # sideways end that curls up (trunk comes from the right)
const CURL_FROM_LEFT := Vector2i(1, 4)   # sideways end that curls up (trunk comes from the left)
const BEND_LEFT_UP := Vector2i(2, 1)     # left + up
const BEND_UP_RIGHT := Vector2i(1, 0)    # up + right
const BEND_LEFT_DOWN := Vector2i(2, 3)   # left + down
const BEND_DOWN_RIGHT := Vector2i(1, 3)  # down + right


const STRAIGHT_ACROSS := Vector2i(0, 2)


## Decide how each trunk END looks, from what it touches:
## - rock at the side  -> the trunk carries on into the rock with a horizontal
##   root hidden behind it, so it looks like it grows out of the cliff
##   (an end pointing up or down bends sideways into the rock first)
## - ground below      -> a vertical root into the ground
## - sideways in air   -> curls up, ready for a palm top
## - pointing up in air-> left as painted (gets a palm top)
func _curl_free_ends() -> void:
	for cell in get_used_cells():
		if not _is_trunk(cell):
			continue
		var up : bool = _is_trunk(cell + Vector2i.UP)
		var down : bool = _is_trunk(cell + Vector2i.DOWN)
		var left : bool = _is_trunk(cell + Vector2i.LEFT)
		var right : bool = _is_trunk(cell + Vector2i.RIGHT)
		if int(up) + int(down) + int(left) + int(right) != 1:
			continue      # not an end
		var inside : bool = _is_solid(cell)
		var rock_left : bool = _is_solid(cell + Vector2i.LEFT)
		var rock_right : bool = _is_solid(cell + Vector2i.RIGHT)
		var rock_below : bool = _is_solid(cell + Vector2i.DOWN)
		var want : Vector2i = get_cell_atlas_coords(cell)
		var root_cell : Vector2i = cell
		var root_tile : Vector2i = Vector2i(-1, -1)
		if right:                       # trunk carries on to the right
			if inside:
				want = ROOT_LEFT_END
			elif rock_left:
				want = STRAIGHT_ACROSS
				root_cell = cell + Vector2i.LEFT; root_tile = ROOT_LEFT_END
			else:
				want = CURL_FROM_RIGHT
		elif left:                      # trunk carries on to the left
			if inside:
				want = ROOT_RIGHT_END
			elif rock_right:
				want = STRAIGHT_ACROSS
				root_cell = cell + Vector2i.RIGHT; root_tile = ROOT_RIGHT_END
			else:
				want = CURL_FROM_LEFT
		elif down:                      # an end pointing up
			if rock_left:
				want = BEND_LEFT_DOWN
				root_cell = cell + Vector2i.LEFT; root_tile = ROOT_LEFT_END
			elif rock_right:
				want = BEND_DOWN_RIGHT
				root_cell = cell + Vector2i.RIGHT; root_tile = ROOT_RIGHT_END
		elif up:                        # an end pointing down
			if rock_below or inside:
				want = VERTICAL_ROOT
			elif rock_left:
				want = BEND_LEFT_UP
				root_cell = cell + Vector2i.LEFT; root_tile = ROOT_LEFT_END
			elif rock_right:
				want = BEND_UP_RIGHT
				root_cell = cell + Vector2i.RIGHT; root_tile = ROOT_RIGHT_END
			else:
				want = VERTICAL_ROOT
		var src : int = get_cell_source_id(cell)
		if want != get_cell_atlas_coords(cell):
			set_cell(cell, src, want)
		if root_tile != Vector2i(-1, -1) and get_cell_source_id(root_cell) == -1:
			set_cell(root_cell, src, root_tile)   # hidden behind the rock


func _is_solid(cell : Vector2i) -> bool:
	if solid_layer == null:
		return false
	var world : Vector2 = to_global(map_to_local(cell))
	return solid_layer.get_cell_source_id(solid_layer.local_to_map(solid_layer.to_local(world))) != -1
