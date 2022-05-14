extends Spatial
class_name Voxelizer
tool



export(AABB) var voxelization_box: AABB = AABB(Vector3.ZERO, Vector3.ONE * 10.0) setget set_bounding_box
export(float, 0.1, 100) var voxel_size: float = 1.0
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
	var p := 0.0
	var t := 0
	
	print("Generating corners")
	var pointcaster := Pointcaster.new(get_world())
	var rectcaster := RectCaster.new(get_world(), voxel_size)
	
	for x in _voxels:
		print("Progress: ", (p / _voxels.size()) * 100, " %")
		for y in x:
			for voxel in y:
				voxel.generate_corners(35, pointcaster, rectcaster)
				t += 1
		p += 1
	
	print("Tested: ", t, " voxels")
	print("Parsing neighbours")
	
	var processed := 0
	for i in range(_voxels.size()):
		for j in range(_voxels[i].size()):
			for k in range(_voxels[i][j].size()):
				var neighbours := [null, null, null, null, null, null]
				if i > 0:
					neighbours[0] = _voxels[i-1][j][k]
				if k > 0:
					neighbours[1] = _voxels[i][j][k-1]
				if i < _voxels.size() - 1:
					neighbours[2] = _voxels[i+1][j][k]
				if k < _voxels[i][j].size() - 1:
					neighbours[3] = _voxels[i][j][k+1]
				if j < _voxels[i].size() - 1:
					neighbours[4] = _voxels[i][j+1][k]
				if j > 0:
					neighbours[5] = _voxels[i][j-1][k]
				_voxels[i][j][k].parse_neighbours(neighbours)
				processed += 1
	
	print("Set neighbours for ", processed, " voxels")
#
#	print("Evaluating corners")
#	i = 0.0
#	var raycaster := Raycaster.new(get_world())
#	var pointcaster := Pointcaster.new(get_world())
#	for x in _voxels:
#		print("Progress: ", (i / _voxels.size()) * 100, " %")
#		for y in x:
#			for voxel in y:
#				voxel.evaluate_corners(pointcaster, raycaster)
#		i += 1
#
#	if apply_smoothing:
#
#		print("Applying smoothing")
#		i = 0.0
#		for x in _voxels:
#			print("Progress: ", (i / _voxels.size()) * 100, " %")
#			for y in x:
#				for voxel in y:
#					voxel.evaluate_smoothing(raycaster)
#			i += 1
#
#		for x in _voxels:
#			for y in x:
#				for voxel in y:
#					voxel.apply_smoothing(raycaster)
	
	
	call_deferred("_edges_done")
	



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
	
	vertices.invert()
	
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
	var _faces := []
	var _owned_faces := 0
	var _inside_corners := 0
	var _neighbours := []
	
	func _init(center: Vector3, size: float) -> void:
		_center = center
		_size = size
	
	
	
	func set_neighbours(neighbours: Array) -> void:
		_neighbours = neighbours
	
	
	
	func get_corresponding_vertices() -> PoolVector3Array:
		var offset := _size / 2.0
		var vertices: PoolVector3Array = []
		
		var positions := [
			_center + Vector3(-1, -1, +1) * offset,
			_center + Vector3(-1, -1, -1) * offset,
			_center + Vector3(+1, -1, -1) * offset,
			_center + Vector3(+1, -1, +1) * offset,
			_center + Vector3(-1, +1, +1) * offset,
			_center + Vector3(-1, +1, -1) * offset,
			_center + Vector3(+1, +1, -1) * offset,
			_center + Vector3(+1, +1, +1) * offset,
		]
		
		
		for index in TriangulationTable.SMC[_get_corners_index()]:
			if index == -1:
				continue
			vertices.append(positions[index])
		
		return vertices
	
	
	
	func generate_corners(faces_to_ignore: int, pointcaster: Pointcaster, rectcaster: RectCaster) -> void:
		var offset := _size / 2.0
		var positions := [
			Vector3(-1, 0, 0),
			Vector3(0, 0, -1),
			Vector3(+1, 0, 0),
			Vector3(0, 0, +1),
			Vector3(0, +1, 0),
			Vector3(0, -1, 0)
		]
		
		_faces = [null, null, null, null, null, null]
		
		for i in range(_faces.size()):
			if faces_to_ignore & 1 << i:
				continue
			_faces[i] = Face.new(_center + positions[i] * offset, positions[i], _size, pointcaster, rectcaster)
			_owned_faces |= 1 << i
		
		var face_corners := [51, 102, 204, 153, 240, 15]
		for i in range(_faces.size()):
			if _owned_faces & 1 << i and _faces[i].is_cut():
				_inside_corners |= face_corners[i]
	
	
	
	func get_face(index: int) -> Face:
		return _faces[index]
	
	
	
	func get_corner(index: int) -> int:
		return 1 if _inside_corners & 1 << index != 0 else 0
	
	
	
	func parse_neighbours(neighbours: Array) -> void:
		if neighbours[0]:
#			_faces[0] = neighbours[0].get_face(2)
			_inside_corners |= neighbours[0].get_corner(2) << 1
			_inside_corners |= neighbours[0].get_corner(3) << 0
			_inside_corners |= neighbours[0].get_corner(7) << 4
			_inside_corners |= neighbours[0].get_corner(6) << 5
		
		if neighbours[1]:
#			_faces[1] = neighbours[2].get_face(3)
			_inside_corners |= neighbours[1].get_corner(3) << 2
			_inside_corners |= neighbours[1].get_corner(0) << 1
			_inside_corners |= neighbours[1].get_corner(4) << 5
			_inside_corners |= neighbours[1].get_corner(7) << 6
		
		if neighbours[2]:
#			_faces[2] = neighbours[0].get_face(2)
			_inside_corners |= neighbours[2].get_corner(1) << 2
			_inside_corners |= neighbours[2].get_corner(0) << 3
			_inside_corners |= neighbours[2].get_corner(4) << 7
			_inside_corners |= neighbours[2].get_corner(5) << 6

		if neighbours[3]:
#			_faces[3] = neighbours[1].get_face(4)
			_inside_corners |= neighbours[3].get_corner(2) << 3
			_inside_corners |= neighbours[3].get_corner(1) << 0
			_inside_corners |= neighbours[3].get_corner(5) << 4
			_inside_corners |= neighbours[3].get_corner(6) << 7

		if neighbours[4]:
#			_faces[4] = neighbours[2].get_face(3)
			_inside_corners |= neighbours[4].get_corner(3) << 7
			_inside_corners |= neighbours[4].get_corner(0) << 4
			_inside_corners |= neighbours[4].get_corner(1) << 5
			_inside_corners |= neighbours[4].get_corner(2) << 6
		
		if neighbours[5]:
#			_faces[5] = neighbours[1].get_face(4)
			_inside_corners |= neighbours[5].get_corner(6) << 2
			_inside_corners |= neighbours[5].get_corner(7) << 3
			_inside_corners |= neighbours[5].get_corner(4) << 0
			_inside_corners |= neighbours[5].get_corner(5) << 1
	
	
#	func evaluate_corners(pointcaster: Pointcaster, raycaster: Raycaster) -> void:
#		for corner in _corners:
#			# If the corner is not inside a mesh, then we check if he is next to a surface
#			if not corner.evaluate_inside(pointcaster):
#				corner.evaluate_edges(raycaster)
	
	
	
#	func evaluate_smoothing(raycaster: Raycaster) -> void:
#		for corner in _owned_corners:
#			corner.evaluate_intersection(raycaster)
	
	
	
#	func apply_smoothing(raycaster: Raycaster) -> void:
#		for corner in _owned_corners:
#			corner.apply_position_smoothing()
	
	
	
	
#	func _assign_edges_to_corners() -> void:
#		_corners[0].set_edges([_edges[3], _edges[0], _edges[8]])
#		_corners[1].set_edges([_edges[0], _edges[1], _edges[9]])
#		_corners[2].set_edges([_edges[1], _edges[2], _edges[10]])
#		_corners[3].set_edges([_edges[2], _edges[3], _edges[11]])
#		_corners[4].set_edges([_edges[7], _edges[4], _edges[8]])
#		_corners[5].set_edges([_edges[4], _edges[5], _edges[9]])
#		_corners[6].set_edges([_edges[5], _edges[6], _edges[10]])
#		_corners[7].set_edges([_edges[6], _edges[7], _edges[11]])
	
	
#	func _assign_neighbours_to_corners() -> void:
#		_corners[0].set_neighbours([null, null, _corners[1], _corners[3], null, _corners[4]])
#		_corners[1].set_neighbours([_corners[0], null, null, _corners[2], null, _corners[5]])
#		_corners[2].set_neighbours([_corners[3], _corners[1], null, null, null, _corners[6]])
#		_corners[3].set_neighbours([null, _corners[0], _corners[2], null, null, _corners[7]])
#		_corners[4].set_neighbours([null, null, _corners[5], _corners[7], _corners[0], null])
#		_corners[5].set_neighbours([_corners[4], null, null, _corners[6], _corners[1], null])
#		_corners[6].set_neighbours([_corners[7], _corners[5], null, null, _corners[2], null])
#		_corners[7].set_neighbours([null, _corners[4], _corners[6], null, _corners[3], null])
	
	
	
	func _get_corners_index() -> int:
#		var result := 0
##		for i in range(_corners.size()):
##			if not _corners[i].is_outside():
##				result |= 1 << i
##		return result
#
#		var face_corners := [51, 102, 204, 153, 240, 15]
#
#		for i in range(_faces.size()):
#			if _faces[i].is_cut():
#				result |= face_corners[i]
#		return result
		return _inside_corners
	
	
	
	class Face:
		var _center: Vector3
		var _normal: Vector3
		var _size: float
		var _is_cut := false
		
		func _init(center: Vector3, normal: Vector3, size: float, pointcaster: Pointcaster, rectcaster: RectCaster) -> void:
			_center = center
			_normal = normal
			_size = size
			_is_cut = evaluate_cut(pointcaster, rectcaster)
		
		
		func evaluate_cut(pointcaster: Pointcaster, rectcaster: RectCaster) -> bool:
			if pointcaster.is_inside(_center):
				return true
			if rectcaster.is_cut(_center, _normal):
				return true
			return false
		
		
		func is_cut() -> bool:
			return _is_cut
	
#
#
#	class Edge:
#		var _dist_between_corners: float
#		var _corners_cut_dist: Dictionary
#
#		func _init(raycaster: Raycaster, corner1: Corner, corner2: Corner) -> void:
#			_dist_between_corners = corner1.position.distance_to(corner2.position)
#			var data := raycaster.get_collision_data(corner2.position, corner1.position)
#			var data2 := raycaster.get_collision_data(corner1.position, corner2.position)
#
#			_corners_cut_dist = {
#				corner1: data.collision_length() if data.collides() else -1,
#				corner2: data2.collision_length() if data2.collides() else -1
#			}
#
#
#		func is_cut() -> bool:
#			for dist in _corners_cut_dist.values():
#				if dist > 0.0:
#					return true
#			return false
#
#
#
#		func is_surface(corner: Corner) -> bool:
#			return is_cut()
#			if not _corners_cut_dist.has(corner):
#				return false
#			return _corners_cut_dist[corner] > 0.0
#
#
#
#		func get_other(corner: Corner) -> Corner:
#			for c in _corners_cut_dist.keys():
#				if c != corner:
#					return c
#			return null
#
#
#
#	class Corner:
#		enum STATE {SURFACE, INSIDE, OUTSIDE}
#
#		var index: int
#		var position: Vector3
#		var offseted_position: Vector3
#		var edges := [null, null, null, null, null, null]
#		var neighbours := [null, null, null, null, null, null]
#		var state: int = STATE.OUTSIDE
#
#
#		func _init(index: int, position: Vector3) -> void:
#			self.index = index
#			self.position = position
#
#
#
#		func set_neighbours(neighbours: Array) -> void:
#			for i in range(neighbours.size()):
#				if neighbours[i]:
#					self.neighbours[i] = neighbours[i]
#
#
#
#		func evaluate_inside(caster: Pointcaster) -> bool:
#			if caster.is_inside(position):
#				state = STATE.INSIDE
#				return true
#			return false
#
#
#
#		func evaluate_edges(caster: Raycaster) -> void:
#			var edges_list := [2, 3, 0, 1, 5, 4]
#			for i in range(neighbours.size()):
#				if not neighbours[i]:
#					continue
#				if neighbours[i].edges[edges_list[i]]:
#					edges[i] = neighbours[i].edges[edges_list[i]]
#				else:
#					edges[i] = Edge.new(caster, self, neighbours[i])
#
#			for edge in edges:
#				if not edge:
#					continue
#				if edge.is_surface(self):
#					state = STATE.SURFACE
#					return
#
#
#
#		func evaluate_intersection(caster: Raycaster) -> void:
#			offseted_position = position
#			if state != STATE.SURFACE:
#				return
#			var offset := Vector3.ZERO
#			for edge in edges:
#				if not edge:
#					continue
#				if edge.is_cut():
#					offset += edge.get_other(self).position - position
#			var data := caster.get_collision_data(position, position + offset)
#
#			# Forward pass
#			if data.collides():
#				offseted_position = data.collision_position()
#			else:
#				# Backward pass
#				data = caster.get_collision_data(position + offset, position)
#				if data.collides():
#					offseted_position = data.collision_position()
#
#
#		# Applying the offseted position after all the voxels were processed to prevent
#		# cast not colliding for other corners
#		func apply_position_smoothing() -> void:
#			position = offseted_position
#
#
#
#		func is_outside() -> bool:
#			return state == STATE.OUTSIDE
#
#
#
#
#
##		func _evaluate_state_first_pass() -> void:
##			for edge in edges:
##				if edge.is_inside(index):
##					state = STATE.INSIDE
##					return
##				if state == STATE.NONE and edge.is_cut():
##					state = STATE.OUTSIDE
##			if state == STATE.NONE:
##				state = STATE.UNKNOWN
##
##
##		func _evaluate_state_second_pass() -> void:
##			if state != STATE.UNKNOWN:
##				return
##			for corner in neighbours:
##				if corner.state != STATE.UNKNOWN:
##					state = corner.state
##					return
