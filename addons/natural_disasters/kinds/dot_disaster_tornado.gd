class_name DotDisasterTornado
extends DotDisasterKind

## A funnel that travels, drags rigid bodies in and round and up, shoves players the same
## way, and hurts whatever is at its core.
##
## [b]The path is a function of the record and the time[/b] ([method centre]), so the funnel
## is in the same place on every machine without a position ever being sent: it crosses the
## area on its heading, swaying, and is centred on the origin halfway through. Bodies inside
## `radius` feel an inward pull, a swirl and, near the middle, lift; strength falls off to zero
## at the edge, so there is no wall to be thrown against and a player can always walk out.

const DAMAGE_INTERVAL := 0.5
## Bodies faster than this are left alone; a funnel that keeps accelerating a thing it has
## already thrown only makes it vanish.
const SPEED_CAP := 38.0


func _init() -> void:
	id = &"tornado"
	display_name = "Tornado"


func defaults() -> Dictionary:
	return {"intensity": 1.0, "duration": 75.0, "radius": 60.0, "weight": 2.0}


## Where the funnel's axis is at time [param t], on the ground plane of the event's origin.
static func centre(ev: DotDisasterEvent, t: float) -> Vector3:
	var phase := ev.rng(7).randf() * TAU
	var speed := 3.0 + 2.0 * ev.intensity
	var fwd := ev.heading_vector()
	var side := Vector3(fwd.z, 0.0, -fwd.x)
	return ev.origin + fwd * (speed * (t - ev.duration * 0.5)) + side * (sin(t * 0.22 + phase) * ev.radius * 0.35)


## The funnel's core radius in metres: where it hurts rather than only moves.
static func core_radius(ev: DotDisasterEvent) -> float:
	return 3.0 + 2.0 * ev.intensity


## Velocity the funnel gives air at [param at]: inward, swirling, rising near the axis.
static func flow_at(ev: DotDisasterEvent, at: Vector3) -> Vector3:
	var c := centre(ev, ev.elapsed)
	var flat := Vector3(c.x - at.x, 0.0, c.z - at.z)
	var d := flat.length()
	if d >= ev.radius:
		return Vector3.ZERO
	var f := 1.0 - d / ev.radius
	var inward := flat / maxf(d, 0.01)
	var tangent := Vector3(-inward.z, 0.0, inward.x)
	var lift := (0.4 + f) if d < ev.radius * 0.7 else 0.0
	return (inward * 9.0 + tangent * 14.0 + Vector3.UP * 14.0 * lift) * f * ev.intensity * ev.envelope()


func server_start(ev: DotDisasterEvent, ctx: DotDisasterManager) -> void:
	ctx.state(ev)["hurt_clock"] = 0.0


func server_tick(ev: DotDisasterEvent, delta: float, ctx: DotDisasterManager) -> void:
	var st := ctx.state(ev)
	st["hurt_clock"] = float(st["hurt_clock"]) + delta
	var hurt := float(st["hurt_clock"]) >= DAMAGE_INTERVAL
	if hurt:
		st["hurt_clock"] = 0.0
	var c := centre(ev, ev.elapsed)
	var core := core_radius(ev)
	var dps := float(ctx.value("tornado_damage", 12.0)) * ev.intensity

	for b in ctx.bodies():
		var flow := flow_at(ev, b.global_position)
		if flow == Vector3.ZERO or b.linear_velocity.length() > SPEED_CAP:
			continue
		ctx.impulse_body(b, flow * b.mass * delta, b.global_position)
	for p in ctx.players():
		var flow := flow_at(ev, p.global_position)
		if flow == Vector3.ZERO:
			continue
		# A controller that exposes apply_external_velocity keeps the dose; a bare body only
		# rubber-bands, so the strength cvar is the knob either way.
		var dv := flow * float(ctx.value("tornado_player_strength", 1.0)) * delta
		dv.y *= float(ctx.value("tornado_player_lift", 1.8))
		ctx.push_player(p, dv, ev)
		if hurt and Vector2(p.global_position.x - c.x, p.global_position.z - c.z).length() < core:
			ctx.damage(p, dps * DAMAGE_INTERVAL * ev.envelope(), p.global_position, ev)


func shake_at(ev: DotDisasterEvent, at: Vector3) -> float:
	var d := Vector2(at.x - centre(ev, ev.elapsed).x, at.z - centre(ev, ev.elapsed).z).length()
	return clampf(1.0 - d / (ev.radius * 0.8), 0.0, 1.0) * ev.envelope() * clampf(0.3 * ev.intensity, 0.0, 0.5)


func wind_at(ev: DotDisasterEvent, at: Vector3) -> Vector3:
	return flow_at(ev, at) * Vector3(1.0, 0.0, 1.0)


func make_view(_ev: DotDisasterEvent, _ctx: DotDisasterManager) -> DotDisasterView:
	return DotDisasterTornadoView.new()
