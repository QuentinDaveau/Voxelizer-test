extends Control


func draw_disk(position: Vector3, normal: Vector3, radius: float, color: Color) -> void:
	pass



#func draw_line(start: Vector3, end: Vector3, width: float, color: Color) -> void:
#	pass



func draw_ray(start: Vector3, direction: Vector3, length: float, width: float, color: Color) -> void:
	draw



func draw_sphere(position: Vector3, radius: float, color: Color) -> void:
	draw_circle()
