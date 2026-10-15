class_name DotDisasterWindView
extends DotDisasterView

## Streaming particles on the wind (snow, or dust) and a veil over the screen, louder with
## each gust.

var snow: bool = false

var _flakes: CPUParticles3D
var _veil: ColorRect
var _bed: AudioStreamPlayer


func build() -> void:
	var tint := Color(0.95, 0.97, 1.0, 0.9) if snow else Color(0.72, 0.62, 0.45, 0.45)
	_flakes = DotDisasterFx.particles(
		DotDisasterFx.soft_texture(), int(clampf(1100.0 * event.intensity, 300.0, 3600.0)),
		2.2, Vector2(0.18, 0.45) if snow else Vector2(0.25, 0.8), tint
	)
	_flakes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_flakes.emission_box_extents = Vector3(26.0, 10.0, 26.0)
	_flakes.gravity = Vector3(0.0, -1.2 if snow else -0.2, 0.0)
	_flakes.spread = 12.0
	_flakes.angular_velocity_min = -90.0
	_flakes.angular_velocity_max = 90.0
	add_child(_flakes)
	_veil = add_overlay(Color(0.92, 0.95, 1.0, 0.0) if snow else Color(0.6, 0.5, 0.35, 0.0))
	_bed = add_sound("wind_loop", true, -80.0)


func update_view(_delta: float) -> void:
	var at := viewer_position()
	var env := event.envelope()
	var g := DotDisasterWind.gust(event, event.elapsed)
	var here := presence(at) * env
	var dir := event.heading_vector()
	var speed := 10.0 * event.intensity * g
	_flakes.global_position = at - dir * 18.0 + Vector3(0.0, 4.0, 0.0)
	_flakes.direction = dir + Vector3(0.0, -0.05, 0.0)
	_flakes.initial_velocity_min = speed * 1.6
	_flakes.initial_velocity_max = speed * 2.6
	_flakes.emitting = here > 0.02
	_veil.color.a = (0.45 if snow else 0.18) * here * g * clampf(event.intensity, 0.3, 1.5)
	if _bed != null:
		_bed.volume_db = db(here * g * clampf(event.intensity, 0.3, 1.3), -5.0)
