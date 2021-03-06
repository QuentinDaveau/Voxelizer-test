extends Reference
class_name Raycaster


var _world: World
var _objects_to_ignore: Array
var _collision_mask: int


func _init(world: World, objects_to_ignore: Array = [], collision_mask: int = 0x7FFFFFFF) -> void:
	_world = world
	_objects_to_ignore = objects_to_ignore
	_collision_mask = collision_mask



func collides(from: Vector3, to: Vector3) -> bool:
	return get_collision_data(from, to).collides()



func get_collision_data(from: Vector3, to: Vector3) -> CollisionData:
	return CollisionData.new(from, to, _world.direct_space_state.intersect_ray(from, to, _objects_to_ignore, _collision_mask))



class CollisionData:
	
	var _collision_dict: Dictionary
	var _from: Vector3
	var _to: Vector3
	
	
	func _init(from: Vector3, to: Vector3, collision_dict: Dictionary) -> void:
		_collision_dict = collision_dict
		_from = from
		_to = to
	
	
	func collides() -> bool:
		return not _collision_dict.empty()
	
	
	func collision_position() -> Vector3:
		return _collision_dict.get("position", Vector3.ZERO)
	
	
	func collision_normal() -> Vector3:
		return _collision_dict.get("normal", Vector3.ZERO)
	
	
	func collision_length() -> float:
		if not collides():
			return INF
		return _from.distance_to(collision_position())
