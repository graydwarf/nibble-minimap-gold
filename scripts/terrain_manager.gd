# Copyright (c) 2025 Poplava. All rights reserved.
# Licensed for use in your projects. Redistribution prohibited.
# See LICENSE file for full terms.

extends Node3D
class_name TerrainManager
## Manages procedural terrain chunk generation around the player.
##
## Currently generates a single chunk for the Gold demo.
## Designed to easily extend to infinite terrain by adding chunk loading/unloading.
##
## EXTENDING TO INFINITE TERRAIN:
## 1. Set view_distance > 0 to enable multi-chunk mode
## 2. Call update_chunks(player_position) each frame
## 3. Chunks auto-load/unload based on player position
##
## Usage:
##   # In main scene, add TerrainManager node
##   # Set exported properties in inspector or code
##   terrain_manager.generate_initial_terrain()

signal terrain_ready

@export_group("Terrain Settings")
@export var chunk_size: float = 100.0  ## World units per chunk
@export var resolution: int = 50  ## Vertices per chunk edge
@export var height_scale: float = 15.0  ## Max height variation

@export_group("Noise Settings")
@export var noise_seed: int = 12345
@export var noise_frequency: float = 0.015  ## Lower = smoother hills
@export var noise_octaves: int = 4
@export var noise_lacunarity: float = 2.0
@export var noise_gain: float = 0.5

@export_group("Chunk Loading (Future)")
@export var view_distance: int = 0  ## Chunks to load around player (0 = single chunk mode)

var noise: FastNoiseLite
var _chunks: Dictionary = {}  # Vector2i -> TerrainChunk
var _is_ready: bool = false

func _ready() -> void:
	_setup_noise()
	generate_initial_terrain()

func _setup_noise() -> void:
	noise = FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = noise_frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = noise_octaves
	noise.fractal_lacunarity = noise_lacunarity
	noise.fractal_gain = noise_gain

# Generates initial terrain (single chunk for Gold, expandable for infinite)
func generate_initial_terrain() -> void:
	if view_distance == 0:
		# Single chunk mode - just generate center chunk
		_load_chunk(Vector2i.ZERO)
	else:
		# Multi-chunk mode - generate grid around origin
		for z in range(-view_distance, view_distance + 1):
			for x in range(-view_distance, view_distance + 1):
				_load_chunk(Vector2i(x, z))

	_is_ready = true
	terrain_ready.emit()

const TerrainChunkScript = preload("res://scripts/terrain_chunk.gd")

# Loads a chunk at the given coordinate if not already loaded
func _load_chunk(coord: Vector2i) -> Node3D:
	if _chunks.has(coord):
		return _chunks[coord]

	var chunk := TerrainChunkScript.new()
	chunk.generate(coord, noise, chunk_size, resolution, height_scale)
	chunk.name = "Chunk_%d_%d" % [coord.x, coord.y]
	add_child(chunk)
	_chunks[coord] = chunk
	return chunk

# Unloads a chunk at the given coordinate
func _unload_chunk(coord: Vector2i) -> void:
	if _chunks.has(coord):
		_chunks[coord].queue_free()
		_chunks.erase(coord)

# Updates loaded chunks based on player position (for infinite terrain)
# Call this in _process or _physics_process when using view_distance > 0
func update_chunks(player_pos: Vector3) -> void:
	if view_distance == 0:
		return  # Single chunk mode, no updates needed

	var player_chunk := Vector2i(
		int(floor(player_pos.x / chunk_size)),
		int(floor(player_pos.z / chunk_size))
	)

	# Load chunks in range
	for z in range(player_chunk.y - view_distance, player_chunk.y + view_distance + 1):
		for x in range(player_chunk.x - view_distance, player_chunk.x + view_distance + 1):
			_load_chunk(Vector2i(x, z))

	# Unload chunks out of range
	var chunks_to_remove: Array[Vector2i] = []
	for coord: Vector2i in _chunks.keys():
		if abs(coord.x - player_chunk.x) > view_distance + 1 or \
		   abs(coord.y - player_chunk.y) > view_distance + 1:
			chunks_to_remove.append(coord)

	for coord: Vector2i in chunks_to_remove:
		_unload_chunk(coord)

# Returns terrain height at world position
# Use this for placing objects on terrain
func get_height_at(world_pos: Vector3) -> float:
	if not noise:
		return 0.0
	return TerrainChunkScript.get_height_at(noise, world_pos, height_scale)

# Returns whether terrain is ready
func is_ready() -> bool:
	return _is_ready
