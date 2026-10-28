extends Node3D

var player: CharacterBody3D
var guard: Node3D
var camera: Camera3D
var pivot: Node3D
var hud: Label
var prompt: Label
var data_taken := false
var finished := false
var suspicion := 0.0
var elapsed := 0.0
var yaw := 0.0
var pitch := -0.25
var server := Vector3(0, 1, -23)
var exit_point := Vector3(11, 0, 10)
var guard_direction := Vector3.FORWARD

func material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m

func box_at(pos: Vector3, size: Vector3, color: Color, solid := true) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material(color)
	mesh.position = pos
	add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var cube := BoxShape3D.new()
		cube.size = size
		collision.shape = cube
		body.add_child(collision)
		mesh.add_child(body)
	return mesh

func caption(pos: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.font_size = 42
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("101b30")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("9db3d4")
	environment.ambient_light_energy = 0.65
	world.environment = environment
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-55, -30, 0)
	moon.light_color = Color("adc9ff")
	moon.light_energy = 0.8
	add_child(moon)
	box_at(Vector3(0, -0.5, -9), Vector3(18, 1, 38), Color("354152"))
	box_at(Vector3(11, -0.5, 10), Vector3(8, 1, 10), Color("5b5145"))
	# Low parapets and equipment provide real collision and line-of-sight cover.
	for x in [-9.0, 9.0]:
		box_at(Vector3(x, 0.6, -11), Vector3(0.4, 1.2, 34), Color("647080"))
	for pos in [Vector3(-3, 1, -4), Vector3(3, 1, -11), Vector3(-3, 1, -17)]:
		box_at(pos, Vector3(3.5, 2, 2.5), Color("4b6269"))
	box_at(Vector3(0, 1.5, -26), Vector3(18, 3, 0.5), Color("303b4a"))
	box_at(server, Vector3(1.3, 2, 1), Color("17252d"))
	box_at(server + Vector3(0, 0.3, 0.52), Vector3(0.8, 0.5, 0.04), Color("3ce0cf"), false)
	caption(server + Vector3(0, 2, 0), "СЕРВЕРНАЯ / E")
	caption(exit_point + Vector3(0, 2, 0), "ЭВАКУАЦИЯ")
	box_at(exit_point, Vector3(2, 0.08, 2), Color("d5a74f"), false)
	for i in range(24):
		var x := float(i % 2) * 60 - 30
		var z := float(i / 2) * 9 - 60
		box_at(Vector3(x, -12, z), Vector3(12, 12 + i % 5 * 3, 7), Color("1e293c"), false)
	player = CharacterBody3D.new()
	player.position = Vector3(0, 1, 6)
	add_child(player)
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	collider.shape = capsule
	collider.position.y = 0.9
	player.add_child(collider)
	var avatar := MeshInstance3D.new()
	var visual := CapsuleMesh.new()
	visual.radius = 0.35
	visual.height = 1.8
	avatar.mesh = visual
	avatar.position.y = 0.9
	avatar.material_override = material(Color("b2b9c4"))
	player.add_child(avatar)
	pivot = Node3D.new()
	add_child(pivot)
	camera = Camera3D.new()
	camera.position = Vector3(0, 2.2, 5)
	pivot.add_child(camera)
	camera.current = true
	guard = Node3D.new()
	add_child(guard)
	var guard_mesh := MeshInstance3D.new()
	guard_mesh.mesh = visual
	guard_mesh.position.y = 0.9
	guard_mesh.material_override = material(Color("b34248"))
	guard.add_child(guard_mesh)
	var beam := SpotLight3D.new()
	beam.position.y = 1.4
	beam.spot_range = 13
	beam.spot_angle = 35
	beam.light_color = Color("ffe3aa")
	beam.light_energy = 3
	guard.add_child(beam)
	var ui := CanvasLayer.new()
	add_child(ui)
	hud = Label.new()
	hud.position = Vector2(24, 20)
	hud.add_theme_font_size_override("font_size", 22)
	ui.add_child(hud)
	prompt = Label.new()
	prompt.position = Vector2(24, 560)
	prompt.add_theme_font_size_override("font_size", 20)
	ui.add_child(prompt)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.003
		pitch = clampf(pitch - event.relative.y * 0.003, -0.7, 0.25)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if event.keycode == KEY_R:
			get_tree().reload_current_scene()
		if event.keycode == KEY_E and not finished and player.position.distance_to(server) < 2.7:
			data_taken = true
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if finished:
		return
	elapsed += delta
	var crouch := Input.is_physical_key_pressed(KEY_CTRL)
	var speed := 2.0 if crouch else (7.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 4.0)
	var direction := Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), 0, float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	direction = direction.rotated(Vector3.UP, yaw).normalized()
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	player.velocity.y -= 22 * delta
	if player.is_on_floor() and Input.is_physical_key_pressed(KEY_SPACE):
		player.velocity.y = 7
	player.move_and_slide()
	pivot.position = player.position + Vector3(0, 1, 0)
	pivot.rotation = Vector3(pitch, yaw, 0)
	guard.position = Vector3(sin(elapsed * 0.4) * 6, 0, -12)
	guard_direction = Vector3(1 if cos(elapsed * 0.4) > 0 else -1, 0, 0)
	guard.look_at(guard.position + guard_direction)
	var offset := player.position - guard.position
	var distance := offset.length()
	var seen := false
	if distance < (7.0 if crouch else 12.0) and offset.normalized().dot(guard_direction) > 0.45:
		var ray := PhysicsRayQueryParameters3D.create(guard.position + Vector3(0, 1.5, 0), player.position + Vector3(0, 0.9, 0))
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		seen = not hit.is_empty() and hit.collider == player
	suspicion = clampf(suspicion + delta * (0.65 if seen else -0.3), 0, 1)
	hud.text = "ПОСЛЕДНЯЯ СТАВКА · Прототип\n" + ("Данные получены. Уходите на соседнюю стройку!" if data_taken else "Проникните к серверу на дальнем конце крыши") + "\nПодозрение: %d%%" % int(suspicion * 100)
	prompt.text = "WASD — движение · Мышь — камера · Shift — бег · Ctrl — скрытность\nПробел — прыжок · E — забрать данные · R — заново · Esc — курсор\nНапарник: «Используй вентиляционные блоки как укрытия. Не попадай в луч.»"
	if player.position.distance_to(server) < 2.7 and not data_taken:
		prompt.text = "Нажмите E, чтобы скопировать компромат"
	if suspicion >= 1 or player.position.y < -8:
		finished = true
		hud.text = "ОПЕРАЦИЯ ПРОВАЛЕНА\n" + ("Охранник обнаружил вас." if suspicion >= 1 else "Вы сорвались с крыши.") + "\nR — повторить"
	if data_taken and player.position.distance_to(exit_point) < 2:
		finished = true
		hud.text = "МИССИЯ ВЫПОЛНЕНА\nКомпромат у команды. Но кто предупредил охрану?\nВремя: %d сек. · R — повторить" % int(elapsed)
