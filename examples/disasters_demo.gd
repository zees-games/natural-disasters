extends Node3D

## A small Kenney Nature Kit clearing with a disaster over it, for looking at.
##
##     godot --path . res://examples/disasters_demo.tscn -- --kind tornado
##     xvfb-run -a godot --path . res://examples/disasters_demo.tscn -- --kind blizzard --shot shot.png
##
## [b]Keys:[/b] 1 thunderstorm, 2 tornado, 3 blizzard, 4 wind, 5 earthquake, 0 stops. `--shot`
## renders one frame once the disaster is in full swing and quits, which is how a view is
## looked at: a headless run gives a null renderer and saves nothing.

const KINDS := ["thunderstorm", "tornado", "blizzard", "wind", "earthquake"]
const MODELS := ["tree_pineTallA", "tree_pineRoundA", "tree_cone", "tree_cone_dark", "rock_largeA", "rock_tallB", "stone_largeB"]

var manager: DotDisasterManager
var camera: Camera3D
var _shot := ""
var _t := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var kind := "tornado"
	for i in args.size():
		if args[i] == "--kind" and i + 1 < args.size():
			kind = args[i + 1]
		elif args[i] == "--shot" and i + 1 < args.size():
			_shot = args[i + 1]
	_build_world()
	manager = DotDisasterManager.new()
	manager.visuals_mode = DotDisasterManager.VisualsMode.ON
	add_child(manager)
	var shake := DotDisasterShake.new()
	camera.add_child(shake)
	shake.manager = manager
	_start(kind)


func _build_world() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.7, 0.85)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.75, 0.85)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	add_child(sun)
	var ground := StaticBody3D.new()
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400.0, 400.0)
	mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.5, 0.3)
	mesh.material_override = mat
	ground.add_child(mesh)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400.0, 1.0, 400.0)
	shape.shape = box
	shape.position.y = -0.5
	ground.add_child(shape)
	add_child(ground)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 60:
		var scene: PackedScene = load("res://assets/kenney/nature/%s.glb" % MODELS[rng.randi() % MODELS.size()])
		if scene == null:
			continue
		var m: Node3D = scene.instantiate()
		m.position = Vector3(rng.randf_range(-50.0, 50.0), 0.0, rng.randf_range(-50.0, 30.0))
		m.rotation.y = rng.randf() * TAU
		m.scale = Vector3.ONE * rng.randf_range(2.5, 4.0)
		add_child(m)
	for i in 25:
		var b := RigidBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(1.0, 1.0, 1.0)
		cs.shape = bs
		b.add_child(cs)
		var bm := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bm.mesh = bx
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = Color.from_hsv(rng.randf(), 0.5, 0.9)
		bm.material_override = bmat
		b.add_child(bm)
		b.position = Vector3(rng.randf_range(-20.0, 20.0), 0.6, rng.randf_range(-15.0, 15.0))
		add_child(b)
	camera = Camera3D.new()
	camera.position = Vector3(0.0, 4.0, 22.0)
	camera.rotation_degrees = Vector3(-6.0, 0.0, 0.0)
	camera.far = 400.0
	add_child(camera)
	camera.make_current()


func _start(kind: String) -> void:
	manager.stop()
	var res := manager.start(StringName(kind), {"origin": Vector3(0.0, 0.0, -10.0), "duration": 18.0 if kind == "tornado" else 120.0, "seed": 4})
	if not res.ok:
		push_error("disasters_demo: %s" % res.error.message)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var i: int = event.keycode - KEY_1
		if i >= 0 and i < KINDS.size():
			_start(KINDS[i])
		elif event.keycode == KEY_0:
			manager.stop()


func _process(delta: float) -> void:
	_t += delta
	if _shot != "" and _t > 9.0:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_shot)
		get_tree().quit()
