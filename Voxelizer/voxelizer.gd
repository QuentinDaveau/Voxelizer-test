extends Spatial
class_name Voxelizer
tool



export(AABB) var voxelization_box: AABB = AABB(Vector3.ZERO, Vector3.ONE * 10.0) setget set_bounding_box
export(float, 0.1, 10) var voxel_size: float = 0.1
export(bool) var bake = false setget bake

var _drawer: BoxDrawer
var _markers: MeshInstance
onready var _thread: Thread = Thread.new()

var _voxels: Array



func _ready() -> void:
	if not Engine.editor_hint:
		queue_free()
	_drawer = BoxDrawer.new()
	add_child(_drawer)
	_drawer.draw_aabb(voxelization_box, global_transform.origin, Color.red)
	_markers = MeshInstance.new()
	add_child(_markers)



func set_bounding_box(value: AABB) -> void:
	voxelization_box = value
	_drawer.draw_aabb(voxelization_box, global_transform.origin, Color.red)



func bake(value: bool) -> void:
	_thread.start(self, "_generate_voxels")



func _generate_voxels() -> Array:
	var voxels := [] # X, Y, Z
	for i in range(0, int(voxelization_box.size.x / voxel_size) + 1):
		var x := []
		for j in range(0, int(voxelization_box.size.y / voxel_size) + 1):
			var y := []
			for k in range(0, int(voxelization_box.size.z / voxel_size) + 1):
				y.append(Voxel.new(global_transform.origin + voxelization_box.position + (Vector3(i, j, k) * voxel_size) + Vector3.ONE * voxel_size / 2.0, voxel_size))
			x.append(y)
		voxels.append(x)
	call_deferred("voxels_done")
	return voxels



func voxels_done() -> void:
	print("Voxels done !")
	_voxels = _thread.wait_to_finish()
	print("Result: ", _voxels.size(), "   ", _voxels[0].size(), "   ", _voxels[0][0].size(), " for a total of ", _voxels.size() * _voxels[0].size() * _voxels[0][0].size(), " voxels")
	_thread.start(self, "_generate_edges")
	
	# Initialize the ArrayMesh.
#	var arr_mesh = ArrayMesh.new()
#	var arrays = []
#	arrays.resize(ArrayMesh.ARRAY_MAX)
#	# Create the Mesh.
#	var vertices = PoolVector3Array()
#	vertices.push_back(Vector3(10, 10, 0))
#	vertices.push_back(Vector3(10, 0, 0))
#	vertices.push_back(Vector3(0, 0, 10))
#	arrays[ArrayMesh.ARRAY_VERTEX] = _corners
#
#	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
#	_markers.mesh = arr_mesh



func _generate_edges() -> int:
	var caster := Raycaster.new(get_world())
	var i := 0.0
	var j := 0
	for x in _voxels:
		print("Progress: ", (i / _voxels.size()) * 100, " %")
		for y in x:
			for voxel in y:
				voxel.test_edges(caster)
				j += 1
		i += 1
	call_deferred("_edges_done")
	print("Tested: ", j, " voxels")
	return OK



func _edges_done() -> void:
	print("Edges done !")
	var result: int = _thread.wait_to_finish()
	print("Generating mesh !")
	_generate_meshes()



func _generate_meshes() -> void:
	var vertices: PoolVector3Array = []
	for x in _voxels:
		for y in x:
			for voxel in y:
				if not voxel.collides():
					continue
				vertices.append_array(voxel.get_corresponding_vertices())
	
	var arr_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(ArrayMesh.ARRAY_MAX)
	arrays[ArrayMesh.ARRAY_VERTEX] = vertices
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_markers.mesh = arr_mesh
	
#	var multimesh := MultiMesh.new()
#	multimesh.transform_format = MultiMesh.TRANSFORM_3D
#	multimesh.set_instance_count(colliding_voxels.size())
#	var cube := CubeMesh.new()
#	cube.size = Vector3.ONE * voxel_size
#	multimesh.mesh = cube
#	_markers.multimesh = multimesh
#
#	for i in range(colliding_voxels.size()):
#		print("Progress: ", (float(i) / colliding_voxels.size()) * 100, " %")
#		_markers.multimesh.set_instance_transform(i, Transform(Basis(), colliding_voxels[i]._center - global_transform.origin))
	



class Voxel:
	var _center: Vector3
	var _size: float
	var _edges: int
	var _corners : int
	
	func _init(center: Vector3, size: float) -> void:
		_center = center
		_size = size
	
	
	
	func collides() -> bool:
		return _corners != 0
	
	
	
	func get_corners() -> int:
		return _corners
	
	
	
	func get_corresponding_vertices() -> PoolVector3Array:
		var offset := _size / 2.0
		var corners: PoolVector3Array = [
			_center + Vector3(-1, -1, -1) * offset,
			_center + Vector3(+1, -1, -1) * offset,
			_center + Vector3(+1, -1, +1) * offset,
			_center + Vector3(-1, -1, +1) * offset,
			_center + Vector3(-1, +1, -1) * offset,
			_center + Vector3(+1, +1, -1) * offset,
			_center + Vector3(+1, +1, +1) * offset,
			_center + Vector3(-1, +1, +1) * offset,
		]
		var vertices: PoolVector3Array = []
		var vert_indexes: Array = TriangulationTable.MC[_corners]
		
		# Extra step to change the vert rotation
#		for i in range(0, vert_indexes.size(), 3):
#			var v: int = vert_indexes[i]
#			vert_indexes[i] = vert_indexes[i + 2]
#			vert_indexes[i + 2] = v
		
		for index in vert_indexes:
			if index == -1:
				continue
			vertices.append(corners[index])
		
		return vertices
	
	
	
	func test_edges(raycaster: Raycaster) -> void:
#		print("Testing edges !")
		var offset := _size / 2.0
		var corners: PoolVector3Array = [
			_center + Vector3(-1, -1, -1) * offset,
			_center + Vector3(+1, -1, -1) * offset,
			_center + Vector3(+1, -1, +1) * offset,
			_center + Vector3(-1, -1, +1) * offset,
			_center + Vector3(-1, +1, -1) * offset,
			_center + Vector3(+1, +1, -1) * offset,
			_center + Vector3(+1, +1, +1) * offset,
			_center + Vector3(-1, +1, +1) * offset,
		]
		
		# Testing the 8 corners
		
		_corners = 0
		_corners += _test_edge(_center, corners[0], raycaster) * 1 << 0
		_corners += _test_edge(_center, corners[1], raycaster) * 1 << 1
		_corners += _test_edge(_center, corners[2], raycaster) * 1 << 2
		_corners += _test_edge(_center, corners[3], raycaster) * 1 << 3
		_corners += _test_edge(_center, corners[4], raycaster) * 1 << 4
		_corners += _test_edge(_center, corners[5], raycaster) * 1 << 5
		_corners += _test_edge(_center, corners[6], raycaster) * 1 << 6
		_corners += _test_edge(_center, corners[7], raycaster) * 1 << 7
#
#		# Testing the 12 edges
#		_edges = 0
#
#		_edges += _test_edge(corners[0], corners[1], raycaster) * 1 << 0
#		_edges += _test_edge(corners[1], corners[2], raycaster) * 1 << 1
#		_edges += _test_edge(corners[2], corners[3], raycaster) * 1 << 2
#		_edges += _test_edge(corners[3], corners[0], raycaster) * 1 << 3
#		_edges += _test_edge(corners[0], corners[4], raycaster) * 1 << 4
#		_edges += _test_edge(corners[1], corners[5], raycaster) * 1 << 5
#		_edges += _test_edge(corners[2], corners[6], raycaster) * 1 << 6
#		_edges += _test_edge(corners[3], corners[7], raycaster) * 1 << 7
#		_edges += _test_edge(corners[4], corners[5], raycaster) * 1 << 8
#		_edges += _test_edge(corners[5], corners[6], raycaster) * 1 << 9
#		_edges += _test_edge(corners[6], corners[7], raycaster) * 1 << 10
#		_edges += _test_edge(corners[7], corners[0], raycaster) * 1 << 11
#
#		_generate_corners()
	
	
	
	func _generate_corners() -> void:
		# i de 0 à 11
		_corners = 0
		for i in range(12):
			if _edges & 1 << i:
				_corners |= TriangulationTable.Edges[i]
#		print(_corners, "    ", _edges)
	
	
	
	func _test_edge(a: Vector3, b: Vector3, caster: Raycaster) -> int:
		var collides := caster.collides(b, a)
		# Testing both ways for single-side collision
		return 1 if collides or caster.collides(a, b) else 0

