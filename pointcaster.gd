extends Reference
class_name Pointcaster


var _world: World
var _objects_to_ignore: Array
var _collision_mask: int


func _init(world: World, objects_to_ignore: Array = [], collision_mask: int = 0x7FFFFFFF) -> void:
	_world = world
	_objects_to_ignore = objects_to_ignore
	_collision_mask = collision_mask



func is_inside(position: Vector3) -> bool:
	return not _world.direct_space_state.intersect_point(position, 1, _objects_to_ignore, _collision_mask).empty()
