extends Node2D
class_name MapManager

@onready var wall_layer: TileMapLayer = $WallLayer
@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var cliff_layer: TileMapLayer = $CliffLayer
@onready var splat_1: Texture = preload("res://map/effects/blood_1.png")
@onready var splat_2: Texture = preload("res://map/effects/blood_2.png")
@onready var splat_3: Texture = preload("res://map/effects/blood_3.png")
@onready var blood_pool: Texture = preload("res://character/effects/blood.png")
@onready var audio_stream_player_2d: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var shadow_layer: TileMapLayer = $ShadowLayer
#TODO spawn shadows

var chunk_height: int = 16  # Number of tiles per chunk (e.g., 16x16 tiles)
var chunk_width: int = 32
var tile_size: int = 128  # Size of each tile in pixels
var texture_library: Dictionary = {}  # Dictionary to track loaded textures
var noise : FastNoiseLite   # FastNoiseLite instance
var player : CharacterBody2D

func _ready() -> void:
	SignalBus.health_signal.connect(spawn_blood)
	SignalBus.player_move.connect(generate_chunk)
	# Configure FastNoiseLite
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = .2
	spawn_shadows()

func spawn_shadows() -> void:
	var wall_tiles = wall_layer.get_used_cells()
	for tile in wall_tiles:
		if shadow_layer.get_cell_source_id(tile) != -1:
			continue
		else:
			shadow_layer.set_cell(tile, 0, Vector2i(0,0))

func spawn_label(label_string: String, _position : Vector2, _color : Color) -> void:
	var _label : Label = Label.new()
	_label.text = label_string
	_label.position = _position
	_label.self_modulate = _color
	_label.z_index = 2
	add_child(_label)
	#var label_tween = create_tween()
	#label_tween.tween_property(_label, "self_modulate", Color(1,1,1,0), 1.0)
	get_tree().create_timer(1.1).timeout.connect(_label.queue_free)

func spawn_blood(value: int, _base_value: int, character: CharacterBody2D) -> void:
	# Spawn blood effect at the player's position
	var label_string : String = str(value) + " / " + str(_base_value) + " HP"
	
	if value == _base_value:
		spawn_label(label_string, character.global_position, Color(.5,3,.5,1))
		return
	var blood_effect :Sprite2D = Sprite2D.new()
	blood_effect.global_position = character.global_position + Vector2(randf_range(24, 84), randf_range(-30, 30)) 
	blood_effect.scale = Vector2(randf_range(0.5, 1.5), randf_range(0.5, 1.5))
	blood_effect.rotation_degrees = randf_range(0, 360)
	blood_effect.self_modulate = Color(0.5, 0.5, 0.5, 0.8)
	add_child(blood_effect)
	if value > 0:
		spawn_label(label_string, character.global_position, Color(3,.5,.5,1))
		var roll = randi_range(0,2)
		match roll:
			0:
				blood_effect.texture = splat_1
			1:
				blood_effect.texture = splat_2
			2:
				blood_effect.texture = splat_3
	else:
		spawn_label(label_string, character.global_position, Color(.8,.5,.5,1))
		blood_effect.texture = blood_pool
	var tween = create_tween()
	tween.tween_property(blood_effect, "scale", Vector2(9,9), 20.0)
	texture_library[blood_effect] = ground_layer.local_to_map(blood_effect.position)

func generate_chunk(chunk_position: Vector2) -> void:
	# Generate terrain for the chunk
	var tile_pos = wall_layer.local_to_map(chunk_position)
	audio_stream_player_2d.position = chunk_position
	for y in range(chunk_height):
		for x in range(chunk_width):
			var world_x = tile_pos.x - (chunk_width / 2) + x
			#print("world_x: ", world_x)
			var world_y = tile_pos.y - (chunk_height / 2) + y
			#print("world_y: ", world_y)
			if wall_layer.get_cell_source_id(Vector2i(world_x, world_y)) != -1:
				continue
			if cliff_layer.get_cell_source_id(Vector2i(world_x, world_y)) != -1:
				continue
			if ground_layer.get_cell_source_id(Vector2i(world_x, world_y)) != -1:
				continue
			#if y >= 6 and y <= 10:
				#ground_layer.set_cell(Vector2i(world_x, world_y), 0, Vector2i(0,0))
				#continue
			if y >= 15:
				cliff_layer.set_cell(Vector2i(world_x, world_y), 0, Vector2i(0,0))
				continue
			if y <= 2:
				wall_layer.set_cell(Vector2i(world_x, world_y), 0, Vector2i(0,0))
				continue
			var value = noise.get_noise_2d(world_x, world_y)*10
			#print(value)
			if value > 1.5 and y > 10 or value > 5:
				cliff_layer.set_cell(Vector2i(world_x, world_y), 0, Vector2i(0,0))
			if value < -1.5 and y < 6 or value < -5:
				wall_layer.set_cell(Vector2i(world_x, world_y), 0, Vector2i(0,0))
			else:
				ground_layer.set_cell(Vector2i(world_x, world_y), 0, Vector2i(0,0))
	unload_chunks(tile_pos)
	unload_corpses(tile_pos)
	unload_textures(tile_pos)
	spawn_shadows()

func unload_chunks(player_position: Vector2i) -> void:
	var cliff_tiles = cliff_layer.get_used_cells()
	var wall_tiles = wall_layer.get_used_cells()
	var ground_tiles = ground_layer.get_used_cells()
	var shadow_tiles = shadow_layer.get_used_cells()
	for tile in shadow_tiles:
		if abs(tile.x - player_position.x) >= 30 or abs(tile.y - player_position.y) >= 30:
			shadow_layer.erase_cell(tile)
	for tile in cliff_tiles:
		if abs(tile.x - player_position.x) >= 30 or abs(tile.y - player_position.y) >= 30:
			cliff_layer.erase_cell(tile)
	for tile in wall_tiles:
		if abs(tile.x - player_position.x) >= 30 or abs(tile.y - player_position.y) >= 30:
			wall_layer.erase_cell(tile)
	for tile in ground_tiles:
		if abs(tile.x - player_position.x) >= 30 or abs(tile.y - player_position.y) >= 30:
			# Unload the chunk if it's outside the render distance
			ground_layer.erase_cell(tile)

func unload_corpses(player_position: Vector2i) -> void:
	for corpse in get_tree().get_nodes_in_group("dead"):
		var corpse_position: Vector2i = ground_layer.local_to_map(corpse.position)
		var distance: Vector2i = abs(corpse_position - player_position)
		if distance.x >= 30 or distance.y >= 30:
			# Unload the corpse if it's outside the render distance
			corpse.remove_from_group("dead")
			corpse.queue_free()

func unload_textures(player_position: Vector2i) -> void:
	for texture in texture_library.keys():
		var distance: Vector2i = abs(texture_library[texture] - player_position)
		if distance.x >= 30 or distance.y >= 30:
			# Unload the texture if it's outside the render distance
			print("Unloading " ,texture," at: ", texture_library[texture])
			texture.queue_free()
			texture_library.erase(texture)
