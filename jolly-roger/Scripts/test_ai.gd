extends Node
## Test controller: once on the floor, loops
## jump -> land -> run right -> run left -> repeat.
## Add as a child Node of a character that uses character.gd.

@export var run_time : float = 1.0   # seconds per run direction
@export var pause_time : float = 0.5 # seconds idle between steps

enum Step { WAIT_FLOOR, JUMP, AIRBORNE, PAUSE_AFTER_LAND, RUN_RIGHT, RUN_LEFT, PAUSE_END }

@onready var _character = get_parent()

var _step : Step = Step.WAIT_FLOOR
var _timer : float = 0.0
var _left_floor : bool = false


func _ready() -> void:
	# Randomise per instance so multiple test crabs drift out of sync.
	run_time *= randf_range(0.7, 1.3)
	pause_time *= randf_range(0.6, 1.6)
	_timer = randf_range(0.0, 1.5)


func _physics_process(delta: float) -> void:
	_timer -= delta

	match _step:
		Step.WAIT_FLOOR:
			_character.run(0)
			if _character.is_on_floor() and _timer <= 0:
				_go(Step.JUMP, pause_time)

		Step.JUMP:
			if _timer <= 0:
				_left_floor = false
				_character.jump()
				_go(Step.AIRBORNE, 0)

		Step.AIRBORNE:
			if not _character.is_on_floor():
				_left_floor = true
			elif _left_floor:
				_go(Step.PAUSE_AFTER_LAND, pause_time)

		Step.PAUSE_AFTER_LAND:
			if _timer <= 0:
				_go(Step.RUN_RIGHT, run_time)

		Step.RUN_RIGHT:
			_character.run(1)
			if _timer <= 0:
				_go(Step.RUN_LEFT, run_time)

		Step.RUN_LEFT:
			_character.run(-1)
			if _timer <= 0:
				_character.run(0)
				_go(Step.PAUSE_END, pause_time)

		Step.PAUSE_END:
			if _timer <= 0:
				_go(Step.WAIT_FLOOR, 0)


func _go(next : Step, time : float) -> void:
	_step = next
	_timer = time
