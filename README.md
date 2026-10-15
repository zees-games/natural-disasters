# natural-disasters

Server-authoritative natural disasters for Godot 4: thunderstorm, tornado, blizzard, wind and earthquake, plus a director that schedules them. Part of the TMC Dot family; `dot-core` is the only hard dependency, and `dot-server`'s console is used when present (duck-typed, never imported).

A disaster is a small record (`DotDisasterEvent`) that the authority sends once. Paths, gusts and shaking are deterministic functions of the record's seed and elapsed time, so clients draw the same funnel without a position ever being sent. The only per-event traffic afterwards is lightning strikes. Clients draw and never simulate.

## Using it

```gdscript
var disasters := DotDisasterManager.new()
disasters.authority = multiplayer.is_server()
disasters.send_fn = func(msg: Dictionary) -> void: my_broadcast(msg)   # authority only
disasters.damage_fn = func(target, amount, at, ev) -> void: target.hurt(amount)
add_child(disasters)

disasters.start(&"tornado", {"origin": Vector3(0, 0, 0), "duration": 60.0})   # returns a DotResult
```

On a client, feed every message the authority sent to `disasters.receive(msg)` (a `DotResult`; forged or malformed records are refused) and, when a player joins mid-disaster, call `disasters.send_snapshot(func(msg): send_to_that_peer(msg))` on the authority: it hands the callable one `start` per running disaster (`snapshot()` returns the same list). A host can set every hook in one line, `disasters.wire({"damage": ..., "push": ..., "send": ..., "bodies": ..., "players": ..., "origin": ...})` (a typo is `CODE_INVALID`), and `DotDisasterManager.damage_via(&"hurt")` / `push_via(&"add_push")` build the two hooks that just call a method on the target. `start` on a client and `receive` on the authority are both `CODE_FORBIDDEN`. dot-net is not imported: carry the dictionaries over whatever channel the game already has.

Nodes (all `Dot`-prefixed, no autoloads, hosts found through `DotNodeRef`):

- `DotDisasterManager`: owns the disasters, the registry of kinds and the views. Hooks: `send_fn`, `damage_fn`, `player_push_fn`, `bodies_fn`, `players_fn`, `origin_fn`. Targets are found by group (`disaster_bodies`, `disaster_players`) or by the hooks; set meta `disaster_immune` to exempt a body. Duck methods on a target: `apply_disaster_push(dv)`, `apply_disaster_damage(amount, at)`, `take_damage(amount)`.
- `DotDisasterDirector`: schedules disasters on a seeded random interval, weighted by kind, honouring `max_active` and `kinds`.
- `DotDisasterShake`: camera shake through `h_offset`/`v_offset` only, never the transform.

Queries for a game's own physics: `wind_at(point)` (a vehicle can be pushed by it), `shake_at(point)`, `is_active(kind)`, `active()`. Lightning on cue: `get_kind(&"thunderstorm").strike(event, manager, at_point)`.

## Registering your own disaster

Subclass `DotDisasterKind` (`id`, `defaults()`, `server_start/tick/end`, `make_view`, `shake_at`, `wind_at`) and call `manager.register_kind(kind)`; it returns `CODE_CONFLICT` for a taken id unless `replace` is true. A kind registered after a console is bound gets its cvars too. `stock_kinds = false` leaves the five stock kinds out. A game with its own weather (rain on a delivery route, say) registers a kind rather than forking.

## Settings and cvars

Layered like the rest of the family: exported defaults, JSON file, environment (`DISASTERS_`), command line (`--disasters-`), then cvars on a bound console (`manager.bind_console(console)`), each named `disaster_<key>`: `director_enabled`, `interval_min`, `interval_max`, `max_active`, `kinds`, `seed`, `affect_all_bodies`, `lightning_damage`, `tornado_damage`, and per kind `<kind>_intensity`, `_duration`, `_radius`, `_weight`. Commands: `disaster <kind> [intensity] [duration] [radius]`, `disaster_stop [kind]`, `disaster_list`.

## Examples and tests

```bash
godot --headless --path . --import
timeout 300 godot --headless --path . res://examples/disasters_selftest.tscn   # 115 checks
xvfb-run -a godot --path . res://examples/disasters_demo.tscn -- --kind tornado --shot out.png
```

The demo is interactive without `--shot` (keys 1 to 5 start a disaster, 0 stops).

## Credits

- Models in `assets/kenney/nature/`: Kenney Nature Kit, CC0, https://kenney.nl (licence kept in the folder). Used by the example scene only.
- Sounds in `addons/natural_disasters/audio/`: synthesised by `tools/make_sounds.py` (numpy and ffmpeg, fixed seeds), CC0 by the authors of this repository. Kenney has no thunder, so they are generated.
- Textures are generated in code.

Code is MIT (see `LICENSE`). The design was informed only by a public description of what such disasters do; no third-party code or assets were used.
