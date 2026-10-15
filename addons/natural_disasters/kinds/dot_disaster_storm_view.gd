class_name DotDisasterStormView
extends DotDisasterView

## Rain around the viewer, a darkened screen, a flash and a bolt per strike, thunder late by
## the distance.

const RAIN_BOX := 48.0
const RAIN_HEIGHT := 22.0

var _rain: CPUParticles3D
var _dim: ColorRect
var _flash: ColorRect
var _flash_level: float = 0.0
var _bolts: Array = []
var _thunder: Array = []
var _bed: AudioStreamPlayer


func build() -> void:
	_rain = DotDisasterFx.particles(
		DotDisasterFx.streak_texture(), int(clampf(900.0 * event.intensity, 300.0, 3200.0)), 0.9,
		Vector2(1.0, 1.0), Color(0.8, 0.86, 1.0, 0.8), BaseMaterial3D.BILLBOARD_FIXED_Y
	)
	(_rain.mesh as QuadMesh).size = Vector2(0.07, 1.8)
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(RAIN_BOX, 0.5, RAIN_BOX)
	_rain.direction = Vector3(0.12, -1.0, 0.0)
	_rain.spread = 3.0
	_rain.gravity = Vector3(0.0, -9.8, 0.0)
	_rain.initial_velocity_min = 22.0
	_rain.initial_velocity_max = 28.0
	add_child(_rain)
	_dim = add_overlay(Color(0.04, 0.06, 0.12, 0.0))
	_flash = add_overlay(Color(0.9, 0.95, 1.0, 0.0))
	_bed = add_sound("rain_loop", true, -80.0)


func update_view(delta: float) -> void:
	var at := viewer_position()
	var here := presence(at) * event.envelope()
	_rain.global_position = at + Vector3(0.0, RAIN_HEIGHT, 0.0)
	_rain.emitting = here > 0.02
	_rain.color = Color(0.8, 0.86, 1.0, 0.8 * here)
	_dim.color.a = 0.32 * here * clampf(event.intensity, 0.3, 1.5)
	_flash_level = maxf(_flash_level - delta * 3.5, 0.0)
	_flash.color.a = _flash_level
	if _bed != null:
		_bed.volume_db = db(here * clampf(event.intensity, 0.3, 1.2), -8.0)

	for i in range(_bolts.size() - 1, -1, -1):
		var bolt: Node3D = _bolts[i][0]
		_bolts[i][1] -= delta
		if _bolts[i][1] <= 0.0 or not is_instance_valid(bolt):
			if is_instance_valid(bolt):
				bolt.queue_free()
			_bolts.remove_at(i)
		else:
			bolt.visible = fmod(_bolts[i][1], 0.1) > 0.03
	for i in range(_thunder.size() - 1, -1, -1):
		_thunder[i][0] -= delta
		if _thunder[i][0] <= 0.0:
			var player: AudioStreamPlayer = _thunder[i][1]
			if is_instance_valid(player):
				player.play()
			_thunder.remove_at(i)


## Draws a bolt to [param at] and schedules its thunder.
func show_strike(at: Vector3, bolt_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = bolt_seed
	var root := Node3D.new()
	add_child(root)
	root.global_position = Vector3.ZERO
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.92, 0.95, 1.0)
	var points: Array[Vector3] = [at]
	var segments := 9
	for i in range(1, segments + 1):
		var t := float(i) / segments
		var jitter := (1.0 - t * 0.3) * 4.5 * sin(PI * t * 0.5 + 0.3)
		points.append(at + Vector3(rng.randf_range(-jitter, jitter), 70.0 * t, rng.randf_range(-jitter, jitter)))
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.1
		cyl.bottom_radius = 0.1
		cyl.height = a.distance_to(b)
		cyl.radial_segments = 5
		cyl.rings = 1
		cyl.material = mat
		var m := MeshInstance3D.new()
		m.mesh = cyl
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(m)
		m.global_position = (a + b) * 0.5
		var up := (b - a).normalized()
		var axis := Vector3.UP.cross(up)
		if axis.length() > 0.001:
			m.global_basis = Basis(axis.normalized(), Vector3.UP.angle_to(up))
	_bolts.append([root, 0.3])
	var d := viewer_position().distance_to(at)
	_flash_level = maxf(_flash_level, clampf(1.0 - d / 260.0, 0.0, 1.0) * 0.8)
	var sound_name: String = DotDisasterStormView._thunder_name(bolt_seed)
	var player := add_sound(sound_name, false, db(clampf(1.0 - d / 400.0, 0.1, 1.0), -2.0), false)
	if player != null:
		_thunder.append([minf(d / DotDisasterThunderstorm.SOUND_SPEED, DotDisasterThunderstorm.MAX_THUNDER_DELAY), player])


static func _thunder_name(bolt_seed: int) -> String:
	return DotDisasterThunderstorm.SOUNDS[absi(bolt_seed) % DotDisasterThunderstorm.SOUNDS.size()]


## How many bolts are on screen, for a suite.
func bolt_count() -> int:
	return _bolts.size()
