class_name DotDisasterTornadoView
extends DotDisasterView

## The funnel: stacked translucent rings that widen with height and turn at different rates,
## debris spiralling in it, and dust at the foot. Its roar is louder the closer the viewer.

const RINGS := 9

var _funnel: Node3D
var _ring_nodes: Array[MeshInstance3D] = []
var _debris: CPUParticles3D
var _dust: CPUParticles3D
var _roar: AudioStreamPlayer
var _height: float = 60.0


func build() -> void:
	_height = 45.0 + 15.0 * clampf(event.intensity, 0.5, 2.0)
	_funnel = Node3D.new()
	add_child(_funnel)
	var stripes := Gradient.new()
	stripes.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	stripes.offsets = PackedFloat32Array([0.0, 0.18, 0.31, 0.5, 0.68, 0.84])
	stripes.colors = PackedColorArray([
		Color(0.36, 0.34, 0.33, 0.7), Color(0.55, 0.52, 0.5, 0.35), Color(0.3, 0.28, 0.28, 0.75),
		Color(0.5, 0.48, 0.46, 0.3), Color(0.33, 0.31, 0.3, 0.7), Color(0.58, 0.55, 0.52, 0.4),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = stripes
	tex.width = 64
	tex.height = 4
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(1, 0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = tex
	mat.albedo_color = Color(1, 1, 1, 0.8)
	mat.uv1_scale = Vector3(3, 1, 1)
	for i in RINGS:
		var h := _height / RINGS
		var cyl := CylinderMesh.new()
		cyl.height = h * 1.02
		cyl.rings = 1
		cyl.radial_segments = 16
		cyl.bottom_radius = _profile(float(i) / RINGS)
		cyl.top_radius = _profile(float(i + 1) / RINGS)
		cyl.material = mat
		var m := MeshInstance3D.new()
		m.mesh = cyl
		m.position.y = h * (i + 0.5)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_funnel.add_child(m)
		_ring_nodes.append(m)

	_debris = DotDisasterFx.particles(DotDisasterFx.soft_texture(), 160, 2.4, Vector2(0.4, 1.4), Color(0.25, 0.2, 0.16, 0.85))
	_debris.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_debris.emission_sphere_radius = _profile(0.5)
	_debris.gravity = Vector3.ZERO
	_debris.initial_velocity_min = 2.0
	_debris.initial_velocity_max = 6.0
	_debris.direction = Vector3.UP
	_debris.spread = 40.0
	_debris.orbit_velocity_min = 0.6
	_debris.orbit_velocity_max = 1.2
	_debris.local_coords = true
	_funnel.add_child(_debris)
	_debris.position.y = _height * 0.35

	_dust = DotDisasterFx.particles(DotDisasterFx.soft_texture(), 90, 3.0, Vector2(4.0, 9.0), Color(0.5, 0.44, 0.36, 0.45))
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_dust.emission_sphere_radius = core_scale()
	_dust.gravity = Vector3(0.0, 1.0, 0.0)
	_dust.direction = Vector3.UP
	_dust.initial_velocity_min = 3.0
	_dust.initial_velocity_max = 9.0
	_dust.spread = 80.0
	_dust.local_coords = true
	_funnel.add_child(_dust)
	_roar = add_sound("tornado_loop", true, -80.0)


func core_scale() -> float:
	return DotDisasterTornado.core_radius(event) * 1.4


## Radius of the funnel at a fraction of its height: thin at the ground, flaring above.
func _profile(t: float) -> float:
	return 1.4 + (DotDisasterTornado.core_radius(event) * 2.6 - 1.4) * pow(t, 1.7)


func update_view(delta: float) -> void:
	var c := DotDisasterTornado.centre(event, event.elapsed)
	var env := event.envelope()
	_funnel.global_position = Vector3(c.x, event.origin.y, c.z)
	_funnel.scale = Vector3(1.0, 1.0, 1.0) * (0.15 + 0.85 * env)
	_funnel.visible = env > 0.01
	for i in _ring_nodes.size():
		_ring_nodes[i].rotate_y(delta * (1.6 + 0.35 * i) * clampf(event.intensity, 0.5, 2.0))
		_ring_nodes[i].position.x = sin(_age * 0.9 + i * 0.55) * 0.35 * i
		_ring_nodes[i].position.z = cos(_age * 0.7 + i * 0.5) * 0.35 * i
	_debris.emitting = env > 0.05
	_dust.emitting = env > 0.05
	if _roar != null:
		var d := Vector2(viewer_position().x - c.x, viewer_position().z - c.z).length()
		_roar.volume_db = db(clampf(1.0 - d / (event.radius * 2.5), 0.0, 1.0) * env, -3.0)
