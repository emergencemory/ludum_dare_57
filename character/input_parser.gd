extends Control
class_name InputParser

@onready var hud_scene : PackedScene = preload("res://ui/hud.tscn")

var player: CharacterManager
var speed: float = 50.0
var held_directions: Dictionary = { "up": false, "down": false, "left": false, "right": false }
var hud : CanvasLayer
var marker : Marker2D


func _ready() -> void:
	marker = Marker2D.new()
	add_child(marker)


func _input(event: InputEvent) -> void:
	## Player control inputs
	if player == null or player.is_queued_for_deletion() or player.is_in_group("dead"):
		return
	if event.is_action_pressed("move up"):
		player.turn(player.DIR.NORTH)
		held_directions["up"] = true
	if event.is_action_pressed("move down"):
		player.turn(player.DIR.SOUTH)
		held_directions["down"] = true
	if event.is_action_pressed("move left"):
		player.turn(player.DIR.WEST)
		held_directions["left"] = true
	if event.is_action_pressed("move right"):
		player.turn(player.DIR.EAST)
		held_directions["right"] = true
	if event.is_action_released("move up"):
		held_directions["up"] = false
	if event.is_action_released("move down"):
		held_directions["down"] = false
	if event.is_action_released("move left"):
		held_directions["left"] = false
	if event.is_action_released("move right"):
		held_directions["right"] = false
	if event.is_action_pressed("kick"):
		player.kick()
	if event.is_action_pressed("block"):
		player.block_to_right = calc_relative_mouse_pos()
		player.block()
	if event.is_action_pressed("attack"):
		player.swing_from_right = calc_relative_mouse_pos()
		player.prepare_attack()
	if event.is_action_released("attack"):
		player.attack()
	if event.is_action_pressed("zoom in"):
		if player.is_queued_for_deletion() or player.is_in_group("dead") or player.player_camera == null:
			return
		else:
			player.player_camera.zoom -= Vector2(0.05, 0.05)
	if event.is_action_pressed("zoom out"):
		if player.is_queued_for_deletion() or player.is_in_group("dead") or player.player_camera == null:
			return
		else:
			player.player_camera.zoom += Vector2(0.05, 0.05)

func calc_relative_mouse_pos() -> bool:
	## Calculate the mouse position relative to the player
	marker.global_position = player.global_position
	marker.look_at(get_global_mouse_position())
	var mouse_angle = wrapf(marker.global_rotation_degrees - 90, 0, 359)
	# Get the player's facing angle in degrees
	var facing_angle = player.rotation_degrees
	var relative_angle = wrapf(mouse_angle - facing_angle, 0, 359)
	# Determine if the mouse is to the left or right
	if relative_angle < 180:
		return false  # Mouse is to the left
	else:
		return true  # Mouse is to the right

func _physics_process(_delta: float) -> void:
	## Held key movement logic
	if player == null or player.is_queued_for_deletion() or player.is_in_group("dead"):
		return
	if held_directions["up"]:
		player.move(player.DIR.NORTH)
	if held_directions["down"]:
		player.move(player.DIR.SOUTH)
	if held_directions["left"]:
		player.move(player.DIR.WEST)
	if held_directions["right"]:
		player.move(player.DIR.EAST)

