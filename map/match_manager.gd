extends Node
class_name MatchManager

const INPUT_PARSER : Script = preload("res://character/input_parser.gd")
const GAME_DATA : Script = preload("res://data/GameData.gd")


@onready var character_scene : PackedScene = preload("res://character/character_model.tscn")
var player : CharacterBody2D
var hud_scene : PackedScene = preload("res://ui/hud.tscn")
var character_data : Dictionary
var layer : int = 1
var current_orcs : int = 0
var current_knights : int = 0
var enemy_deaths : int = 0
var knight_deaths : int = 0
var your_deaths : int = -1
var knight_kills : int = 0
var your_kills : int = 0
var hud : CanvasLayer

signal update_player_hud(layer, current_orcs, your_kills, your_deaths, current_knights, knight_kills, knight_deaths)

func _ready() -> void:
	character_data = GAME_DATA.character_data.duplicate()
	get_tree().create_timer(1.0).timeout.connect(spawn_player)

func spawn_player() -> void:
	player = character_scene.instantiate()
	set_data(player)
	player.is_player = true
	add_child(player)
	player.add_to_group("knight")
	player.global_position = get_valid_spawn(player)
	var player_controller = INPUT_PARSER.new()
	player_controller.player = player
	player.add_child(player_controller)
	hud = hud_scene.instantiate()
	player.attack_signal.connect(hud._on_attack_cooldown_started)
	player.block_signal.connect(hud._on_block_cooldown_started)
	player.move_signal.connect(hud._on_move_cooldown_started)
	player.kick_signal.connect(hud._on_kick_cooldown_started)
	player.health_signal.connect(hud._on_health_changed)
	player.killed_by_knight.connect(_on_knight_kill)
	player.killed_by_orc.connect(_on_orc_kill)
	player.killed_by_player.connect(_on_player_kill)
	update_player_hud.connect(hud._on_update_player_hud)
	player_controller.add_child(hud)
	var player_camera = Camera2D.new()
	player.add_child(player_camera)
	your_deaths += 1
	update_hud()
	player_camera.make_current()
	player.character_sprite.sprite_frames = ResourceLoader.load("res://character/knight/knight_spriteframes.tres")
	spawn_ai("orc")
	spawn_ai("knight")

func set_data(character:CharacterBody2D) -> void:
	character.base_attack_cooldown = character_data["attack_cooldown"]
	character.base_attack_damage = character_data["attack_damage"]
	character.base_attack_speed = character_data["attack_speed"]
	character.base_block_duration = character_data["block_duration"]
	character.base_block_cooldown = character_data["block_cooldown"]
	character.base_health = character_data["base_health"]
	character.base_speed = character_data["speed"]
	character.base_move_cooldown = character_data["move_cooldown"]
	character.base_kick_stun_duration = character_data["kick_stun"]
	character.base_kick_cooldown = character_data["kick_cooldown"]

func spawn_ai(team:String) -> void:
	var character = character_scene.instantiate()
	set_data(character)
	character.team = team
	character.killed_by_knight.connect(_on_knight_kill)
	character.killed_by_orc.connect(_on_orc_kill)
	character.killed_by_player.connect(_on_player_kill)
	add_child(character)
	character.add_to_group(team)
	character.global_position = get_valid_spawn(character)
	character.add_to_group("ai")
	character.character_sprite.sprite_frames = ResourceLoader.load("res://character/" + team + "/" + team + "_spriteframes.tres")
	if team == "orc":
		current_orcs += 1
	if team == "knight":
		current_knights += 1
	update_hud()

func get_valid_spawn(character : CharacterBody2D) -> Vector2:
	var spawn_pos : Vector2
	var spawn_area : Rect2 = player.get_viewport().get_visible_rect()
	var valid_spawn : bool = false
	var team : String
	if character.is_in_group("orc"):
		team = "orc"
	elif character.is_in_group("knight"):
		team = "knight"
	else:
		print("Invalid team for character: ", character.name)
		return Vector2.ZERO
	while not valid_spawn:
		var _spawn_pos : Vector2
		if character.is_player:
			# Spawn in the centerish of the screen
			_spawn_pos.x = randf_range(spawn_area.position.x, (spawn_area.end.x)/2)  + (256*(layer -1))
		elif team == "knight":
			# Spawn on the left side of the screen
			_spawn_pos.x = randf_range(spawn_area.position.x - 256, spawn_area.position.x) + (256*(layer-1))
		else: # orc
			# Spawn on the right side of the screen
			_spawn_pos.x = randf_range(spawn_area.end.x, spawn_area.end.x + 256)  + (256*(layer-1))
		_spawn_pos.y = randf_range(spawn_area.position.y, spawn_area.end.y)
		spawn_pos = _spawn_pos.snapped(Vector2(128, 128))
		var collision_checker : RayCast2D = RayCast2D.new()
		collision_checker.global_position = spawn_pos
		collision_checker.target_position = Vector2(64,64)
		collision_checker.collide_with_areas = true
		collision_checker.collision_mask = 1
		collision_checker.hit_from_inside = true
		add_child(collision_checker)
		collision_checker.force_raycast_update()
		if collision_checker.is_colliding():
			collision_checker.queue_free()
			print("Collision detected at: ", spawn_pos)
			continue
		
		else:
			collision_checker.queue_free()
			print("No collision at: ", spawn_pos)
			valid_spawn = true
	return spawn_pos

#TODO AI turn, move, attack, block, kick	
func _physics_process(delta: float) -> void:
	for character in get_tree().get_nodes_in_group("ai"):
		if not is_instance_valid(character) or character.is_queued_for_deletion() or character.is_in_group("dead"):
			continue
		elif character.has_target == false or not is_instance_valid(character.target) or character.target.is_in_group("dead"):
			var target = get_target(character) # this spawns new waves too
			if target != null:
				character.has_target = true
				get_tree().create_timer(1.0).timeout.connect(character._on_target_timeout)
				character.target = target
		var distance_to_target = character.global_position.distance_to(character.target.global_position)
		var direction_to_target = (character.target.global_position - character.global_position)

		



func get_target(character: CharacterBody2D) -> CharacterBody2D:
	var nearest_target = null
	if character.is_in_group("orc"):
		var potential_targets = get_tree().get_nodes_in_group("knight")
		if potential_targets.size() == 0:
			for i in layer:
				spawn_ai("knight")
			return nearest_target
		for target in potential_targets:
			if not target.is_queued_for_deletion():
				if nearest_target == null or character.position.distance_to(target.position) < character.position.distance_to(nearest_target.position):
					nearest_target = target
	elif character.is_in_group("knight"):
		var potential_targets = get_tree().get_nodes_in_group("orc")
		if potential_targets.size() == 0:
			layer += 1
			update_hud()
			for i in layer:
				spawn_ai("orc")
			return nearest_target
		for target in potential_targets:
			if not target.is_queued_for_deletion():
				if nearest_target == null or character.position.distance_to(target.position) < character.position.distance_to(nearest_target.position):
					nearest_target = target
	return nearest_target

func _on_knight_kill(team: String) -> void:
	if team == "orc":
		current_orcs -= 1
		knight_kills += 1
	elif team == "knight":
		current_knights -= 1
	update_hud()

func _on_orc_kill(team: String) -> void:
	if team == "knight":
		current_knights -= 1
		knight_deaths += 1
	elif team == "orc":
		current_orcs -= 1
	update_hud()

func _on_player_kill(team: String) -> void:
	if team == "orc":
		current_orcs -= 1
		your_kills += 1
	elif team == "knight":
		current_knights -= 1
	update_hud()


func update_hud() -> void:
	emit_signal("update_player_hud", layer, current_orcs, your_kills, your_deaths, current_knights, knight_kills, knight_deaths)
