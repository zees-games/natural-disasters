class_name DotDisasterManager
extends Node

## Runs the disasters of one world: starts them, steps them, draws them, and answers a
## game's questions about them. One per world, placed by the game (no autoload), on the
## server and on every client.
##
## [b]Server-authoritative, replicated as a record.[/b] On the authority (`authority = true`,
## the dedicated server or the listen host) [method start] creates a [DotDisasterEvent], runs
## its kind's [method DotDisasterKind.server_tick] each physics step, and passes the record to
## [member send_fn]. A client's manager has `authority = false`, never simulates, and is fed
## by [method receive]; it only draws. Bind [member send_fn] to whatever the game replicates
## with (a dot-net message, an RPC) and call [method receive] on the other end: the wire form
## is plain Dictionaries, so neither end needs to know the other's networking.
##
## [b]Registering your own.[/b] [method register_kind] takes a [DotDisasterKind]; its cvars
## are registered when a console is bound ([method bind_console]), so it is configured the
## same way as the stock four. [method wind_at] and [method shake_at] let a game's own
## vehicles and camera answer to any kind, stock or not.
##
## [codeblock]
## var disasters := DotDisasterManager.new()
## disasters.authority = multiplayer.is_server()
## disasters.send_fn = func(msg: Dictionary) -> void: net.broadcast(&"disaster", msg)
## add_child(disasters)
## disasters.bind_console(server.console)
## disasters.register_kind(MyAcidRain.new())
## disasters.start(&"tornado", {"intensity": 1.5})
## [/codeblock]

const CHANNEL := "disasters"
const BODY_REFRESH := 1.0
const BODY_GROUP := &"disaster_bodies"
const PLAYER_GROUP := &"disaster_players"
const IMMUNE_META := &"disaster_immune"

signal disaster_started(event: DotDisasterEvent)
signal disaster_ended(event: DotDisasterEvent)
## A bolt came down at [param position]; [param target] is what it hit (null for the ground
## or a miss). Fires on the authority and on every client.
signal lightning_struck(position: Vector3, target: Object)

enum VisualsMode {
	## Draw unless there is no display (a dedicated server).
	AUTO,
	ON,
	OFF,
}

## The node the weather is drawn under and physics queries run against. Defaults to the
## parent, which is the world in the usual arrangement.
@export var world: DotNodeRef
## True on the machine that decides: the dedicated server or the listen host.
@export var authority: bool = true
@export var visuals_mode: VisualsMode = VisualsMode.AUTO
@export var sound_enabled: bool = true
@export var audio_bus: StringName = &"Master"
## Register the four stock kinds (and the wind and blizzard variants) on `_ready`.
@export var stock_kinds: bool = true
@export var config: DotDisasterConfig
## Physics layers a lightning bolt can hit.
@export_flags_3d_physics var strike_mask: int = 0xFFFFFFFF

## Called with each outgoing message on the authority: `(msg: Dictionary) -> void`.
var send_fn: Callable = Callable()
## `(target: Object, amount: float, at: Vector3, event: DotDisasterEvent) -> void`. Without
## one, a target with `apply_disaster_damage(amount, at)` or `take_damage(amount)` is called.
var damage_fn: Callable = Callable()
## `(player: Node3D, velocity_change: Vector3, event: DotDisasterEvent) -> void`. Without one
## a player with `apply_disaster_push(dv)` is called, else a CharacterBody3D has its velocity
## changed. A game with a prediction-corrected controller sets this.
var player_push_fn: Callable = Callable()
## `() -> Array` of RigidBody3D. Without one: group `disaster_bodies`, plus every rigid body
## under the world when `config.affect_all_bodies`.
var bodies_fn: Callable = Callable()
## `() -> Array` of Node3D. Without one: group `disaster_players`.
var players_fn: Callable = Callable()
## `(rng: RandomNumberGenerator) -> Vector3`: where the director centres a disaster. Without
## one: a random player's position, else the world's origin.
var origin_fn: Callable = Callable()

var _console: Object = null
var _kinds: Dictionary = {}
var _events: Array[DotDisasterEvent] = []
var _views: Dictionary = {}
var _state: Dictionary = {}
var _next_id: int = 1
var _rng := RandomNumberGenerator.new()
var _bodies: Array[RigidBody3D] = []
var _body_age: float = 1e9
var _pulses: Array = []


func _ready() -> void:
	if config == null:
		config = DotDisasterConfig.new()
	if world == null:
		world = DotNodeRef.new()
		world.mode = DotNodeRef.Mode.PARENT
	if stock_kinds:
		register_stock_kinds()
	_rng.randomize()
	set_physics_process(true)


# --- Registration -----------------------------------------------------------

## Adds a kind. A second kind with the same id is a conflict, not a replacement, unless
## [param replace] says so: a game swapping the stock tornado for its own says it.
func register_kind(kind: DotDisasterKind, replace: bool = false) -> DotResult:
	if kind == null or kind.id == &"":
		return DotResult.fail(DotError.CODE_INVALID, "A disaster kind needs an id.")
	if _kinds.has(kind.id) and not replace:
		return DotResult.fail(
			DotError.CODE_CONFLICT, "A disaster kind with this id is already registered.",
			String(kind.id)
		)
	_kinds[kind.id] = kind
	if _console != null:
		DotDisasterCvars.register_kind(_console, kind, config)
	DotLog.debug(CHANNEL, "kind registered", {"kind": kind.id})
	return DotResult.success(kind)


func unregister_kind(id: StringName) -> bool:
	return _kinds.erase(id)


func register_stock_kinds() -> void:
	for kind in DotDisasterKinds.stock():
		if not _kinds.has(kind.id):
			register_kind(kind)


func has_kind(id: StringName) -> bool:
	return _kinds.has(id)


func get_kind(id: StringName) -> DotDisasterKind:
	return _kinds.get(id)


func kind_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for id in _kinds:
		out.append(String(id))
	out.sort()
	return out


## Binds a [code]DotConsole[/code] (duck-typed: dot-server is not a dependency). Registers
## every setting as a `disaster_*` cvar, and the `disaster` commands, and from then on reads
## its numbers from the cvars.
func bind_console(console: Object) -> DotResult:
	if console == null or not console.has_method("cvar"):
		return DotResult.fail(
			DotError.CODE_INVALID, "A console must have cvar().",
			"" if console == null else console.get_class()
		)
	if config == null:
		config = DotDisasterConfig.new()
	_console = console
	var res := DotDisasterCvars.register(console, config)
	if not res.ok:
		return res.wrap("binding the console")
	for id in _kinds:
		DotDisasterCvars.register_kind(console, _kinds[id], config)
	if console.has_method("add_source"):
		console.call("add_source", DotDisasterCommands.new(self), "cvar")
	return res


## A setting by key (`interval_min`, `tornado_radius`): the bound console's cvar, else the
## config, else [param fallback]. The type of [param fallback] decides the type returned.
func value(key: String, fallback: Variant) -> Variant:
	if _console != null:
		var cvar_name := "disaster_" + key
		var known: Variant = _console.call("find_cvar", cvar_name) if _console.has_method("find_cvar") else null
		if known != null:
			match typeof(fallback):
				TYPE_BOOL:
					return bool(_console.call("get_bool", cvar_name, fallback))
				TYPE_INT:
					return int(_console.call("get_int", cvar_name, fallback))
				TYPE_STRING:
					return String(_console.call("get_string", cvar_name, fallback))
				_:
					return float(_console.call("get_float", cvar_name, fallback))
	if config != null and config.has_key(key):
		return config.get(key)
	return fallback


## The numbers a kind runs with: its cvars, then its config keys, then its defaults.
func settings_for(id: StringName) -> Dictionary:
	var kind: DotDisasterKind = _kinds.get(id)
	var out: Dictionary = {}
	if kind == null:
		return out
	var defaults := kind.defaults()
	for key in defaults:
		out[key] = value("%s_%s" % [id, key], defaults[key])
	return out


# --- Starting and stopping --------------------------------------------------

## Starts a disaster. [param overrides] may hold `intensity`, `duration`, `radius`, `origin`
## (Vector3), `heading` (radians) and `seed`; anything left out comes from
## [method settings_for] and the manager's own draws. Authority only.
func start(id: StringName, overrides: Dictionary = {}) -> DotResult:
	if not authority:
		return DotResult.fail(
			DotError.CODE_FORBIDDEN, "Only the authority starts a disaster.", String(id)
		)
	var kind: DotDisasterKind = _kinds.get(id)
	if kind == null:
		return DotResult.fail(
			DotError.CODE_INVALID, "No disaster kind is registered with this id.", String(id)
		)
	var s := settings_for(id)
	var ev := DotDisasterEvent.new()
	ev.id = _next_id
	_next_id += 1
	ev.kind = id
	ev.seed = int(overrides.get("seed", _rng.randi()))
	ev.intensity = clampf(float(overrides.get("intensity", s.get("intensity", 1.0))), 0.0, DotDisasterEvent.MAX_INTENSITY)
	ev.duration = clampf(float(overrides.get("duration", s.get("duration", 60.0))), 0.5, DotDisasterEvent.MAX_DURATION)
	ev.radius = clampf(float(overrides.get("radius", s.get("radius", 80.0))), 1.0, DotDisasterEvent.MAX_RADIUS)
	ev.heading = float(overrides.get("heading", _rng.randf() * TAU))
	var origin_value: Variant = overrides.get("origin", null)
	ev.origin = origin_value if origin_value is Vector3 else pick_origin()
	_begin(ev, kind)
	DotLog.info(CHANNEL, "disaster started", {
		"kind": id, "id": ev.id, "intensity": snappedf(ev.intensity, 0.01),
		"duration": snappedf(ev.duration, 0.1), "radius": snappedf(ev.radius, 0.1),
	})
	if send_fn.is_valid():
		send_fn.call(ev.to_wire())
	return DotResult.success(ev)


## Stops one disaster early (its id), or every one of a kind (a kind id), or all of them.
func stop(which: Variant = null) -> int:
	var victims: Array[DotDisasterEvent] = []
	for ev in _events:
		if which == null or (which is int and ev.id == which) \
				or ((which is StringName or which is String) and ev.kind == StringName(which)):
			victims.append(ev)
	for ev in victims:
		_end(ev)
		if authority and send_fn.is_valid():
			send_fn.call({"v": 1, "t": "stop", "i": ev.id, "k": String(ev.kind)})
	return victims.size()


func _begin(ev: DotDisasterEvent, kind: DotDisasterKind) -> void:
	_events.append(ev)
	_state[ev.id] = {}
	if authority:
		kind.server_start(ev, self)
	_spawn_view(ev, kind)
	disaster_started.emit(ev)


func _end(ev: DotDisasterEvent) -> void:
	if not _events.has(ev):
		return
	_events.erase(ev)
	var kind: DotDisasterKind = _kinds.get(ev.kind)
	if authority and kind != null:
		kind.server_end(ev, self)
	var view: DotDisasterView = _views.get(ev.id)
	if view != null and is_instance_valid(view):
		view.queue_free()
	_views.erase(ev.id)
	_state.erase(ev.id)
	DotLog.debug(CHANNEL, "disaster ended", {"kind": ev.kind, "id": ev.id})
	disaster_ended.emit(ev)


func _spawn_view(ev: DotDisasterEvent, kind: DotDisasterKind) -> void:
	if not draws():
		return
	var host := world_node()
	if host == null:
		return
	var view := kind.make_view(ev, self)
	if view == null:
		return
	host.add_child(view)
	view.setup(ev, self)
	_views[ev.id] = view


## Whether this machine draws: always on, never off, and on `AUTO` unless headless.
func draws() -> bool:
	match visuals_mode:
		VisualsMode.ON:
			return true
		VisualsMode.OFF:
			return false
	return DisplayServer.get_name() != "headless"


# --- Wire -------------------------------------------------------------------

## A message from the authority. A late joiner is fed [method snapshot] through here.
## Refused on the authority itself: a forged `start` from a client must not be able to run.
func receive(msg: Dictionary) -> DotResult:
	if authority:
		return DotResult.fail(
			DotError.CODE_FORBIDDEN, "The authority does not take disaster messages."
		)
	var t: Variant = msg.get("t", null)
	if not (t is String):
		return DotResult.fail(DotError.CODE_PARSE, "A disaster message has no type.")
	match String(t):
		"start":
			var res := DotDisasterEvent.from_wire(msg)
			if not res.ok:
				return res.wrap("reading a disaster record")
			var ev: DotDisasterEvent = res.value
			var kind: DotDisasterKind = _kinds.get(ev.kind)
			if kind == null:
				return DotResult.fail(
					DotError.CODE_UNSUPPORTED,
					"This build has no disaster kind with this id.", String(ev.kind)
				)
			var existing := find_event(ev.id)
			if existing != null:
				existing.elapsed = ev.elapsed
				return DotResult.success(existing)
			_begin(ev, kind)
			return DotResult.success(ev)
		"stop":
			var found := find_event(int(msg.get("i", -1)))
			if found == null:
				return DotResult.fail(DotError.CODE_INVALID, "No such disaster is running.")
			_end(found)
			return DotResult.success(found)
		_:
			var target := find_event(int(msg.get("i", -1)))
			if target == null:
				return DotResult.fail(DotError.CODE_INVALID, "No such disaster is running.", String(t))
			var kind2: DotDisasterKind = _kinds.get(target.kind)
			if kind2 != null:
				kind2.on_message(target, msg, self)
			return DotResult.success(target)


## The late-join hook: the host calls this once when a player joins, with a callable that
## delivers one dictionary to that player alone (`(msg: Dictionary) -> void`, usually the
## game's send-to-peer). Returns how many messages went. Without it a player who arrives in
## the middle of a storm sees clear sky until the next disaster starts, because a `start` is
## sent once. A client without authority sends nothing.
func send_snapshot(deliver: Callable) -> int:
	if not authority or not deliver.is_valid():
		return 0
	var sent := 0
	for msg in snapshot():
		deliver.call(msg)
		sent += 1
	return sent


## Assigns hooks from one dictionary, so a host wires everything in one place:
## `manager.wire({"damage": fn, "push": fn, "send": fn, "bodies": fn, "players": fn, "origin": fn})`.
## An unknown key is [code]CODE_INVALID[/code] and nothing is assigned, so a typo is not a
## silently missing hook.
func wire(hooks: Dictionary) -> DotResult:
	var names := {
		"send": "send_fn", "damage": "damage_fn", "push": "player_push_fn",
		"bodies": "bodies_fn", "players": "players_fn", "origin": "origin_fn",
	}
	for key in hooks:
		if not names.has(String(key)):
			return DotResult.fail(DotError.CODE_INVALID, "No such disaster hook.", String(key))
		if not (hooks[key] is Callable):
			return DotResult.fail(DotError.CODE_INVALID, "A disaster hook must be a Callable.", String(key))
	for key in hooks:
		set(names[String(key)], hooks[key])
	return DotResult.success(self)


## A `damage_fn` that calls `target.<method>(amount)`, for a host whose health lives behind
## one method (`hurt`, `apply_damage`). Targets without it are skipped.
static func damage_via(method: StringName) -> Callable:
	return func(target: Object, amount: float, _at: Vector3, _ev: DotDisasterEvent) -> void:
		if is_instance_valid(target) and target.has_method(method):
			target.call(method, amount)


## A `player_push_fn` that calls `player.<method>(velocity_change)`, for a controller that
## owns its velocity (a push written straight into a prediction-corrected body is undone on
## the next correction). Players without it are skipped.
static func push_via(method: StringName) -> Callable:
	return func(player: Node3D, dv: Vector3, _ev: DotDisasterEvent) -> void:
		if is_instance_valid(player) and player.has_method(method):
			player.call(method, dv)


## Messages that bring a client that joined late up to date: one `start` per running event,
## with its elapsed time. [method send_snapshot] is the hook that sends them.
func snapshot() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ev in _events:
		out.append(ev.to_wire())
	return out


## A kind's per-event message (a lightning strike): handled here at once and sent on.
func broadcast(ev: DotDisasterEvent, msg: Dictionary) -> void:
	msg["v"] = 1
	msg["i"] = ev.id
	msg["k"] = String(ev.kind)
	var kind: DotDisasterKind = _kinds.get(ev.kind)
	if kind != null:
		kind.on_message(ev, msg, self)
	if authority and send_fn.is_valid():
		send_fn.call(msg)


# --- Stepping ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	step(delta)


## Advances every disaster by [param delta]. Public so a suite, or a game that steps its
## world by hand, can drive it without a scene tree.
func step(delta: float) -> void:
	_body_age += delta
	for pulse in _pulses:
		pulse[2] += delta
	_pulses = _pulses.filter(func(p: Array) -> bool: return p[2] < 2.5)
	for ev in _events.duplicate():
		ev.elapsed += delta
		var kind: DotDisasterKind = _kinds.get(ev.kind)
		if authority and kind != null and not ev.is_over():
			kind.server_tick(ev, delta, self)
		var view: DotDisasterView = _views.get(ev.id)
		if view != null and is_instance_valid(view):
			view.refresh(delta)
		if ev.is_over():
			_end(ev)


# --- Queries ----------------------------------------------------------------

func active() -> Array[DotDisasterEvent]:
	return _events.duplicate()


func active_count() -> int:
	return _events.size()


func is_active(id: StringName) -> bool:
	for ev in _events:
		if ev.kind == id:
			return true
	return false


func find_event(id: int) -> DotDisasterEvent:
	for ev in _events:
		if ev.id == id:
			return ev
	return null


## The view drawing [param ev] on this machine, or null (headless, or a kind with none).
func view_of(ev: DotDisasterEvent) -> DotDisasterView:
	var v: DotDisasterView = _views.get(ev.id)
	return v if v != null and is_instance_valid(v) else null


## Per-event scratch space, dropped with the event.
func state(ev: DotDisasterEvent) -> Dictionary:
	return _state.get(ev.id, {})


## Camera shake at a point, 0..1: the strongest running event, plus any lightning pulse.
func shake_at(at: Vector3) -> float:
	var best := 0.0
	for ev in _events:
		var kind: DotDisasterKind = _kinds.get(ev.kind)
		if kind != null:
			best = maxf(best, kind.shake_at(ev, at))
	for p in _pulses:
		var fall := clampf(1.0 - at.distance_to(p[0]) / 150.0, 0.0, 1.0)
		best = maxf(best, float(p[1]) * fall * clampf(1.0 - float(p[2]) / 2.5, 0.0, 1.0))
	return clampf(best, 0.0, 1.0)


## A short shake from a point, for a kind's own events (a bolt landing).
func add_shake_pulse(at: Vector3, amount: float) -> void:
	_pulses.append([at, clampf(amount, 0.0, 1.0), 0.0])


## The wind at a point, metres per second, summed over every event that blows.
func wind_at(at: Vector3) -> Vector3:
	var sum := Vector3.ZERO
	for ev in _events:
		var kind: DotDisasterKind = _kinds.get(ev.kind)
		if kind != null:
			sum += kind.wind_at(ev, at)
	return sum


func world_node() -> Node3D:
	if world == null:
		return get_parent() as Node3D
	return world.resolve_or_null(self, CHANNEL) as Node3D


func viewer_position() -> Vector3:
	if is_inside_tree():
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			return cam.global_position
	return Vector3.ZERO


## A point to centre a disaster on, from [member origin_fn] or the players or the origin.
func pick_origin(rng: RandomNumberGenerator = null) -> Vector3:
	var r := rng if rng != null else _rng
	if origin_fn.is_valid():
		var v: Variant = origin_fn.call(r)
		if v is Vector3:
			return v
	var list := players()
	if not list.is_empty():
		var p: Node3D = list[r.randi() % list.size()]
		return Vector3(p.global_position.x, 0.0, p.global_position.z)
	return Vector3.ZERO


# --- What a kind acts on ----------------------------------------------------

func bodies() -> Array[RigidBody3D]:
	if bodies_fn.is_valid():
		var out: Array[RigidBody3D] = []
		for b in bodies_fn.call():
			if b is RigidBody3D and is_instance_valid(b):
				out.append(b)
		return out
	if _body_age >= BODY_REFRESH:
		_body_age = 0.0
		_bodies = _scan_bodies()
	return _bodies.filter(func(b: RigidBody3D) -> bool: return is_instance_valid(b) and b.is_inside_tree())


func _scan_bodies() -> Array[RigidBody3D]:
	var out: Array[RigidBody3D] = []
	if not is_inside_tree():
		return out
	for n in get_tree().get_nodes_in_group(BODY_GROUP):
		if n is RigidBody3D:
			out.append(n)
	if config != null and bool(value("affect_all_bodies", true)):
		var host := world_node()
		if host != null:
			_collect_bodies(host, out)
	return out.filter(func(b: RigidBody3D) -> bool: return not b.has_meta(IMMUNE_META) and not b.freeze)


func _collect_bodies(node: Node, out: Array[RigidBody3D]) -> void:
	for child in node.get_children():
		if child is RigidBody3D and not out.has(child):
			out.append(child)
		_collect_bodies(child, out)


func players() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if players_fn.is_valid():
		for p in players_fn.call():
			if p is Node3D and is_instance_valid(p):
				out.append(p)
		return out
	if is_inside_tree():
		for p in get_tree().get_nodes_in_group(PLAYER_GROUP):
			if p is Node3D:
				out.append(p)
	return out


func push_player(player: Node3D, dv: Vector3, ev: DotDisasterEvent) -> void:
	if player_push_fn.is_valid():
		player_push_fn.call(player, dv, ev)
	elif player.has_method("apply_external_velocity"):
		player.call("apply_external_velocity", dv)
	elif player.has_method("apply_disaster_push"):
		player.call("apply_disaster_push", dv)
	elif player is CharacterBody3D:
		(player as CharacterBody3D).velocity += dv


func impulse_body(body: RigidBody3D, impulse: Vector3, at: Vector3) -> void:
	if body.has_meta(IMMUNE_META) or not is_instance_valid(body):
		return
	body.sleeping = false
	body.apply_impulse(impulse, at - body.global_position)


func damage(target: Object, amount: float, at: Vector3, ev: DotDisasterEvent) -> void:
	if amount <= 0.0 or target == null:
		return
	if damage_fn.is_valid():
		damage_fn.call(target, amount, at, ev)
	elif target.has_method("apply_disaster_damage"):
		target.call("apply_disaster_damage", amount, at)
	elif target.has_method("take_damage"):
		target.call("take_damage", amount)


## A physics ray in the world's space; empty when nothing was hit or there is no world.
func raycast(from: Vector3, to: Vector3) -> Dictionary:
	var host := world_node()
	if host == null or not host.is_inside_tree():
		return {}
	var query := PhysicsRayQueryParameters3D.create(from, to, strike_mask)
	return host.get_world_3d().direct_space_state.intersect_ray(query)


func describe() -> String:
	return "DotDisasterManager %s, %d kinds, %d running" % [
		"authority" if authority else "client", _kinds.size(), _events.size(),
	]


func describe_lines() -> PackedStringArray:
	var out := PackedStringArray([describe()])
	for ev in _events:
		out.append("  " + ev.describe())
	return out
