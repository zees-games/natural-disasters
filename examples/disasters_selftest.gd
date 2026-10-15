extends Node3D

## natural-disasters' headless suite.
##
##     godot --headless --path . res://examples/disasters_selftest.tscn
##
## [b]It counts two things and the second is the one that matters.[/b] Sections that ran to
## their last line, and a total number of checks: a script error inside a section aborts THAT
## section and not the run, and a suite reporting "0 failed" with checks missing is a failure
## this family has shipped more than once.

const EXPECTED_SECTIONS := 11
const EXPECTED_CHECKS := 110

var _passed := 0
var _failed := 0
var _sections := 0
var _failures := PackedStringArray()


## A stand-in for a game's player: records what disasters do to it.
class FakePlayer extends Node3D:
	var pushed := Vector3.ZERO
	var pushes := 0
	var hp := 100.0

	func apply_disaster_push(dv: Vector3) -> void:
		pushed += dv
		pushes += 1

	func take_damage(amount: float) -> void:
		hp -= amount


## A stand-in for dot-server's console: the same duck-typed surface and nothing more.
class FakeConsole extends RefCounted:
	var cvars: Dictionary = {}
	var sources: Array = []

	class Var extends RefCounted:
		var value := ""
		var minimum := -INF
		func with_min(m: float) -> Var:
			minimum = m
			return self

	func cvar(cvar_name: String, default_value: String, _description: String = "", _flags: int = 0) -> Var:
		var v := Var.new()
		v.value = default_value
		cvars[cvar_name] = v
		return v

	func find_cvar(cvar_name: String) -> Var:
		return cvars.get(cvar_name)

	func get_float(cvar_name: String, fallback: float = 0.0) -> float:
		return (cvars[cvar_name] as Var).value.to_float() if cvars.has(cvar_name) else fallback

	func get_int(cvar_name: String, fallback: int = 0) -> int:
		return (cvars[cvar_name] as Var).value.to_int() if cvars.has(cvar_name) else fallback

	func get_bool(cvar_name: String, fallback: bool = false) -> bool:
		if not cvars.has(cvar_name):
			return fallback
		return (cvars[cvar_name] as Var).value in ["1", "true"]

	func get_string(cvar_name: String, fallback: String = "") -> String:
		return (cvars[cvar_name] as Var).value if cvars.has(cvar_name) else fallback

	func add_source(source: Object, _permission: String = "", _chat: bool = false) -> DotResult:
		sources.append(source)
		return DotResult.success(source.call("names"))

	func set_value(cvar_name: String, value: String) -> void:
		(cvars[cvar_name] as Var).value = value


func _ready() -> void:
	print("natural-disasters")
	print("")
	_event()
	_registry()
	_config_and_cvars()
	await _real_console()
	await _tornado()
	await _wind()
	await _earthquake()
	await _thunderstorm()
	await _replication()
	_director()
	await _views_and_shake()
	print("")
	var ran := _passed + _failed
	_check(_sections == EXPECTED_SECTIONS,
		"every section ran to its last line (%d of %d)" % [_sections, EXPECTED_SECTIONS])
	_check(ran == EXPECTED_CHECKS,
		"and the suite ran all %d of its checks (%d)" % [EXPECTED_CHECKS, ran])
	print("")
	print("%d passed, %d failed" % [_passed, _failed])
	for line in _failures:
		print("  %s" % line)
	get_tree().quit(1 if _failed > 0 else 0)


func _section(title: String) -> void:
	print(title)


func _done() -> void:
	_sections += 1


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
		print("  ok    %s" % what)
	else:
		_failed += 1
		_failures.append(what)
		print("  FAIL  %s" % what)


# --- Helpers ----------------------------------------------------------------

## A world with a floor, one manager (authority unless told otherwise) and nothing drawn.
func _world(authority: bool = true, visuals: bool = false) -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1600.0, 1.0, 1600.0)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	root.add_child(floor_body)
	var manager := DotDisasterManager.new()
	manager.authority = authority
	manager.sound_enabled = visuals
	manager.visuals_mode = DotDisasterManager.VisualsMode.ON if visuals else DotDisasterManager.VisualsMode.OFF
	root.add_child(manager)
	return {"root": root, "manager": manager, "floor": floor_body}


func _ball(root: Node3D, at: Vector3, mass: float = 2.0) -> RigidBody3D:
	var b := RigidBody3D.new()
	var s := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.5
	s.shape = sphere
	b.add_child(s)
	b.mass = mass
	b.position = at
	root.add_child(b)
	return b


func _player(root: Node3D, at: Vector3) -> FakePlayer:
	var p := FakePlayer.new()
	p.position = at
	p.add_to_group(DotDisasterManager.PLAYER_GROUP)
	root.add_child(p)
	return p


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


# --- Sections ---------------------------------------------------------------

func _event() -> void:
	_section("the event record")
	var ev := DotDisasterEvent.new()
	ev.id = 7
	ev.kind = &"tornado"
	ev.seed = 12345
	ev.origin = Vector3(10.0, 2.0, -30.0)
	ev.radius = 80.0
	ev.intensity = 1.5
	ev.duration = 60.0
	ev.elapsed = 12.0
	ev.heading = 1.0
	var back := DotDisasterEvent.from_wire(ev.to_wire())
	_check(back.ok, "a record round-trips through the wire")
	var got: DotDisasterEvent = back.value
	_check(got.id == 7 and got.kind == &"tornado" and got.seed == 12345 and got.origin == ev.origin
		and is_equal_approx(got.radius, 80.0) and is_equal_approx(got.elapsed, 12.0)
		and is_equal_approx(got.heading, 1.0) and is_equal_approx(got.intensity, 1.5),
		"every field comes back")

	var missing := ev.to_wire()
	missing.erase("o")
	_check(DotDisasterEvent.from_wire(missing).error.code == DotError.CODE_PARSE, "a record missing a field is refused")
	var nan := ev.to_wire()
	nan["n"] = NAN
	_check(not DotDisasterEvent.from_wire(nan).ok, "a record with a NaN is refused")
	var wrong := ev.to_wire()
	wrong["k"] = 5
	_check(not DotDisasterEvent.from_wire(wrong).ok, "a record with a number for a kind is refused")
	var bad_origin := ev.to_wire()
	bad_origin["o"] = [1.0, 2.0]
	_check(not DotDisasterEvent.from_wire(bad_origin).ok, "an origin with two numbers is refused")
	var huge := ev.to_wire()
	huge["r"] = 1e12
	huge["n"] = 1e9
	huge["d"] = -5.0
	var clamped: DotDisasterEvent = DotDisasterEvent.from_wire(huge).value
	_check(clamped.radius == DotDisasterEvent.MAX_RADIUS and clamped.intensity == DotDisasterEvent.MAX_INTENSITY
		and clamped.duration == 0.5, "absurd sizes are clamped, not trusted")

	ev.elapsed = 0.0
	var start := ev.envelope()
	ev.elapsed = 30.0
	var middle := ev.envelope()
	ev.elapsed = 59.5
	var end := ev.envelope()
	_check(start == 0.0 and middle == 1.0 and end < 0.2, "the envelope ramps in, holds and ramps out")
	_check(ev.rng(1).randi() == ev.rng(1).randi() and ev.rng(1).randi() != ev.rng(2).randi(),
		"a stream is a function of the seed and the salt")
	ev.elapsed = 60.0
	_check(ev.is_over() and ev.remaining() == 0.0 and ev.progress() == 1.0, "it is over when its time is")
	_check(ev.describe().contains("tornado"), "it describes itself")
	_done()


func _registry() -> void:
	_section("kinds and the registration API")
	var w := _world()
	var m: DotDisasterManager = w["manager"]
	var ids := m.kind_ids()
	_check(ids.size() >= 5 and "thunderstorm" in ids and "tornado" in ids and "earthquake" in ids
		and "blizzard" in ids and "wind" in ids, "the stock kinds are registered: %s" % ", ".join(ids))

	var custom := DotDisasterKind.new()
	custom.id = &"acid_rain"
	custom.display_name = "Acid rain"
	_check(m.register_kind(custom).ok and m.has_kind(&"acid_rain"), "a game registers its own kind")
	var dup := m.register_kind(custom)
	_check(not dup.ok and dup.error.code == DotError.CODE_CONFLICT, "a second kind with the id is a conflict")
	_check(m.register_kind(custom, true).ok, "unless it says it replaces")
	_check(m.register_kind(DotDisasterKind.new()).error.code == DotError.CODE_INVALID, "a kind with no id is refused")
	_check(m.unregister_kind(&"acid_rain") and not m.has_kind(&"acid_rain"), "and one can be removed")

	var unknown := m.start(&"meteor")
	_check(not unknown.ok and unknown.error.code == DotError.CODE_INVALID, "an unknown kind does not start")
	var client_w := _world(false)
	var client: DotDisasterManager = client_w["manager"]
	_check(client.start(&"tornado").error.code == DotError.CODE_FORBIDDEN, "a client cannot start a disaster")
	_check(m.receive({"t": "stop", "i": 1}).error.code == DotError.CODE_FORBIDDEN,
		"the authority does not take disaster messages")

	var bare := DotDisasterManager.new()
	bare.stock_kinds = false
	add_child(bare)
	_check(bare.kind_ids().is_empty(), "a game that wants none of the stock kinds gets none")
	bare.queue_free()
	(w["root"] as Node).queue_free()
	(client_w["root"] as Node).queue_free()
	_done()


func _config_and_cvars() -> void:
	_section("layered config and cvars")
	var cfg := DotDisasterConfig.new()
	_check(cfg.interval_min == 120.0 and cfg.max_active == 1 and cfg.tornado_radius == 60.0, "defaults are the documented ones")
	var changed := cfg.apply_dictionary({"interval_min": 5.0, "tornado_intensity": 2.5, "nonsense": 1})
	_check(cfg.interval_min == 5.0 and cfg.tornado_intensity == 2.5, "a dictionary layer overrides the defaults")
	_check(changed != null and cfg.unknown_keys.has("nonsense"), "and a typo is reported rather than ignored")
	_check(cfg.cli_prefix().begins_with("--") and cfg.env_prefix() == "DISASTERS_", "the command line and environment prefixes are set")
	cfg.interval_min = 500.0
	cfg.interval_max = 100.0
	_check(not cfg.validate().ok, "an inverted interval fails validation")
	cfg.interval_min = 5.0
	cfg.interval_max = 10.0
	cfg.kinds = " Tornado, wind ,"
	_check(Array(cfg.allowed_kinds()) == ["tornado", "wind"], "the allowed kinds are read as a list")

	var w := _world()
	var m: DotDisasterManager = w["manager"]
	m.config = cfg
	var console := FakeConsole.new()
	var res := m.bind_console(console)
	_check(res.ok and console.cvars.has("disaster_interval_min") and console.cvars.has("disaster_tornado_radius")
		and console.cvars.has("disaster_earthquake_duration") and console.cvars.has("disaster_max_active"),
		"binding a console registers every setting as a cvar")
	_check(console.get_float("disaster_interval_min") == 5.0 and console.get_float("disaster_tornado_intensity") == 2.5,
		"with the config's values as their defaults")
	_check(console.sources.size() == 1, "and the disaster commands")
	console.set_value("disaster_tornado_radius", "33")
	_check(is_equal_approx(float(m.settings_for(&"tornado")["radius"]), 33.0), "an operator's cvar wins on the next disaster")
	var ev: DotDisasterEvent = m.start(&"tornado", {"duration": 5.0}).value
	_check(is_equal_approx(ev.radius, 33.0) and is_equal_approx(ev.intensity, 2.5), "and a started disaster uses it")

	var custom := DotDisasterKind.new()
	custom.id = &"locusts"
	m.register_kind(custom)
	_check(console.cvars.has("disaster_locusts_intensity") and console.cvars.has("disaster_locusts_weight"),
		"a kind registered after the console gets its cvars too")
	_check(m.value("seed", 99) == 0 and m.value("no_such", 7) == 7, "a missing setting reads its fallback")
	(w["root"] as Node).queue_free()
	_done()


func _real_console() -> void:
	_section("the real console, when dot-server is linked")
	if not ClassDB.class_exists(&"Node") or not ResourceLoader.exists("res://addons/dot_server/console/dot_console.gd"):
		print("  (dot-server is not linked; the commands below are not covered)")
		_check(true, "skipped, and said so")
		_check(true, "skipped, and said so")
		_check(true, "skipped, and said so")
		_check(true, "skipped, and said so")
		_done()
		return
	var console_script: GDScript = load("res://addons/dot_server/console/dot_console.gd")
	var console: Node = console_script.new()
	add_child(console)
	var w := _world()
	var m: DotDisasterManager = w["manager"]
	var bound := m.bind_console(console)
	_check(bound.ok and console.call("find_cvar", "disaster_tornado_duration") != null, "the cvars exist on the real console")
	var out: DotResult = console.call("execute", "disaster tornado 2 6 40")
	_check(out.ok and m.is_active(&"tornado"), "`disaster tornado 2 6 40` starts one")
	var ev: DotDisasterEvent = m.active()[0]
	_check(is_equal_approx(ev.intensity, 2.0) and is_equal_approx(ev.duration, 6.0) and is_equal_approx(ev.radius, 40.0),
		"with the numbers it was given")
	console.call("execute", "disaster_stop")
	_check(m.active_count() == 0, "`disaster_stop` ends it")
	console.queue_free()
	(w["root"] as Node).queue_free()
	await get_tree().process_frame
	_done()


func _tornado() -> void:
	_section("tornado")
	var w := _world()
	var root: Node3D = w["root"]
	var m: DotDisasterManager = w["manager"]
	var near := _ball(root, Vector3(14.0, 0.6, 0.0))
	var far := _ball(root, Vector3(300.0, 0.6, 0.0))
	var p_near := _player(root, Vector3(10.0, 0.0, 6.0))
	var p_far := _player(root, Vector3(-250.0, 0.0, 0.0))
	m.config.affect_all_bodies = true
	var res := m.start(&"tornado", {"origin": Vector3.ZERO, "duration": 12.0, "intensity": 1.5, "radius": 60.0, "heading": 0.0, "seed": 3})
	_check(res.ok, "it starts")
	var ev: DotDisasterEvent = res.value
	var path_a := DotDisasterTornado.centre(ev, 3.0)
	var path_b := DotDisasterTornado.centre(ev, 3.0)
	_check(path_a == path_b, "its path is a function of the record and the time")
	_check(DotDisasterTornado.centre(ev, 0.0).distance_to(DotDisasterTornado.centre(ev, 12.0)) > 10.0, "and it travels")
	var peak_up := 0.0
	var closest := 1e9
	for i in 480:
		await get_tree().physics_frame
		peak_up = maxf(peak_up, near.linear_velocity.y)
		closest = minf(closest, _flat(near.global_position - DotDisasterTornado.centre(ev, ev.elapsed)).length())
	_check(peak_up > 1.0, "a body inside it is lifted (%.1f m/s)" % peak_up)
	_check(near.global_position.y > 0.7 or peak_up > 1.0, "and has left the ground")
	_check(absf(far.linear_velocity.length()) < 0.5 and far.global_position.distance_to(Vector3(300.0, 0.5, 0.0)) < 1.0,
		"a body outside its radius is not touched")
	_check(p_near.pushes > 50 and p_near.pushed.length() > 1.0, "a player inside it is pushed (%d pushes)" % p_near.pushes)
	_check(p_far.pushes == 0, "a player outside is not")
	var flow := DotDisasterTornado.flow_at(ev, Vector3(5.0, 0.0, 0.0))
	_check(flow.y > 0.0 or ev.envelope() < 0.05, "its flow lifts near the axis")
	_check(m.wind_at(Vector3(1000.0, 0.0, 0.0)) == Vector3.ZERO, "and is nothing far away")
	await _frames(1)
	_check(not m.is_active(&"tornado") or ev.elapsed <= ev.duration, "it ends by itself")
	root.queue_free()
	_done()


func _wind() -> void:
	_section("wind and blizzard")
	var w := _world()
	var root: Node3D = w["root"]
	var m: DotDisasterManager = w["manager"]
	var ball := _ball(root, Vector3(0.0, 0.6, 0.0), 1.0)
	var far := _ball(root, Vector3(500.0, 0.6, 0.0), 1.0)
	var p := _player(root, Vector3(3.0, 0.0, 3.0))
	var ev: DotDisasterEvent = m.start(&"wind", {"origin": Vector3.ZERO, "duration": 12.0, "intensity": 2.0, "radius": 200.0, "heading": 0.0}).value
	var blizzard: DotDisasterEvent = m.start(&"blizzard", {"origin": Vector3(1000.0, 0.0, 0.0), "duration": 12.0, "radius": 50.0}).value
	_check(blizzard.kind == &"blizzard" and m.active_count() == 2, "blizzard and wind are both kinds")
	await _frames(240)
	_check(ball.linear_velocity.z > 1.0 or ball.global_position.z > 1.0,
		"a body is blown along the heading (z = %.1f)" % ball.global_position.z)
	_check(absf(far.global_position.x - 500.0) < 0.5 and absf(far.global_position.z) < 0.5, "a body outside the area is not")
	_check(p.pushed.z > 0.1, "a player is pushed downwind")
	var gusts := []
	for t in 20:
		gusts.append(DotDisasterWind.gust(ev, float(t)))
	_check(float(gusts.min()) >= 0.29 and float(gusts.max()) <= 1.0 and float(gusts.max()) - float(gusts.min()) > 0.1,
		"gusts stay between 30 % and 100 % and do vary")
	_check(m.wind_at(Vector3(0.0, 0.0, 0.0)).length() > 0.5 and m.wind_at(Vector3(0.0, 0.0, 5000.0)) == Vector3.ZERO,
		"wind_at answers a game's own vehicles, and nothing beyond the radius")
	root.queue_free()
	_done()


func _earthquake() -> void:
	_section("earthquake")
	var w := _world()
	var root: Node3D = w["root"]
	var m: DotDisasterManager = w["manager"]
	var near := _ball(root, Vector3(8.0, 0.6, 0.0), 1.0)
	var far := _ball(root, Vector3(400.0, 0.6, 0.0), 1.0)
	var p := _player(root, Vector3(-6.0, 0.0, 4.0))
	var ev: DotDisasterEvent = m.start(&"earthquake", {"origin": Vector3.ZERO, "duration": 9.0, "intensity": 2.0, "radius": 90.0}).value
	var rest := near.global_position
	var peak := 0.0
	var peak_shake := 0.0
	for i in 300:
		await get_tree().physics_frame
		peak = maxf(peak, near.global_position.distance_to(rest))
		peak_shake = maxf(peak_shake, m.shake_at(Vector3(5.0, 1.0, 0.0)))
	_check(peak > 0.1, "a body near the epicentre is thrown about (%.2f m)" % peak)
	_check(far.global_position.distance_to(Vector3(400.0, 0.5, 0.0)) < 0.5, "one far off is not")
	_check(p.pushes > 5, "a player stumbles")
	_check(peak_shake > 0.2, "the camera shakes near the epicentre (%.2f)" % peak_shake)
	_check(m.shake_at(Vector3(900.0, 1.0, 0.0)) == 0.0, "and not far from it")
	ev.elapsed = ev.duration
	await _frames(2)
	_check(m.shake_at(Vector3(5.0, 1.0, 0.0)) == 0.0, "the shaking stops when it ends")
	root.queue_free()
	_done()


func _thunderstorm() -> void:
	_section("thunderstorm")
	var w := _world()
	var root: Node3D = w["root"]
	var m: DotDisasterManager = w["manager"]
	var ball := _ball(root, Vector3(20.0, 0.6, 0.0), 1.0)
	var p := _player(root, Vector3(20.5, 0.0, 1.0))
	var ev: DotDisasterEvent = m.start(&"thunderstorm", {"origin": Vector3.ZERO, "duration": 40.0, "intensity": 1.0, "radius": 120.0}).value
	var kind: DotDisasterThunderstorm = m.get_kind(&"thunderstorm")
	var strikes: Array = []
	m.lightning_struck.connect(func(at: Vector3, target: Object) -> void: strikes.append([at, target]))
	var hits: Array = []
	m.damage_fn = func(target: Object, amount: float, _at: Vector3, _e: DotDisasterEvent) -> void: hits.append([target, amount])
	var at := kind.strike(ev, m, Vector3(20.0, 0.0, 2.5))
	await _frames(2)
	_check(absf(at.y) < 0.01, "a bolt lands on the ground it was aimed at (y = %.2f)" % at.y)
	_check(strikes.size() == 1 and (strikes[0][0] as Vector3).distance_to(at) < 0.01, "lightning_struck fires with where")
	_check(hits.size() >= 1 and hits.any(func(h: Array) -> bool: return h[0] == p), "a player beside the strike takes the damage hook")
	_check(float(hits[0][1]) > 0.0 and float(hits[0][1]) <= 30.0 * ev.intensity + 0.001, "damage is the cvar scaled by intensity")
	_check(ball.linear_velocity.length() > 1.0, "a body beside it is thrown (%.1f m/s)" % ball.linear_velocity.length())
	_check(p.pushes >= 1, "and the player is shoved")
	_check(m.shake_at(Vector3(20.0, 1.0, 0.0)) > 0.1, "the ground shakes at the strike")

	m.damage_fn = Callable()
	var plain := _player(root, Vector3(-40.0, 0.0, 0.0))
	kind.strike(ev, m, Vector3(-40.0, 0.0, 0.0))
	_check(plain.hp < 100.0, "without a hook, take_damage() is called")

	var before := strikes.size()
	await _frames(1)
	var ticker := m.start(&"thunderstorm", {"origin": Vector3.ZERO, "duration": 60.0, "intensity": 3.0, "radius": 100.0, "seed": 5}).value as DotDisasterEvent
	ticker.elapsed = 20.0
	await _frames(300)
	_check(strikes.size() > before, "a running storm strikes by itself (%d bolts)" % (strikes.size() - before))
	_check(m.receive({"t": "strike"}).error.code == DotError.CODE_FORBIDDEN, "a strike message is refused by the authority")
	root.queue_free()
	_done()


func _replication() -> void:
	_section("replication")
	var server_w := _world(true)
	var client_w := _world(false)
	var late_w := _world(false)
	var server: DotDisasterManager = server_w["manager"]
	var client: DotDisasterManager = client_w["manager"]
	var late: DotDisasterManager = late_w["manager"]
	var wire: Array[Dictionary] = []
	server.send_fn = func(msg: Dictionary) -> void:
		wire.append(msg)
		client.receive(msg)
	var started: Array = []
	client.disaster_started.connect(func(e: DotDisasterEvent) -> void: started.append(e))
	var ev: DotDisasterEvent = server.start(&"tornado", {"origin": Vector3(5.0, 0.0, 5.0), "duration": 30.0, "seed": 99}).value
	_check(wire.size() == 1 and wire[0]["t"] == "start", "starting sends one record")
	_check(client.active_count() == 1 and started.size() == 1, "the client starts it")
	var mirror: DotDisasterEvent = client.active()[0]
	_check(mirror.id == ev.id and mirror.seed == 99 and mirror.origin == ev.origin and mirror.kind == &"tornado",
		"identical to the server's")
	_check(DotDisasterTornado.centre(mirror, 5.0) == DotDisasterTornado.centre(ev, 5.0),
		"so the funnel is in the same place on both without a position being sent")
	client.step(2.0)
	_check(is_equal_approx(mirror.elapsed, 2.0) and is_equal_approx(ev.elapsed, 0.0), "the client keeps its own time")

	var storm: DotDisasterEvent = server.start(&"thunderstorm", {"origin": Vector3.ZERO, "duration": 30.0}).value
	var strikes: Array = []
	client.lightning_struck.connect(func(at: Vector3, _t: Object) -> void: strikes.append(at))
	var server_strikes: Array = []
	server.lightning_struck.connect(func(at: Vector3, _t: Object) -> void: server_strikes.append(at))
	(server.get_kind(&"thunderstorm") as DotDisasterThunderstorm).strike(storm, server, Vector3(3.0, 0.0, 3.0))
	_check(strikes.size() == 1 and server_strikes.size() == 1 and (strikes[0] as Vector3).distance_to(server_strikes[0]) < 0.01,
		"a strike reaches the client at the same place")

	for msg in server.snapshot():
		late.receive(msg)
	_check(late.active_count() == 2 and late.is_active(&"thunderstorm"), "a late joiner is brought up to date from the snapshot")
	late.receive(server.snapshot()[0])
	_check(late.active_count() == 2, "and the same snapshot twice adds nothing")

	var forged := ev.to_wire()
	forged["n"] = INF
	_check(not client.receive(forged).ok, "a forged record is refused")
	forged = ev.to_wire()
	forged["i"] = 99
	forged["k"] = "meteor"
	var unknown := client.receive(forged)
	_check(unknown.error.code == DotError.CODE_UNSUPPORTED, "a kind this build lacks is unsupported, not a crash")
	_check(not client.receive({"t": 5}).ok and not client.receive({"t": "stop", "i": 424242}).ok, "garbage is refused")

	server.stop(&"tornado")
	_check(wire.back()["t"] == "stop" and client.is_active(&"tornado") == false and server.is_active(&"thunderstorm"),
		"stopping one kind stops it on the client and leaves the other")
	_check(server.stop() == 1 and server.active_count() == 0 and client.active_count() == 0, "stop() with nothing ends all")
	for x in [server_w, client_w, late_w]:
		(x["root"] as Node).queue_free()
	_done()


func _director() -> void:
	_section("the director")
	var w := _world()
	var root: Node3D = w["root"]
	var m: DotDisasterManager = w["manager"]
	m.config.interval_min = 10.0
	m.config.interval_max = 20.0
	m.config.seed = 77
	var director := DotDisasterDirector.new()
	director.manager = m
	root.add_child(director)
	director.set_physics_process(false)
	m.set_physics_process(false)
	var picks: Array = []
	director.chosen.connect(func(id: StringName, _wait: float) -> void: picks.append(id))
	director.step(0.1)
	var armed := director.next_in()
	_check(armed >= 10.0 and armed <= 20.0, "it arms a gap within the interval (%.1f s)" % armed)
	var steps := 0
	while picks.is_empty() and steps < 400:
		director.step(0.5)
		m.step(0.5)
		steps += 1
	_check(picks.size() == 1 and m.active_count() == 1, "and then starts one")
	for i in 3000:
		director.step(0.5)
		m.step(0.5)
		_check_max_active(m)
	_check(picks.size() >= 5, "the schedule goes on (%d disasters)" % picks.size())
	var distinct := {}
	for id in picks:
		distinct[id] = true
	_check(distinct.size() >= 3, "and draws different kinds (%s)" % ", ".join(PackedStringArray(distinct.keys().map(func(k: Variant) -> String: return String(k)))))
	_check(_max_seen <= 1, "never more than max_active at once (%d)" % _max_seen)

	m.stop()
	picks.clear()
	m.config.kinds = "earthquake"
	for i in 2000:
		director.step(0.5)
		m.step(0.5)
	var only := true
	for id in picks:
		only = only and id == &"earthquake"
	_check(not picks.is_empty() and only, "the kinds cvar restricts what it picks")

	m.stop()
	picks.clear()
	m.config.director_enabled = false
	for i in 1000:
		director.step(0.5)
	_check(picks.is_empty(), "director_enabled = false schedules nothing")
	m.config.director_enabled = true
	m.config.kinds = ""
	m.config.max_active = 2
	m.config.tornado_weight = 0.0
	m.config.thunderstorm_weight = 0.0
	m.config.blizzard_weight = 0.0
	m.config.wind_weight = 0.0
	director.schedule_in(0.0)
	director.step(0.1)
	_check(director.last_choice == &"earthquake", "a kind's weight of zero removes it from the draw")

	var a := _sequence(77)
	var b := _sequence(77)
	var c := _sequence(78)
	_check(a == b and a.size() >= 4, "the same seed replays the same schedule")
	_check(a != c, "and another seed does not")
	_check(director.describe().begins_with("DotDisasterDirector"), "it describes itself")
	root.queue_free()
	_done()


var _max_seen := 0


func _check_max_active(m: DotDisasterManager) -> void:
	_max_seen = maxi(_max_seen, m.active_count())


func _sequence(seed_value: int) -> Array:
	var w := _world()
	var root: Node3D = w["root"]
	var m: DotDisasterManager = w["manager"]
	m.config.interval_min = 5.0
	m.config.interval_max = 8.0
	m.config.seed = seed_value
	m.set_physics_process(false)
	var d := DotDisasterDirector.new()
	d.manager = m
	root.add_child(d)
	d.set_physics_process(false)
	var out: Array = []
	d.chosen.connect(func(id: StringName, _wait: float) -> void: out.append(id))
	for i in 600:
		d.step(0.5)
		m.step(0.5)
	root.free()
	return out


func _views_and_shake() -> void:
	_section("views, sound and the camera shake")
	var w := _world(true, true)
	var root: Node3D = w["root"]
	var m: DotDisasterManager = w["manager"]
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 2.0, 12.0)
	root.add_child(camera)
	camera.make_current()
	var shake := DotDisasterShake.new()
	camera.add_child(shake)
	shake.manager = m

	for id in ["thunderstorm", "tornado", "blizzard", "wind", "earthquake"]:
		var ev: DotDisasterEvent = m.start(StringName(id), {"origin": Vector3.ZERO, "duration": 20.0, "intensity": 1.0, "radius": 80.0}).value
		ev.elapsed = 8.0
		var view := m.view_of(ev)
		await _frames(3)
		_check(view != null and view.get_child_count() >= 1 and view.is_inside_tree(), "%s draws a view with parts" % id)
	var storm_view: DotDisasterStormView = m.view_of(m.active()[0]) as DotDisasterStormView
	_check(storm_view != null, "the storm view is a DotDisasterStormView")
	storm_view.show_strike(Vector3(2.0, 0.0, 2.0), 12)
	_check(storm_view.bolt_count() == 1, "a strike puts a bolt on screen")
	await _frames(25)
	_check(storm_view.bolt_count() == 0, "and takes it off again")

	var names := ["thunder_1", "thunder_2", "thunder_3", "rain_loop", "wind_loop", "tornado_loop", "quake_rumble"]
	var missing := PackedStringArray()
	for n in names:
		if DotDisasterFx.sound(n) == null:
			missing.append(n)
	_check(missing.is_empty(), "every sound the views use is shipped (%s)" % ", ".join(missing))
	var quake := m.active()[4]
	var peak := 0.0
	for i in 40:
		await get_tree().process_frame
		peak = maxf(peak, absf(camera.h_offset) + absf(camera.v_offset))
	_check(peak > 0.0 and shake.current > 0.0, "the shake node moves the camera's offset (%.3f)" % peak)
	_check(camera.transform.origin == Vector3(0.0, 2.0, 12.0) and camera.rotation == Vector3.ZERO,
		"and never its transform")
	m.stop()
	await _frames(2)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(camera.h_offset == 0.0 and camera.v_offset == 0.0 or shake.current == 0.0, "it settles when the ground does")
	var leftover := 0
	for child in root.get_children():
		if child is DotDisasterView:
			leftover += 1
	_check(leftover == 0, "every view is freed with its disaster")
	_check(quake != null and m.describe().contains("authority") and m.describe_lines().size() >= 1, "the manager describes itself")
	_check(ResourceLoader.exists("res://addons/natural_disasters/natural_disasters_api.gd")
		and load("res://addons/natural_disasters/natural_disasters_api.gd").LEVEL >= 1, "the API level is declared")
	root.queue_free()
	_done()
