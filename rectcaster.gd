extends Reference
class_name RectCaster


var _world: World
var _shape_parameters: PhysicsShapeQueryParameters
var _rect_shape: BoxShape


func _init(world: World, rect_size: float, objects_to_ignore: Array = [], collision_mask: int = 0x7FFFFFFF) -> void:
	_world = world
	
	_rect_shape = BoxShape.new()
	_rect_shape.extents = Vector3(0.01, rect_size / 2.0, rect_size / 2.0)
	
	_shape_parameters = PhysicsShapeQueryParameters.new()
	_shape_parameters.exclude = objects_to_ignore
	_shape_parameters.collision_mask = collision_mask
	_shape_parameters.set_shape(_rect_shape)



func is_cut(position: Vector3, normal: Vector3) -> bool:
	normal = normal.normalized()
	_shape_parameters.transform = Transform(Basis(Vector3.RIGHT.cross(normal) if normal != Vector3.RIGHT and normal != Vector3.LEFT else normal, Vector3.RIGHT.angle_to(normal)), position)
	return not _world.direct_space_state.intersect_shape(_shape_parameters).empty()
