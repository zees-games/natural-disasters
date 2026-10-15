class_name DotDisasterDirector
extends Node

## Decides when the next disaster happens and which one. A timer and a weighted draw, nothing
## more: every number is a cvar (`disaster_interval_min`, `_interval_max`, `_max_active`,
## `_kinds`, `_seed`, `_director_enabled`, and `disaster_<kind>_weight`), read afresh each time
## it is used, so an operator retunes a running server.
##
## Runs only where its manager is the authority; on a client it idles, because the manager
## there is fed by the wire and starting anything would be refused anyway.

const CHANNEL := "disasters.director"

## Where the manager is, resolved against this node's parent. Defaults to the first
## [DotDisasterManager] under it. A game that builds both in code can assign [member manager]
## directly instead.
@export var manager_ref: DotNodeRef

## Fired when a disaster is chosen, before it starts.
signal chosen(kind_id: StringName, wait: float)

var manager: DotDisasterManager = null
var last_choice: StringName = &""

var _countdown: float = -1.0
var _rng := RandomNumberGenerator.new()
var _seeded: bool = false


func _ready() -> void:
	if manager == null:
		if manager_ref == null:
			manager_ref = DotNodeRef.new()
			manager_ref.mode = DotNodeRef.Mode.DESCENDANT_OF_TYPE
			manager_ref.type_name = &"DotDisasterManager"
		var res := manager_ref.resolve(get_parent() if get_parent() != null else self)
		if res.ok:
			manager = res.value
		else:
			DotLog.warn(CHANNEL, "no disaster manager found", {"why": res.error.message})
	_rng.randomize()


func _physics_process(delta: float) -> void:
	step(delta)


## Seconds until the next draw, or -1 before the first is armed.
func next_in() -> float:
	return _countdown


## Makes the next draw happen after [param seconds].
func schedule_in(seconds: float) -> void:
	_countdown = maxf(seconds, 0.0)


func step(delta: float) -> void:
	if manager == null or not manager.authority:
		return
	if not bool(manager.value("director_enabled", true)):
		return
	_seed_once()
	if _countdown < 0.0:
		_countdown = _draw_gap()
		return
	_countdown -= delta
	if _countdown > 0.0:
		return
	if manager.active_count() >= int(manager.value("max_active", 1)):
		_countdown = 5.0
		return
	var id := choose()
	if id == &"":
		_countdown = _draw_gap()
		return
	var wait := _draw_gap()
	chosen.emit(id, wait)
	var res := manager.start(id, {"origin": manager.pick_origin(_rng), "seed": _rng.randi()})
	if not res.ok:
		DotLog.warn(CHANNEL, "could not start the chosen disaster", {"kind": id, "why": res.error.message})
	last_choice = id
	_countdown = wait


## A kind drawn by weight from those allowed and not already running, or empty when none is.
func choose() -> StringName:
	var allowed := PackedStringArray()
	for part in String(manager.value("kinds", "")).split(",", false):
		allowed.append(part.strip_edges().to_lower())
	var pool: Array[StringName] = []
	var weights: Array[float] = []
	var total := 0.0
	for id_text in manager.kind_ids():
		var id := StringName(id_text)
		if not allowed.is_empty() and not allowed.has(id_text):
			continue
		if manager.is_active(id):
			continue
		var w := float(manager.settings_for(id).get("weight", 1.0))
		if w <= 0.0:
			continue
		pool.append(id)
		weights.append(w)
		total += w
	if pool.is_empty():
		return &""
	var roll := _rng.randf() * total
	for i in pool.size():
		roll -= weights[i]
		if roll <= 0.0:
			return pool[i]
	return pool[pool.size() - 1]


func _draw_gap() -> float:
	var lo := float(manager.value("interval_min", 120.0))
	var hi := maxf(float(manager.value("interval_max", 300.0)), lo)
	return _rng.randf_range(lo, hi)


func _seed_once() -> void:
	if _seeded:
		return
	_seeded = true
	var s := int(manager.value("seed", 0))
	if s != 0:
		_rng.seed = s


func describe() -> String:
	return "DotDisasterDirector next in %.0f s, last %s" % [_countdown, last_choice]
