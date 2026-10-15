class_name DotDisasterKind
extends RefCounted

## One sort of disaster: what it does to the world on the authority, and what it looks and
## sounds like on every machine. Subclass it and hand it to
## [method DotDisasterManager.register_kind]; nothing else in the addon changes.
##
## [b]Two halves and they never mix.[/b] [method server_tick] runs on the authority only and
## is the only place a body is moved or a player hurt. [method make_view] runs wherever a
## display exists and only draws; it reads the [DotDisasterEvent] and never writes to the
## world. A listen server runs both, which is why neither may assume the other is absent.
##
## [b]Subclasses keep no per-event state[/b] on themselves: one kind instance serves every
## event of its type, two storms at once included. Per-event state goes in [member
## DotDisasterEvent] through [method DotDisasterManager.state], which is dropped with it.

var id: StringName = &""
var display_name: String = ""


## The numbers a kind falls back to when neither a cvar nor the config names one. `intensity`
## is a multiplier (1 is the kind's idea of ordinary), `radius` metres, `duration` seconds,
## `weight` the director's relative odds. Add keys freely; a kind reads its own.
func defaults() -> Dictionary:
	return {"intensity": 1.0, "duration": 60.0, "radius": 80.0, "weight": 1.0}


## Authority, once, when the event starts.
func server_start(_ev: DotDisasterEvent, _ctx: DotDisasterManager) -> void:
	pass


## Authority, every physics step while the event runs. Scale everything by [code]delta[/code]
## and by [method DotDisasterEvent.envelope].
func server_tick(_ev: DotDisasterEvent, _delta: float, _ctx: DotDisasterManager) -> void:
	pass


## Authority, once, when the event ends or is stopped.
func server_end(_ev: DotDisasterEvent, _ctx: DotDisasterManager) -> void:
	pass


## A view that draws this event, or null for one that is felt and not seen. Called on every
## machine with a display; never on a headless server.
func make_view(_ev: DotDisasterEvent, _ctx: DotDisasterManager) -> DotDisasterView:
	return null


## A message about a running event reached this machine (the authority included, so a listen
## server draws its own bolt). The wire form is a Dictionary with at least `t`, `i` and `k`.
func on_message(_ev: DotDisasterEvent, _msg: Dictionary, _ctx: DotDisasterManager) -> void:
	pass


## How hard this event shakes a camera at [param at], 0..1.
func shake_at(_ev: DotDisasterEvent, _at: Vector3) -> float:
	return 0.0


## The wind this event blows at [param at], in metres per second. A game that has its own
## vehicles or projectiles adds it to theirs; the stock bodies are pushed by the kind itself.
func wind_at(_ev: DotDisasterEvent, _at: Vector3) -> Vector3:
	return Vector3.ZERO


func describe() -> String:
	return "%s (%s)" % [display_name if display_name != "" else String(id), id]
