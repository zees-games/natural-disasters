class_name DotDisasterThunderstorm
extends DotDisasterKind

## Rain, and lightning that comes down somewhere and hurts what is there.
##
## The authority draws the strikes (where one lands depends on what is under it, so no client
## can derive it) and sends each as one small message; every machine then draws the same bolt
## and hears the thunder late by the distance, as the weather does. About half the bolts are
## aimed at a player or a body inside the area, so a storm is a threat to somebody standing in
## it and not only to the ground.

## Strikes per second at intensity 1 and full strength.
const STRIKE_RATE := 0.22
const AIMED_SHARE := 0.5
const BLAST_RADIUS := 6.0
const HIT_RADIUS := 2.5
const SOUND_SPEED := 343.0
const MAX_THUNDER_DELAY := 4.0
const SOUNDS := ["thunder_1", "thunder_2", "thunder_3"]


func _init() -> void:
	id = &"thunderstorm"
	display_name = "Thunderstorm"


func defaults() -> Dictionary:
	return {"intensity": 1.0, "duration": 90.0, "radius": 120.0, "weight": 3.0}


func server_start(ev: DotDisasterEvent, ctx: DotDisasterManager) -> void:
	var st := ctx.state(ev)
	st["charge"] = 0.35
	st["rng"] = ev.rng(11)


func server_tick(ev: DotDisasterEvent, delta: float, ctx: DotDisasterManager) -> void:
	var st := ctx.state(ev)
	st["charge"] = float(st["charge"]) + STRIKE_RATE * ev.intensity * ev.envelope() * delta
	while float(st["charge"]) >= 1.0:
		st["charge"] = float(st["charge"]) - 1.0
		strike(ev, ctx)


## Brings one bolt down now and returns where. Public so a game can call lightning on cue:
## [param aim] is a Vector3 to strike at (the bolt finds the ground under it), or null to
## draw a point as the storm would.
func strike(ev: DotDisasterEvent, ctx: DotDisasterManager, aim_at: Variant = null) -> Vector3:
	var st := ctx.state(ev)
	var rng: RandomNumberGenerator = st.get("rng", ev.rng(11))
	var aim: Vector3 = aim_at if aim_at is Vector3 else _aim_point(ev, ctx, rng)
	var hit := ctx.raycast(aim + Vector3.UP * 80.0, aim + Vector3.DOWN * 60.0)
	var at: Vector3 = hit["position"] if hit.has("position") else Vector3(aim.x, ev.origin.y, aim.z)
	var collider: Object = hit.get("collider", null)

	var amount := float(ctx.value("lightning_damage", 30.0)) * ev.intensity
	ctx.damage(collider, amount, at, ev)
	for p in ctx.players():
		var d := p.global_position.distance_to(at)
		if d <= HIT_RADIUS and p != collider:
			ctx.damage(p, amount * (1.0 - d / (HIT_RADIUS * 1.5)), at, ev)
		if d <= BLAST_RADIUS:
			var away := (p.global_position - at).normalized()
			ctx.push_player(p, (away + Vector3.UP * 0.6) * (7.0 * ev.intensity * (1.0 - d / BLAST_RADIUS)), ev)
	for b in ctx.bodies():
		var db := b.global_position.distance_to(at)
		if db <= BLAST_RADIUS:
			var f := 1.0 - db / BLAST_RADIUS
			var dir := (b.global_position - at + Vector3.UP * 0.5).normalized()
			ctx.impulse_body(b, dir * b.mass * 9.0 * ev.intensity * f, at)
	st["target"] = collider
	ctx.broadcast(ev, {"t": "strike", "p": [at.x, at.y, at.z], "n": rng.randi()})
	st.erase("target")
	return at


func _aim_point(ev: DotDisasterEvent, ctx: DotDisasterManager, rng: RandomNumberGenerator) -> Vector3:
	if rng.randf() < AIMED_SHARE:
		var targets: Array[Node3D] = []
		for p in ctx.players():
			if ev.flat_distance(p.global_position) <= ev.radius:
				targets.append(p)
		for b in ctx.bodies():
			if ev.flat_distance(b.global_position) <= ev.radius:
				targets.append(b)
		if not targets.is_empty():
			var t: Node3D = targets[rng.randi() % targets.size()]
			return t.global_position + Vector3(rng.randf_range(-4.0, 4.0), 0.0, rng.randf_range(-4.0, 4.0))
	var angle := rng.randf() * TAU
	var r := sqrt(rng.randf()) * ev.radius
	return ev.origin + Vector3(cos(angle) * r, 0.0, sin(angle) * r)


func on_message(ev: DotDisasterEvent, msg: Dictionary, ctx: DotDisasterManager) -> void:
	if String(msg.get("t", "")) != "strike":
		return
	var p: Variant = msg.get("p", null)
	if not (p is Array) or (p as Array).size() != 3:
		return
	for v in p:
		if not (v is float or v is int) or not is_finite(float(v)):
			return
	var at := Vector3(float(p[0]), float(p[1]), float(p[2]))
	ctx.add_shake_pulse(at, 0.5 * clampf(ev.intensity, 0.3, 1.5))
	var view := ctx.view_of(ev)
	if view is DotDisasterStormView:
		(view as DotDisasterStormView).show_strike(at, int(msg.get("n", 0)))
	ctx.lightning_struck.emit(at, ctx.state(ev).get("target", null))


func make_view(_ev: DotDisasterEvent, _ctx: DotDisasterManager) -> DotDisasterView:
	return DotDisasterStormView.new()
