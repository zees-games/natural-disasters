class_name DotDisasterCvars
extends RefCounted

## The cvars every setting is also: `disaster_<key>` for each key in [DotDisasterConfig], and
## `disaster_<kind>_<intensity|duration|radius|weight>` for every registered kind.
##
## [b]Duck-typed, and dot-server is not named.[/b] An addon whose scripts mention a
## `class_name` the project lacks fails to parse and takes everything that references it
## down, so the console is an [Object] that has `cvar(name, default, description, flags)`,
## exactly as dot-server's [code]DotConsole[/code] does. The flags are spelled out for the
## same reason.

## Persisted by writeconfig, and meaningful only on a server.
const FLAGS := (1 << 0) | (1 << 5)

const DESCRIPTIONS := {
	"director_enabled": "Whether the director schedules disasters by itself.",
	"interval_min": "Shortest gap, in seconds, between one disaster ending and the next being chosen.",
	"interval_max": "Longest gap, in seconds, between disasters.",
	"max_active": "How many disasters may run at once.",
	"kinds": "Comma-separated kinds the director may pick; empty is every registered kind.",
	"seed": "Seeds the director's draws; 0 is unseeded.",
	"affect_all_bodies": "Disasters move every rigid body in the world, not only group disaster_bodies.",
	"lightning_damage": "Damage of a lightning strike to what it hits, before intensity.",
	"tornado_damage": "Tornado core damage per second, before intensity.",
}

const KIND_KEYS := {
	"intensity": "Strength multiplier; 1 is ordinary.",
	"duration": "Seconds the disaster lasts.",
	"radius": "Metres from its centre that it reaches.",
	"weight": "Relative odds the director picks it.",
}


## Registers one cvar per key of [param config]. Returns the count.
static func register(console: Object, config: DotDisasterConfig) -> DotResult:
	if console == null or not console.has_method("cvar"):
		return DotResult.fail(DotError.CODE_INVALID, "A console must have cvar().")
	var count := 0
	for key in config.config_keys():
		var key_name := String(key)
		if _is_kind_key(key_name):
			continue
		if _add(console, "disaster_" + key_name, config.get(key_name),
				String(DESCRIPTIONS.get(key_name, "natural-disasters setting"))):
			count += 1
	return DotResult.success(count)


## Registers a kind's cvars from its defaults, with the config's value where it has one so a
## JSON file or environment override survives the console being bound after it.
static func register_kind(console: Object, kind: DotDisasterKind, config: DotDisasterConfig) -> int:
	var count := 0
	var defaults := kind.defaults()
	for key in defaults:
		var full := "%s_%s" % [kind.id, key]
		var initial: Variant = config.get(full) if config != null and config.has_key(full) else defaults[key]
		var text := String(KIND_KEYS.get(key, "A setting of the %s disaster." % kind.id))
		if _add(console, "disaster_" + full, initial, "%s (%s)" % [text, kind.id]):
			count += 1
	return count


## Every key that belongs to a kind rather than to the director.
static func _is_kind_key(key: String) -> bool:
	for kind in ["thunderstorm", "tornado", "blizzard", "wind", "earthquake"]:
		if key.begins_with(kind + "_"):
			return true
	return false


static func _add(console: Object, cvar_name: String, initial: Variant, description: String) -> bool:
	if console.has_method("find_cvar") and console.call("find_cvar", cvar_name) != null:
		return false
	var text: String
	match typeof(initial):
		TYPE_BOOL:
			text = "1" if initial else "0"
		TYPE_FLOAT:
			text = String.num(initial, 4)
		_:
			text = str(initial)
	var created: Variant = console.call("cvar", cvar_name, text, description, FLAGS)
	if created is Object and (created as Object).has_method("with_min") \
			and (typeof(initial) == TYPE_FLOAT or typeof(initial) == TYPE_INT):
		(created as Object).call("with_min", 0.0)
	return true
