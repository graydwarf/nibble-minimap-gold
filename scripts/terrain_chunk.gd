# Copyright (c) 2025 Poplava. All rights reserved.
# Licensed for use in your projects. Redistribution prohibited.
# See LICENSE file for full terms.

extends Node3D
class_name TerrainChunk
## Generates a single terrain chunk with procedural noise heightmap.
##
## Creates a mesh and collision shape from FastNoiseLite.
## Designed for chunk-based terrain systems - can be tiled seamlessly.
##
## Usage:
##   var chunk = TerrainChunk.new()
##   chunk.generate(Vector2i(0, 0), noise, chunk_size, resolution, height_scale)
##   add_child(chunk)

var chunk_coord: Vector2i = Vector2i.ZERO
var chunk_size: float = 100.0
var _mesh_instance: MeshInstance3D
var _static_body: StaticBody3D
var _collision_shape: CollisionShape3D

# Generates the terrain chunk at the given chunk coordinate
# chunk_coord: Grid coordinate (0,0 is origin chunk)
# noise: FastNoiseLite instance for height generation
# size: World units per chunk edge
# resolution: Vertices per chunk edge (higher = more detail)
# height_scale: Maximum height variation
func generate(coord: Vector2i, noise: FastNoiseLite, size: float = 100.0,
		resolution: int = 50, height_scale: float = 15.0) -> void:
	chunk_coord = coord
	chunk_size = size

	# Position chunk in world space
	position = Vector3(coord.x * size, 0, coord.y * size)

	# Generate mesh
	var mesh := _create_terrain_mesh(noise, size, resolution, height_scale)

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = mesh
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_mesh_instance)

	# Generate collision
	_static_body = StaticBody3D.new()
	_collision_shape = CollisionShape3D.new()
	_collision_shape.shape = mesh.create_trimesh_shape()
	_static_body.add_child(_collision_shape)
	add_child(_static_body)

	# Apply grass material with procedural texture
	_mesh_instance.material_override = _create_grass_material()

# Creates terrain mesh using noise for height
func _create_terrain_mesh(noise: FastNoiseLite, size: float,
		resolution: int, height_scale: float) -> ArrayMesh:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var step := size / float(resolution - 1)
	var half_size := size / 2.0

	# Generate vertices with heights from noise
	var heights: Array[Array] = []
	for z in range(resolution):
		var row: Array[float] = []
		for x in range(resolution):
			# World position for noise sampling (accounts for chunk offset)
			var world_x := (chunk_coord.x * size) + (x * step) - half_size
			var world_z := (chunk_coord.y * size) + (z * step) - half_size

			var height := noise.get_noise_2d(world_x, world_z) * height_scale
			row.append(height)
		heights.append(row)

	# Build triangles
	for z in range(resolution - 1):
		for x in range(resolution - 1):
			var x0 := x * step - half_size
			var x1 := (x + 1) * step - half_size
			var z0 := z * step - half_size
			var z1 := (z + 1) * step - half_size

			var h00: float = heights[z][x]
			var h10: float = heights[z][x + 1]
			var h01: float = heights[z + 1][x]
			var h11: float = heights[z + 1][x + 1]

			# UV coordinates
			var uv00 := Vector2(float(x) / resolution, float(z) / resolution)
			var uv10 := Vector2(float(x + 1) / resolution, float(z) / resolution)
			var uv01 := Vector2(float(x) / resolution, float(z + 1) / resolution)
			var uv11 := Vector2(float(x + 1) / resolution, float(z + 1) / resolution)

			# Triangle 1
			var v0 := Vector3(x0, h00, z0)
			var v1 := Vector3(x1, h10, z0)
			var v2 := Vector3(x0, h01, z1)
			var n1 := (v1 - v0).cross(v2 - v0).normalized()

			surface_tool.set_normal(n1)
			surface_tool.set_uv(uv00)
			surface_tool.add_vertex(v0)
			surface_tool.set_uv(uv10)
			surface_tool.add_vertex(v1)
			surface_tool.set_uv(uv01)
			surface_tool.add_vertex(v2)

			# Triangle 2
			var v3 := Vector3(x1, h10, z0)
			var v4 := Vector3(x1, h11, z1)
			var v5 := Vector3(x0, h01, z1)
			var n2 := (v4 - v3).cross(v5 - v3).normalized()

			surface_tool.set_normal(n2)
			surface_tool.set_uv(uv10)
			surface_tool.add_vertex(v3)
			surface_tool.set_uv(uv11)
			surface_tool.add_vertex(v4)
			surface_tool.set_uv(uv01)
			surface_tool.add_vertex(v5)

	return surface_tool.commit()

# Returns height at a world position using noise
# Useful for placing objects on terrain
static func get_height_at(noise: FastNoiseLite, world_pos: Vector3,
		height_scale: float = 15.0) -> float:
	return noise.get_noise_2d(world_pos.x, world_pos.z) * height_scale

# Creates a procedural grass material with noise variation
func _create_grass_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()

	# Base grass color
	material.albedo_color = Color(0.28, 0.45, 0.22)  # Lush grass green

	# Create noise texture for variation
	var noise_tex := NoiseTexture2D.new()
	var detail_noise := FastNoiseLite.new()
	detail_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	detail_noise.frequency = 0.05
	detail_noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	detail_noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	noise_tex.noise = detail_noise
	noise_tex.width = 512
	noise_tex.height = 512
	noise_tex.seamless = true

	# Use noise as detail texture for grass-like variation
	material.detail_enabled = true
	material.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	material.detail_uv_layer = BaseMaterial3D.DETAIL_UV_1
	material.detail_albedo = noise_tex

	# Terrain-appropriate settings
	material.roughness = 0.9
	material.metallic = 0.0

	# UV scaling for tiling
	material.uv1_scale = Vector3(8, 8, 8)

	return material
