extends ImmediateGeometry
class_name BoxDrawer



func draw_aabb(aabb: AABB, offset: Vector3, color: Color) -> void:
	aabb.position += offset
	clear()
	begin(Mesh.PRIMITIVE_LINES)
	set_color(color)
	set_normal(Vector3(1, 0, 0))

	# Bottom
	add_vertex(to_local(aabb.position))
	add_vertex(to_local(aabb.position + aabb.size * Vector3(1, 0, 0)))

	add_vertex(to_local(aabb.position + aabb.size * Vector3(1, 0, 0)))
	add_vertex(to_local(aabb.position + aabb.size * Vector3(1, 0, 1)))

	add_vertex(to_local(aabb.position + aabb.size * Vector3(1, 0, 1)))
	add_vertex(to_local(aabb.position + aabb.size * Vector3(0, 0, 1)))

	add_vertex(to_local(aabb.position + aabb.size * Vector3(0, 0, 1)))
	add_vertex(to_local(aabb.position))

	# Top
	add_vertex(to_local(aabb.position + aabb.size * Vector3(0, 1, 0)))
	add_vertex(to_local(aabb.position + aabb.size * Vector3(1, 1, 0)))

	add_vertex(to_local(aabb.position + aabb.size * Vector3(1, 1, 0)))
	add_vertex(to_local(aabb.position + aabb.size * Vector3(1, 1, 1)))

	add_vertex(to_local(aabb.position + aabb.size * Vector3(1, 1, 1)))
	add_vertex(to_local(aabb.position + aabb.size * Vector3(0, 1, 1)))

	add_vertex(to_local(aabb.position + aabb.size * Vector3(0, 1, 1)))
	add_vertex(to_local(aabb.position + aabb.size * Vector3(0, 1, 0)))

	# Sides
	add_vertex(to_local(aabb.position))
	add_vertex(to_local(aabb.position + aabb.size * Vector3(0, 1, 0)))

	add_vertex(to_local(aabb.position + aabb.size * Vector3(1, 0, 0)))
	add_vertex(to_local(aabb.position + aabb.size * Vector3(1, 1, 0)))

	add_vertex(to_local(aabb.position + aabb.size * Vector3(0, 0, 1)))
	add_vertex(to_local(aabb.position + aabb.size * Vector3(0, 1, 1)))

	add_vertex(to_local(aabb.position + aabb.size * Vector3(1, 0, 1)))
	add_vertex(to_local(aabb.position + aabb.size * Vector3(1, 1, 1)))
	end()
