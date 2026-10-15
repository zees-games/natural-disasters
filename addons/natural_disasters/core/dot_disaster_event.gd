class_name DotDisasterEvent
extends RefCounted

## One disaster that is running: the whole of what crosses the wire.
##
## [b]A disaster is a record, not a stream.[/b] The server decides kind, place, size, length
## and a seed, and sends that once; every machine then draws the same funnel along the same
## path, because the path is a function of the record and the elapsed time and nothing else.
## What the world did in answer (which body went where) is the server's physics and replicates
## as physics; the only per-event traffic after the start is a lightning strike, which depends
## on what the bolt hit and so cannot be derived. A client that joins late is sent
## [method to_wire] with its current [member elapsed] and catches up.

const MAX_RADIUS := 2000.0
const MAX_INTENSITY := 10.0
const MAX_DURATION := 3600.0

## Seconds a disaster takes to build to full strength and to die away. Capped by a third of
## the duration, so a short quake is not all ramp.
const RAMP_IN := 6.0
const RAMP_OUT := 8.0

var id: int = 0
var kind: StringName = &""
var seed: int = 0
var origin: Vector3 = Vector3.ZERO
var radius: float = 60.0
var intensity: float = 1.0
var duration: float = 60.0
var elapsed: float = 0.0
## Radians about +Y; where wind blows toward and which way a tornado travels.
var heading: float = 0.0


func is_over() -> bool:
	return elapsed >= duration


func remaining() -> float:
	return maxf(duration - elapsed, 0.0)


## 0 at the start and 1 at the end.
func progress() -> float:
	return clampf(elapsed / maxf(duration, 0.001), 0.0, 1.0)


## 0..1 strength multiplier: ramps up, holds, ramps down. Everything a disaster does is scaled
## by this so none of them starts or stops as a step.
func envelope() -> float:
	var third := duration / 3.0
	var up := minf(RAMP_IN, third)
	var down := minf(RAMP_OUT, third)
	var a := clampf(elapsed / maxf(up, 0.001), 0.0, 1.0)
	var b := clampf(remaining() / maxf(down, 0.001), 0.0, 1.0)
	return smoothstep(0.0, 1.0, minf(a, b))


## A generator seeded from the record, fresh on every call: two machines asking for the same
## stream at the same point read the same numbers.
func rng(salt: int = 0) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed, salt])
	return r


## Horizontal distance from [param at] to the origin.
func flat_distance(at: Vector3) -> float:
	return Vector2(at.x - origin.x, at.z - origin.z).length()


func heading_vector() -> Vector3:
	return Vector3(sin(heading), 0.0, cos(heading))


func to_wire() -> Dictionary:
	return {
		"v": 1, "t": "start", "i": id, "k": String(kind), "s": seed,
		"o": [origin.x, origin.y, origin.z], "r": radius, "n": intensity,
		"d": duration, "e": elapsed, "h": heading,
	}


## Reads a record off the wire. Everything on it is attacker-controlled on a client that was
## sent a forged message and sloppy on a host that was not, so every field is checked and
## clamped rather than trusted; a malformed record is refused, never half-applied.
static func from_wire(msg: Dictionary) -> DotResult:
	for key in ["i", "k", "s", "o", "r", "n", "d"]:
		if not msg.has(key):
			return DotResult.fail(
				DotError.CODE_PARSE, "A disaster record is missing a field.", key
			)

	var o: Variant = msg["o"]
	if not (o is Array) or (o as Array).size() != 3:
		return DotResult.fail(DotError.CODE_PARSE, "A disaster origin must be three numbers.")

	var nums: Array[float] = []
	for v in [msg["r"], msg["n"], msg["d"], msg.get("e", 0.0), msg.get("h", 0.0),
			(o as Array)[0], (o as Array)[1], (o as Array)[2]]:
		if not (v is float or v is int) or not is_finite(float(v)):
			return DotResult.fail(DotError.CODE_PARSE, "A disaster field is not a finite number.")
		nums.append(float(v))

	if not (msg["i"] is int) or not (msg["s"] is int) or not (msg["k"] is String):
		return DotResult.fail(DotError.CODE_PARSE, "A disaster id, seed or kind has the wrong type.")

	var ev := DotDisasterEvent.new()
	ev.id = int(msg["i"])
	ev.seed = int(msg["s"])
	ev.kind = StringName(String(msg["k"]).to_lower())
	ev.radius = clampf(nums[0], 1.0, MAX_RADIUS)
	ev.intensity = clampf(nums[1], 0.0, MAX_INTENSITY)
	ev.duration = clampf(nums[2], 0.5, MAX_DURATION)
	ev.elapsed = clampf(nums[3], 0.0, ev.duration)
	ev.heading = nums[4]
	ev.origin = Vector3(nums[5], nums[6], nums[7])
	return DotResult.success(ev)


func describe() -> String:
	return "#%d %s intensity %.2f, %.0f of %.0f s, radius %.0f at (%.0f, %.0f, %.0f)" % [
		id, kind, intensity, elapsed, duration, radius, origin.x, origin.y, origin.z,
	]
