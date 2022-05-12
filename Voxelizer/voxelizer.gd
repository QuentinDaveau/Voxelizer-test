extends Spatial
class_name Voxelizer
tool



export(AABB) var voxelization_box: AABB = AABB(Vector3.ZERO, Vector3.ONE * 10.0) setget set_bounding_box
export(float, 0.1, 10) var voxel_size: float = 0.1
export(bool) var bake = false setget bake

var _drawer: BoxDrawer
var _markers: MeshInstance
var _corners: MeshInstance
onready var _thread: Thread = Thread.new()
onready var _caster: Raycaster = Raycaster.new(get_world())

var _voxels: Array



func _ready() -> void:
	if not Engine.editor_hint:
		queue_free()
	_drawer = BoxDrawer.new()
	add_child(_drawer)
	_drawer.draw_aabb(voxelization_box, global_transform.origin, Color.red)
	_markers = MeshInstance.new()
	add_child(_markers)
	_corners = MeshInstance.new()
	add_child(_corners)



func set_bounding_box(value: AABB) -> void:
	voxelization_box = value
	_drawer.draw_aabb(voxelization_box, global_transform.origin, Color.red)



func bake(value: bool) -> void:
	_voxels.empty()
	_markers.mesh = null
	_corners.mesh = null
	
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



func _generate_edges() -> void:
	var i := 0.0
	var j := 0
	for x in _voxels:
		print("Progress: ", (i / _voxels.size()) * 100, " %")
		for y in x:
			for voxel in y:
				voxel.test_edges(_caster)
				j += 1
		i += 1
	call_deferred("_edges_done")
	
	print("Tested: ", j, " voxels")



func _edges_done() -> void:
	print("Edges done !")
	_thread.wait_to_finish()
	
	var j := 0
	for x in _voxels:
		for y in x:
			for voxel in y:
				if voxel.collides():
					j += 1
	
	print(j, " voxels are colliding !")
	
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
	
	# Swapping the mesh normals
#	vertices.invert()
	
	
	var arr_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(ArrayMesh.ARRAY_MAX)
	arrays[ArrayMesh.ARRAY_VERTEX] = vertices
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_markers.mesh = arr_mesh
	
	var debug_vertices: PoolVector3Array = []
	# Generating debug points
	for x in _voxels:
		for y in x:
			for voxel in y:
				for corner in voxel._corners:
					debug_vertices.append_array(_generate_point(corner.position, corner.state == 2))
	
	var debug_arr_mesh = ArrayMesh.new()
	var debug_arrays = []
	debug_arrays.resize(ArrayMesh.ARRAY_MAX)
	debug_arrays[ArrayMesh.ARRAY_VERTEX] = debug_vertices
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, debug_arrays)
	_corners.mesh = debug_arr_mesh
	
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



func _generate_point(center: Vector3, inside: bool = false) -> PoolVector3Array:
	var points: PoolVector3Array = []
	
	var pyramid_top := center + Vector3(0.0, 0.05 * (2.0 if inside else -1.0), 0.0)
	
	points.append_array([center + Vector3(0.05, 0.0, 0.05), center + Vector3(-0.05, 0.0, -0.05), center + Vector3(0.05, 0.0, -0.05)])
	points.append_array([center + Vector3(0.05, 0.0, 0.05), center + Vector3(-0.05, 0.0, -0.05), pyramid_top])
	points.append_array([pyramid_top, center + Vector3(-0.05, 0.0, -0.05), center + Vector3(0.05, 0.0, -0.05)])
	points.append_array([center + Vector3(0.05, 0.0, 0.05), pyramid_top, center + Vector3(0.05, 0.0, -0.05)])
	
	return points



class Voxel:
	var _center: Vector3
	var _size: float
	var _edges := []
	var _corners := []
	
	func _init(center: Vector3, size: float) -> void:
		_center = center
		_size = size
	
	
	
	func collides() -> bool:
		for edge in _edges:
			if edge.is_cut():
				return true
		return false
	
	
	
	func get_corners() -> Array:
		return _corners
	
	
	
	func get_corresponding_vertices() -> PoolVector3Array:
		var offset := _size / 2.0
		var vertices: PoolVector3Array = []
		
		# Simplified version
#		var corners: PoolVector3Array = [
#			_center + Vector3(-1, -1, -1) * offset,
#			_center + Vector3(+1, -1, -1) * offset,
#			_center + Vector3(+1, -1, +1) * offset,
#			_center + Vector3(-1, -1, +1) * offset,
#			_center + Vector3(-1, +1, -1) * offset,
#			_center + Vector3(+1, +1, -1) * offset,
#			_center + Vector3(+1, +1, +1) * offset,
#			_center + Vector3(-1, +1, +1) * offset,
#		]
#		var vert_indexes: Array = TriangulationTable.MC[_corners]
#
#		for index in vert_indexes:
#			if index == -1:
#				continue
#			vertices.append(corners[index])
		
		# Complex version
		var edges: PoolVector3Array = [
			_center + Vector3(-1, -1, 0) * offset,
			_center + Vector3(0, -1, +1) * offset,
			_center + Vector3(+1, -1, 0) * offset,
			_center + Vector3(0, -1, -1) * offset,
			_center + Vector3(-1, +1, 0) * offset,
			_center + Vector3(0, +1, +1) * offset,
			_center + Vector3(+1, +1, 0) * offset,
			_center + Vector3(0, +1, -1) * offset,
			_center + Vector3(-1, 0, -1) * offset,
			_center + Vector3(-1, 0, +1) * offset,
			_center + Vector3(+1, 0, +1) * offset,
			_center + Vector3(+1, 0, -1) * offset,
		]
		
		for index in TriangulationTable.MC[_get_corners_index()]:
			if index == -1:
				continue
			vertices.append(edges[index])
		
		return vertices
	
	
	
	func test_edges(raycaster: Raycaster) -> void:
		var offset := _size / 2.0
		_corners = [
			Corner.new(0, _center + Vector3(-1, -1, -1) * offset),
			Corner.new(1, _center + Vector3(-1, -1, +1) * offset),
			Corner.new(2, _center + Vector3(+1, -1, +1) * offset),
			Corner.new(3, _center + Vector3(+1, -1, -1) * offset),
			Corner.new(4, _center + Vector3(-1, +1, -1) * offset),
			Corner.new(5, _center + Vector3(-1, +1, +1) * offset),
			Corner.new(6, _center + Vector3(+1, +1, +1) * offset),
			Corner.new(7, _center + Vector3(+1, +1, -1) * offset),
		]
		
		_edges = [
			Edge.new(raycaster, _corners[0],  _corners[1]),
			Edge.new(raycaster, _corners[1],  _corners[2]),
			Edge.new(raycaster, _corners[2],  _corners[3]),
			Edge.new(raycaster, _corners[3],  _corners[0]),
			Edge.new(raycaster, _corners[4],  _corners[5]),
			Edge.new(raycaster, _corners[5],  _corners[6]),
			Edge.new(raycaster, _corners[6],  _corners[7]),
			Edge.new(raycaster, _corners[7],  _corners[4]),
			Edge.new(raycaster, _corners[0],  _corners[4]),
			Edge.new(raycaster, _corners[1],  _corners[5]),
			Edge.new(raycaster, _corners[2],  _corners[6]),
			Edge.new(raycaster, _corners[3],  _corners[7]),
		]
		
		_assign_edges_to_corners()
		_assign_neighbours_to_corners()
		
		for corner in _corners:
			corner.first_evaluate_state()
		
		for corner in _corners:
			corner.second_evaluate_state()
		
	
	
	
	
	func _assign_edges_to_corners() -> void:
		_corners[0].set_edges([_edges[3], _edges[0], _edges[8]])
		_corners[1].set_edges([_edges[0], _edges[1], _edges[9]])
		_corners[2].set_edges([_edges[1], _edges[2], _edges[10]])
		_corners[3].set_edges([_edges[2], _edges[3], _edges[11]])
		_corners[4].set_edges([_edges[7], _edges[4], _edges[8]])
		_corners[5].set_edges([_edges[4], _edges[5], _edges[9]])
		_corners[6].set_edges([_edges[5], _edges[6], _edges[10]])
		_corners[7].set_edges([_edges[6], _edges[7], _edges[11]])
	
	
	func _assign_neighbours_to_corners() -> void:
		_corners[0].set_neighbours([_corners[3], _corners[1], _corners[4]])
		_corners[1].set_neighbours([_corners[0], _corners[2], _corners[5]])
		_corners[2].set_neighbours([_corners[1], _corners[3], _corners[6]])
		_corners[3].set_neighbours([_corners[2], _corners[4], _corners[7]])
		_corners[4].set_neighbours([_corners[7], _corners[5], _corners[0]])
		_corners[5].set_neighbours([_corners[4], _corners[6], _corners[1]])
		_corners[6].set_neighbours([_corners[5], _corners[7], _corners[2]])
		_corners[7].set_neighbours([_corners[6], _corners[0], _corners[3]])
	
	
	
	func _get_corners_index() -> int:
		var result := 0
		for i in range(_corners.size()):
			if _corners[i].is_inside():
				result |= 1 << i
		return result
	
	
	
	class Edge:
		var _dist_between_corners: float
		var _corners_cut_dist: Dictionary
		
		func _init(raycaster: Raycaster, corner1: Corner, corner2: Corner) -> void:
			_dist_between_corners = corner1.position.distance_to(corner2.position)
			var data := raycaster.get_collision_data(corner2.position, corner1.position)
			var data2 := raycaster.get_collision_data(corner1.position, corner2.position)
			
			_corners_cut_dist = {
				corner1.index: data.collision_length() if data.collides() else -1,
				corner2.index: data2.collision_length() if data2.collides() else -1
			}
		
		
		func is_cut() -> bool:
			for dist in _corners_cut_dist.values():
				if dist > 0.0:
					return true
			return false
		
		
		# TODO: Add small object check
		func is_inside(index: int) -> bool:
			if not _corners_cut_dist.has(index):
				return false
			if _corners_cut_dist.values()[0] > 0.0 and _corners_cut_dist.values()[1] > 0.0:
				if _corners_cut_dist.values()[0] + _corners_cut_dist.values()[1] < _dist_between_corners:
					return false
			return _corners_cut_dist[index] > 0.0
	
	
	
	class Corner:
		enum STATE {NONE, UNKNOWN, INSIDE, OUTSIDE}
		
		var index: int
		var position: Vector3
		var edges: Array
		var neighbours: Array
		var state: int = STATE.NONE
		
		func _init(index: int, position: Vector3) -> void:
			self.index = index
			self.position = position
		
		
		func set_edges(edges: Array) -> void:
			self.edges = edges
		
		
		func set_neighbours(neighbours: Array) -> void:
			self.neighbours = neighbours
		
		
		func first_evaluate_state() -> void:
			_evaluate_state_first_pass()
		
		
		func second_evaluate_state() -> void:
			_evaluate_state_second_pass()
			edges.empty()
			neighbours.empty()
		
		
		func is_inside() -> bool:
			return state == STATE.INSIDE
		
		
		func _evaluate_state_first_pass() -> void:
			for edge in edges:
				if edge.is_inside(index):
					state = STATE.INSIDE
					return
				if state == STATE.NONE and edge.is_cut():
					state = STATE.OUTSIDE
			if state == STATE.NONE:
				state = STATE.UNKNOWN
		
		
		func _evaluate_state_second_pass() -> void:
			if state != STATE.UNKNOWN:
				return
			for corner in neighbours:
				if corner.state != STATE.UNKNOWN:
					state = corner.state
					return
