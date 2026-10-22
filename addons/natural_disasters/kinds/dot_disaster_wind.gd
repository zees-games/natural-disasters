class_name DotDisasterWind
extends DotDisasterKind

## A steady gusting wind that shoves everything one way: `wind` (dust and leaves in the air)
## and `blizzard` (the same wind with driven snow and a white-out) are one class.
##
## Strength is `10 m/s` per unit of intensity, gusting between 30 % and 100 % of that on a
## fixed pair of slow sines seeded by the event, so every machine gusts together and
## [method wind_at] answers the same on all of them. It falls to nothing beyond `radius`.

## Body meta: multiplies the push, a stand-in for drag area (a van catches more than a ball).
const SCALE_META := &"disaster_wind_scale"

## True for the blizzard variant: snow and a white-out rather than dust.
var snow: bool = false


func _init(p_snow: bool = false) -> void:
	snow = p_snow
	id = &"blizzard" if snow else &"wind"
	display_name = "Blizzard" if snow else "Heavy wind"


func defaults() -> Dictionary:
	if snow:
		return {"intensity": 1.0, "duration": 100.0, "radius": 150.0, "weight": 2.0}
	return {"intensity": 1.0, "duration": 60.0, "radius": 150.0, "weight": 2.0}


## Gust factor 0.3..1 at time [param t].
static func gust(ev: DotDisasterEvent, t: float) -> float:
	var r := ev.rng(3)
	var a := r.randf() * TAU
	var b := r.randf() * TAU
	return 0.65 + 0.35 * sin(t * 0.8 + a) * sin(t * 0.27 + b)


func wind_at(ev: DotDisasterEvent, at: Vector3) -> Vector3:
	var d := ev.flat_distance(at)
	if d >= ev.radius:
		return Vector3.ZERO
	var edge := clampf((ev.radius - d) / (ev.radius * 0.25), 0.0, 1.0)
	return ev.heading_vector() * 10.0 * ev.intensity * gust(ev, ev.elapsed) * ev.envelope() * edge


func server_tick(ev: DotDisasterEvent, delta: float, ctx: DotDisasterManager) -> void:
	var gain := float(ctx.value("wind_push", 0.35))
	var cap := float(ctx.value("wind_max_accel", 3.0))
	for b in ctx.bodies():
		var w := wind_at(ev, b.global_position)
		if w == Vector3.ZERO:
			continue
		var accel := push_accel(w, b.linear_velocity, gain * float(b.get_meta(SCALE_META, 1.0)), cap)
		ctx.impulse_body(b, accel * b.mass * delta, b.global_position)
	for p in ctx.players():
		var w := wind_at(ev, p.global_position)
		if w != Vector3.ZERO:
			ctx.push_player(p, w * 0.5 * delta, ev)


## Acceleration the wind gives a body moving at [param v]: a push along the wind that is
## [param gain] per m/s of wind, capped at [param cap] m/s^2, and fading to nothing once the body
## already moves with the wind. It is never a pull toward the wind's velocity, so a body's own
## speed against the wind is not braked beyond that bounded push.
static func push_accel(w: Vector3, v: Vector3, gain: float, cap: float) -> Vector3:
	var speed := w.length()
	if speed < 0.001:
		return Vector3.ZERO
	var dir := w / speed
	var along := Vector3(v.x, 0.0, v.z).dot(dir)
	var room := 1.0 - clampf(along / speed, 0.0, 1.0)
	return dir * minf(speed * gain, cap) * room


func shake_at(_ev: DotDisasterEvent, _at: Vector3) -> float:
	return 0.0


func make_view(_ev: DotDisasterEvent, _ctx: DotDisasterManager) -> DotDisasterView:
	var v := DotDisasterWindView.new()
	v.snow = snow
	return v
