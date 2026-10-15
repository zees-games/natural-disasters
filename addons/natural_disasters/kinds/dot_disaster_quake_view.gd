class_name DotDisasterQuakeView
extends DotDisasterView

## Dust lifting off the ground around the viewer and a low rumble. The camera shake is not
## here: it comes from [method DotDisasterManager.shake_at] through a [DotDisasterShake].

var _dust: CPUParticles3D
var _rumble: AudioStreamPlayer


func build() -> void:
	_dust = DotDisasterFx.particles(DotDisasterFx.soft_texture(), 120, 3.5, Vector2(2.5, 6.0), Color(0.55, 0.48, 0.4, 0.4))
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(22.0, 0.3, 22.0)
	_dust.direction = Vector3.UP
	_dust.spread = 25.0
	_dust.gravity = Vector3(0.0, 0.2, 0.0)
	_dust.initial_velocity_min = 0.5
	_dust.initial_velocity_max = 2.0
	add_child(_dust)
	_rumble = add_sound("quake_rumble", true, -80.0)


func update_view(_delta: float) -> void:
	var at := viewer_position()
	var here := clampf(1.0 - event.flat_distance(at) / (event.radius * 1.3), 0.0, 1.0) * event.envelope()
	_dust.global_position = Vector3(at.x, event.origin.y, at.z)
	_dust.emitting = here > 0.05
	_dust.color.a = 0.4 * here
	if _rumble != null:
		_rumble.volume_db = db(here * clampf(0.5 * event.intensity + 0.3, 0.3, 1.0), -2.0)
