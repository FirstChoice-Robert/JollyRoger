extends Node2D

@export var _scroll_speed : float = -100
@onready var _big_cloud_1: Sprite2D = $BigClouds
@onready var _big_cloud_2: Sprite2D = $BigClouds2

@onready var _small_cloud_1: Sprite2D = $SmallCloud1
@onready var _small_cloud_2: Sprite2D = $SmallCloud2
@onready var _small_cloud_3: Sprite2D = $SmallCloud3
@onready var _small_cloud_4: Sprite2D = $SmallCloud4
@onready var _small_cloud_5: Sprite2D = $SmallCloud5

func _process(delta: float):
	_scroll(_big_cloud_1, _scroll_speed * delta)
	_scroll(_big_cloud_2, _scroll_speed * delta)
	
	_scroll(_small_cloud_1, _scroll_speed * delta /7)
	_scroll(_small_cloud_2, _scroll_speed * delta /11)
	_scroll(_small_cloud_3, _scroll_speed * delta /5)
	_scroll(_small_cloud_4, _scroll_speed * delta/3)
	_scroll(_small_cloud_5, _scroll_speed * delta /1)
	
	
func _scroll(cloud : Node2D, distance :float):
	cloud.position.x += distance
