extends Area2D
## Restarts the level when the player falls into it (e.g. down a gap).

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body : Node2D) -> void:
	if body.has_node("Player"):
		get_tree().call_deferred("reload_current_scene")
