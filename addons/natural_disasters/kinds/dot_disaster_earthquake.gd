class_name DotDisasterEarthquake
extends DotDisasterKind

## The ground moves: loose bodies are kicked about, players stumble, cameras shake, and the
## dust comes up. Strongest at the epicentre, nothing past `radius`.
##
## Bodies are kicked in short pulses rather than every frame: a quake is a series of jolts,
## and a constant tiny force just makes a body hum in place. Pulse times and directions come
## from the authority's own random stream; only their effect (physics) and the shake, a pure
## function of the record, are felt elsewhere.

const PULSE_INTERVAL := 0.14


func _init() -> void:
	id = &"earthquake"
	display_name = "Earthquake"


func defaults() -> Dictionary:
	return {"intensity": 1.0, "duration": 18.0, "radius": 90.0, "weight": 1.5}


func server_start(ev: DotDisasterEvent, ctx: DotDisasterManager) -> void:
	var st := ctx.state(ev)
	st["clock"] = 0.0
	st["rng"] = ev.rng(5)


func server_tick(ev: DotDisasterEvent, delta: float, ctx: DotDisasterManager) -> void:
	var st := ctx.state(ev)
	st["clock"] = float(st["clock"]) + delta
	if float(st["clock"]) < PULSE_INTERVAL:
		return
	st["clock"] = 0.0
	var rng: RandomNumberGenerator = st["rng"]
	var env := ev.envelope()
	for b in ctx.bodies():
		var f := _falloff(ev, b.global_position)
		if f <= 0.0:
			continue
		var kick := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.3, 1.0), rng.randf_range(-1.0, 1.0))
		ctx.impulse_body(b, kick * b.mass * 3.2 * ev.intensity * f * env, b.global_position)
	for p in ctx.players():
		var f := _falloff(ev, p.global_position)
		if f > 0.0:
			var stumble := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))
			ctx.push_player(p, stumble * 1.1 * ev.intensity * f * env, ev)


## 0..1 by distance from the epicentre, squared so the edge is gentle.
func _falloff(ev: DotDisasterEvent, at: Vector3) -> float:
	var f := clampf(1.0 - ev.flat_distance(at) / ev.radius, 0.0, 1.0)
	return f * f


func shake_at(ev: DotDisasterEvent, at: Vector3) -> float:
	var f := clampf(1.0 - ev.flat_distance(at) / (ev.radius * 1.3), 0.0, 1.0)
	var jolt := 0.85 + 0.15 * sin(ev.elapsed * 9.0)
	return clampf((0.25 + 0.4 * ev.intensity) * f * ev.envelope() * jolt, 0.0, 1.0)


func make_view(_ev: DotDisasterEvent, _ctx: DotDisasterManager) -> DotDisasterView:
	return DotDisasterQuakeView.new()
