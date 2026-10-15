# natural-disasters

An addon repo: `addons/natural_disasters/` plus `examples/`. Read `~/CLAUDE.md` and `docs/gdscript-hazards.md` first; the README is the API.

- Layout: `core/` (event record, config, cvars, commands, kind base), `runtime/` (manager, director, shake, view base, fx), `kinds/` (one kind plus its view each), `audio/` (generated).
- Rules: no autoloads, `Dot` prefix, authority simulates and clients only draw, `DotResult` for fallible calls, `DotLog` with CHANNEL, `describe()` on state. A kind's path and gusts must stay pure functions of the event so replication stays one message.
- dot-server is optional and duck-typed; never `extends` or name its classes in addon code.
- Validate: `--import`, the `--check-only` loop, then `res://examples/disasters_selftest.tscn` under `timeout` (112 checks; update `EXPECTED_CHECKS` when adding any). Visual changes: render with `examples/disasters_demo.tscn --shot` under `xvfb-run` and look.
- Not here yet: dot-net wiring helper, a dedicated-server example, per-kind terrain damage, a hook loader for game-playground (the hooks it needs exist).
