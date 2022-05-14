extends Spatial
class_name Voxelizer
tool



export(AABB) var voxelization_box: AABB = AABB(Vector3.ZERO, Vector3.ONE * 10.0) setget set_bounding_box
export(float, 0.1, 10) var voxel_size: float = 0.1
export(bool) var apply_smoothing = false
export(bool) var bake = false setget bake

var _drawer: BoxDrawer
var _markers: MeshInstance
var _corners: MeshInstance
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
	
	var processed := 0
	
	for i in range(voxels.size()):
		for j in range(voxels[i].size()):
			for k in range(voxels[i][j].size()):
				var neighbours := [null, null, null]
				if i > 0:
					neighbours[0] = voxels[i-1][j][k]
				if j > 0:
					neighbours[1] = voxels[i][j-1][k]
				if k > 0:
					neighbours[2] = voxels[i][j][k-1]
				voxels[i][j][k].set_neighbours(neighbours)
				processed += 1
	
	print("Set neighbours for ", processed, " voxels")
	
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
	print("Generating corners")
	for x in _voxels:
		print("Progress: ", (i / _voxels.size()) * 100, " %")
		for y in x:
			for voxel in y:
				voxel.generate_corners()
				j += 1
		i += 1
	
	print("Evaluating corners")
	i = 0.0
	var raycaster := Raycaster.new(get_world())
	var pointcaster := Pointcaster.new(get_world())
	for x in _voxels:
		print("Progress: ", (i / _voxels.size()) * 100, " %")
		for y in x:
			for voxel in y:
				voxel.evaluate_corners(pointcaster, raycaster)
		i += 1
	
	if apply_smoothing:
		
		print("Applying smoothing")
		i = 0.0
		for x in _voxels:
			print("Progress: ", (i / _voxels.size()) * 100, " %")
			for y in x:
				for voxel in y:
					voxel.evaluate_smoothing(raycaster)
			i += 1
		
		for x in _voxels:
			for y in x:
				for voxel in y:
					voxel.apply_smoothing(raycaster)
	
	
	call_deferred("_edges_done")
	
	print("Tested: ", j, " voxels")



func _edges_done() -> void:
	print("Edges done !")
	_thread.wait_to_finish()
	
	print("Generating mesh !")
	_generate_meshes()



func _generate_meshes() -> void:
	var vertices: PoolVector3Array = []
	for x in _voxels:
		for y in x:
			for voxel in y:
				vertices.append_array(voxel.get_corresponding_vertices())
	
	
	var arr_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(ArrayMesh.ARRAY_MAX)
	arrays[ArrayMesh.ARRAY_VERTEX] = vertices
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_markers.mesh = arr_mesh
	
#	var debug_vertices: PoolVector3Array = []
#	# Generating debug points
#	for x in _voxels:
#		for y in x:
#			for voxel in y:
#				for corner in voxel._corners:
#					debug_vertices.append_array(_generate_point(corner.position, corner.state != 2))
#
#	var debug_arr_mesh = ArrayMesh.new()
#	var debug_arrays = []
#	debug_arrays.resize(ArrayMesh.ARRAY_MAX)
#	debug_arrays[ArrayMesh.ARRAY_VERTEX] = debug_vertices
#	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, debug_arrays)
#	_corners.mesh = debug_arr_mesh



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
	var _owned_corners := []
	var _neighbours := []
	
	func _init(center: Vector3, size: float) -> void:
		_center = center
		_size = size
	
	
	
	func get_corners() -> Array:
		return _corners
	
	
	
	func set_neighbours(neighbours: Array) -> void:
		_neighbours = neighbours
	
	
	
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
#		var edges: PoolVector3Array = [
#			(_corners[0].position + _corners[1].position) / 2.0,
#			(_corners[1].position + _corners[2].position) / 2.0,
#			(_corners[2].position + _corners[3].position) / 2.0,
#			(_corners[3].position + _corners[0].position) / 2.0,
#			(_corners[4].position + _corners[5].position) / 2.0,
#			(_corners[5].position + _corners[6].position) / 2.0,
#			(_corners[6].position + _corners[7].position) / 2.0,
#			(_corners[7].position + _corners[4].position) / 2.0,
#			(_corners[0].position + _corners[4].position) / 2.0,
#			(_corners[1].position + _corners[5].position) / 2.0,
#			(_corners[2].position + _corners[6].position) / 2.0,
#			(_corners[3].position + _corners[7].position) / 2.0,
#		]
		
		for index in TriangulationTable.SMC[_get_corners_index()]:
			if index == -1:
				continue
			vertices.append(_corners[index].position)
		
		return vertices
	
	
	
	func get_corner(index: int) -> Corner:
		return _corners[index]
	
	
	
	func generate_corners() -> void:
		var offset := _size / 2.0
		var positions := [
			_center + Vector3(-1, -1, -1) * offset,
			_center + Vector3(-1, -1, +1) * offset,
			_center + Vector3(+1, -1, +1) * offset,
			_center + Vector3(+1, -1, -1) * offset,
			_center + Vector3(-1, +1, -1) * offset,
			_center + Vector3(-1, +1, +1) * offset,
			_center + Vector3(+1, +1, +1) * offset,
			_center + Vector3(+1, +1, -1) * offset,
		]
		
		_corners = [null, null, null, null, null, null, null, null]
		
		if _neighbours[0]:
			_corners[0] = _neighbours[0].get_corner(1)
			_corners[3] = _neighbours[0].get_corner(2)
			_corners[4] = _neighbours[0].get_corner(5)
			_corners[7] = _neighbours[0].get_corner(6)
		
		if _neighbours[1]:
			_corners[0] = _neighbours[1].get_corner(4)
			_corners[1] = _neighbours[1].get_corner(5)
			_corners[2] = _neighbours[1].get_corner(6)
			_corners[3] = _neighbours[1].get_corner(7)
		
		if _neighbours[2]:
			_corners[3] = _neighbours[2].get_corner(0)
			_corners[2] = _neighbours[2].get_corner(1)
			_corners[7] = _neighbours[2].get_corner(4)
			_corners[6] = _neighbours[2].get_corner(5)
		
		for i in range(_corners.size()):
			if not _corners[i]:
				_corners[i] = Corner.new(i, positions[i])
				_owned_corners.append(_corners[i])
		
		_assign_neighbours_to_corners()
	
	
	
	func evaluate_corners(pointcaster: Pointcaster, raycaster: Raycaster) -> void:
		for corner in _corners:
			# If the corner is not inside a mesh, then we check if he is next to a surface
			if not corner.evaluate_inside(pointcaster):
				corner.evaluate_edges(raycaster)
	
	
	
	func evaluate_smoothing(raycaster: Raycaster) -> void:
		for corner in _owned_corners:
			corner.evaluate_intersection(raycaster)
	
	
	
	func apply_smoothing(raycaster: Raycaster) -> void:
		for corner in _owned_corners:
			corner.apply_position_smoothing()
	
	
	
	
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
		_corners[0].set_neighbours([null, null, _corners[1], _corners[3], null, _corners[4]])
		_corners[1].set_neighbours([_corners[0], null, null, _corners[2], null, _corners[5]])
		_corners[2].set_neighbours([_corners[3], _corners[1], null, null, null, _corners[6]])
		_corners[3].set_neighbours([null, _corners[0], _corners[2], null, null, _corners[7]])
		_corners[4].set_neighbours([null, null, _corners[5], _corners[7], _corners[0], null])
		_corners[5].set_neighbours([_corners[4], null, null, _corners[6], _corners[1], null])
		_corners[6].set_neighbours([_corners[7], _corners[5], null, null, _corners[2], null])
		_corners[7].set_neighbours([null, _corners[4], _corners[6], null, _corners[3], null])
	
	
	
	func _get_corners_index() -> int:
		var result := 0
		for i in range(_corners.size()):
			if not _corners[i].is_outside():
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
				corner1: data.collision_length() if data.collides() else -1,
				corner2: data2.collision_length() if data2.collides() else -1
			}
		
		
		func is_cut() -> bool:
			for dist in _corners_cut_dist.values():
				if dist > 0.0:
					return true
			return false
		
		
		
		func is_surface(corner: Corner) -> bool:
			return is_cut()
			if not _corners_cut_dist.has(corner):
				return false
			return _corners_cut_dist[corner] > 0.0
		
		
		
		func get_other(corner: Corner) -> Corner:
			for c in _corners_cut_dist.keys():
				if c != corner:
					return c
			return null
	
	
	
	class Corner:
		enum STATE {SURFACE, INSIDE, OUTSIDE}
		
		var index: int
		var position: Vector3
		var offseted_position: Vector3
		var edges := [null, null, null, null, null, null]
		var neighbours := [null, null, null, null, null, null]
		var state: int = STATE.OUTSIDE
		
		
		func _init(index: int, position: Vector3) -> void:
			self.index = index
			self.position = position
		
		
		
		func set_neighbours(neighbours: Array) -> void:
			for i in range(neighbours.size()):
				if neighbours[i]:
					self.neighbours[i] = neighbours[i]
		
		
		
		func evaluate_inside(caster: Pointcaster) -> bool:
			if caster.is_inside(position):
				state = STATE.INSIDE
				return true
			return false
		
		
		
		func evaluate_edges(caster: Raycaster) -> void:
			var edges_list := [2, 3, 0, 1, 5, 4]
			for i in range(neighbours.size()):
				if not neighbours[i]:
					continue
				if neighbours[i].edges[edges_list[i]]:
					edges[i] = neighbours[i].edges[edges_list[i]]
				else:
					edges[i] = Edge.new(caster, self, neighbours[i])
			
			for edge in edges:
				if not edge:
					continue
				if edge.is_surface(self):
					state = STATE.SURFACE
					return
		
		
		
		func evaluate_intersection(caster: Raycaster) -> void:
			offseted_position = position
			if state != STATE.SURFACE:
				return
			var offset := Vector3.ZERO
			for edge in edges:
				if not edge:
					continue
				if edge.is_cut():
					offset += edge.get_other(self).position - position
			var data := caster.get_collision_data(position, position + offset)
			
			# Forward pass
			if data.collides():
				offseted_position = data.collision_position()
			else:
				# Backward pass
				data = caster.get_collision_data(position + offset, position)
				if data.collides():
					offseted_position = data.collision_position()
		
		
		# Applying the offseted position after all the voxels were processed to prevent
		# cast not colliding for other corners
		func apply_position_smoothing() -> void:
			position = offseted_position
		
		
		
		func is_outside() -> bool:
			return state == STATE.OUTSIDE
		
		
		
		
		
#		func _evaluate_state_first_pass() -> void:
#			for edge in edges:
#				if edge.is_inside(index):
#					state = STATE.INSIDE
#					return
#				if state == STATE.NONE and edge.is_cut():
#					state = STATE.OUTSIDE
#			if state == STATE.NONE:
#				state = STATE.UNKNOWN
#
#
#		func _evaluate_state_second_pass() -> void:
#			if state != STATE.UNKNOWN:
#				return
#			for corner in neighbours:
#				if corner.state != STATE.UNKNOWN:
#					state = corner.state
#					return
