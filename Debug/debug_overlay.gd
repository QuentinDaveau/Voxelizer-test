extends CanvasLayer


func _ready():
	if not InputMap.has_action("toggle_debug"):
		InputMap.add_action("toggle_debug")
		var ev = InputEventKey.new()
		ev.scancode = KEY_F12
		InputMap.action_add_event("toggle_debug", ev)



func _input(event):
	if event.is_action_pressed("toggle_debug"):
		for n in get_children():
			n.visible = not n.visible



#func draw_disk(position: Vector3, normal: Vector3, radius: float, color: Color) -> void:
#	var camera := get_viewport().get_camera()
#	$DebugDraw3D.dra



func draw_line(start: Vector3, end: Vector3, width: float, color: Color) -> void:
	$DebugDraw3D.update()
	yield($DebugDraw3D, "draw")
	var camera := get_viewport().get_camera()
	$DebugDraw3D.draw_line(camera.unproject_position(start), camera.unproject_position(end), color, width, true)



func draw_ray(start: Vector3, direction: Vector3, length: float, width: float, color: Color) -> void:
	color.a = 0.5
	$DebugDraw3D.update()
	yield($DebugDraw3D, "draw")
	var camera := get_viewport().get_camera()
	$DebugDraw3D.draw_line(camera.unproject_position(start), camera.unproject_position(start + direction.normalized() * length), color, width, true)



func draw_sphere(position: Vector3, radius: float, color: Color) -> void:
	color.a = 0.5
	$DebugDraw3D.update()
	yield($DebugDraw3D, "draw")
	var camera := get_viewport().get_camera()
	var center := camera.unproject_position(position)
	$DebugDraw3D.draw_circle(center, center.distance_to(camera.unproject_position(position + (-camera.global_transform.basis.z.cross(Vector3.UP)).normalized() * radius)), color)


