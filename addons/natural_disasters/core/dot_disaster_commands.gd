class_name DotDisasterCommands
extends RefCounted

## Console commands for a [DotDisasterManager], in the duck-typed shape a console's
## `add_source` takes (`names`, `execute`, `help_for`, `complete`).
##
## [code]disaster <kind> [intensity] [duration] [radius][/code] starts one at once,
## [code]disaster_stop [kind][/code] ends one kind or everything, [code]disaster_list[/code]
## says what is running and what could.

var manager: DotDisasterManager


func _init(p_manager: DotDisasterManager = null) -> void:
	manager = p_manager


func names() -> PackedStringArray:
	return PackedStringArray(["disaster", "disaster_stop", "disaster_list"])


func help_for(command: String) -> String:
	match command:
		"disaster":
			return "disaster <kind> [intensity] [duration] [radius]: start a disaster now."
		"disaster_stop":
			return "disaster_stop [kind]: end a kind of disaster, or all of them."
		"disaster_list":
			return "disaster_list: the disasters running and the kinds registered."
	return ""


func complete(line: String, limit: int = 24) -> PackedStringArray:
	var out := PackedStringArray()
	if manager == null:
		return out
	var parts := line.split(" ")
	if parts.size() != 2:
		return out
	for id in manager.kind_ids():
		if id.begins_with(parts[1]) and out.size() < limit:
			out.append("%s %s" % [parts[0], id])
	return out


func execute(line: String) -> DotResult:
	if manager == null or not is_instance_valid(manager):
		return DotResult.fail(DotError.CODE_STATE, "No disaster manager.")
	var parts := Array(line.strip_edges().split(" ", false))
	var word: String = parts.pop_front() if not parts.is_empty() else ""
	match word:
		"disaster":
			if parts.is_empty():
				return DotResult.fail(DotError.CODE_INVALID, "Usage: disaster <kind> [intensity] [duration] [radius]")
			var overrides := {}
			for i in range(1, mini(parts.size(), 4)):
				var n := String(parts[i])
				if not n.is_valid_float():
					return DotResult.fail(DotError.CODE_INVALID, "Not a number.", n)
				overrides[["intensity", "duration", "radius"][i - 1]] = n.to_float()
			var res := manager.start(StringName(String(parts[0]).to_lower()), overrides)
			if not res.ok:
				return res
			return DotResult.success("started " + (res.value as DotDisasterEvent).describe())
		"disaster_stop":
			var which: Variant = null if parts.is_empty() else StringName(String(parts[0]).to_lower())
			return DotResult.success("stopped %d" % manager.stop(which))
		"disaster_list":
			var lines := manager.describe_lines()
			lines.append("kinds: " + ", ".join(manager.kind_ids()))
			return DotResult.success(lines)
	return DotResult.fail(DotError.CODE_INVALID, "Not a disaster command.", word)
