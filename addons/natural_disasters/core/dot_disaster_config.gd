class_name DotDisasterConfig
extends DotConfig

## Every setting the manager and director read, as one layered configuration.
##
## exported defaults < JSON file < environment (DISASTERS_) < command line, the same layering
## as every dot-* config. Each key is also a cvar called `disaster_<key>`
## ([DotDisasterCvars]); a bound console wins over this object, so an operator's `set` takes
## effect on the next disaster without a restart.
##
## [b]Why the per-kind keys are spelled out rather than held in a dictionary.[/b]
## [DotConfig] discovers settings by reflecting on exported properties, so a dictionary would
## be invisible to the file, environment and command-line layers. A game's own kind has no
## property here; it reads its numbers from its own cvars (`disaster_<id>_intensity`,
## `_duration`, `_radius`, `_weight`) and falls back to [method DotDisasterKind.defaults].

const NO_SEED := 0

## Whether the director schedules anything. The manager's own `start` works either way.
@export var director_enabled: bool = true
## Seconds between one disaster ending and the next being chosen, drawn uniformly.
@export_range(1.0, 7200.0, 1.0, "or_greater") var interval_min: float = 120.0
@export_range(1.0, 7200.0, 1.0, "or_greater") var interval_max: float = 300.0
## How many may run at once. Two storms at once are legitimate; ten are a slideshow.
@export_range(1, 8) var max_active: int = 1
## Comma-separated kind ids the director may pick from. Empty means every registered kind.
@export var kinds: String = ""
## Seeds the director's draws so a server can replay a schedule. 0 means unseeded.
@export var seed: int = NO_SEED
## Whether the manager scans the whole world for rigid bodies when a game has not named any
## (group `disaster_bodies`). On by default so the example works with no setup; a game with a
## thousand bodies it does not want thrown turns it off and tags the ones it does.
@export var affect_all_bodies: bool = true
## Lightning damage to a target the bolt hits, before intensity scales it.
@export_range(0.0, 1000.0, 1.0, "or_greater") var lightning_damage: float = 30.0
## Tornado contact damage per second at the core, before intensity scales it.
@export_range(0.0, 1000.0, 1.0, "or_greater") var tornado_damage: float = 12.0

@export_range(0.0, 10.0, 0.05, "or_greater") var thunderstorm_intensity: float = 1.0
@export_range(1.0, 3600.0, 1.0, "or_greater") var thunderstorm_duration: float = 90.0
@export_range(1.0, 2000.0, 1.0, "or_greater") var thunderstorm_radius: float = 120.0
@export_range(0.0, 100.0, 0.1, "or_greater") var thunderstorm_weight: float = 3.0

@export_range(0.0, 10.0, 0.05, "or_greater") var tornado_intensity: float = 1.0
@export_range(1.0, 3600.0, 1.0, "or_greater") var tornado_duration: float = 75.0
@export_range(1.0, 2000.0, 1.0, "or_greater") var tornado_radius: float = 60.0
@export_range(0.0, 100.0, 0.1, "or_greater") var tornado_weight: float = 2.0

@export_range(0.0, 10.0, 0.05, "or_greater") var blizzard_intensity: float = 1.0
@export_range(1.0, 3600.0, 1.0, "or_greater") var blizzard_duration: float = 100.0
@export_range(1.0, 2000.0, 1.0, "or_greater") var blizzard_radius: float = 150.0
@export_range(0.0, 100.0, 0.1, "or_greater") var blizzard_weight: float = 2.0

@export_range(0.0, 10.0, 0.05, "or_greater") var wind_intensity: float = 1.0
@export_range(1.0, 3600.0, 1.0, "or_greater") var wind_duration: float = 60.0
@export_range(1.0, 2000.0, 1.0, "or_greater") var wind_radius: float = 150.0
@export_range(0.0, 100.0, 0.1, "or_greater") var wind_weight: float = 2.0

@export_range(0.0, 10.0, 0.05, "or_greater") var earthquake_intensity: float = 1.0
@export_range(1.0, 3600.0, 1.0, "or_greater") var earthquake_duration: float = 18.0
@export_range(1.0, 2000.0, 1.0, "or_greater") var earthquake_radius: float = 90.0
@export_range(0.0, 100.0, 0.1, "or_greater") var earthquake_weight: float = 1.5


func env_prefix() -> String:
	return "DISASTERS_"


func cli_prefix() -> String:
	return "--disasters-"


func validate() -> DotResult:
	if interval_max < interval_min:
		return DotResult.fail(
			DotError.CODE_INVALID, "interval_max is below interval_min.",
			"%s < %s" % [interval_max, interval_min]
		)
	return DotResult.success(self)


## The kinds the director may pick from, or an empty array for "all of them".
func allowed_kinds() -> PackedStringArray:
	var out := PackedStringArray()
	for part in kinds.split(",", false):
		var id := part.strip_edges().to_lower()
		if id != "":
			out.append(id)
	return out
