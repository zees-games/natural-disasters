class_name GSDisasterKinds
extends RefCounted

## The kinds the addon ships. A game that wants its own tornado registers one over the stock
## id with `replace = true`; a game that wants none of these sets `stock_kinds = false` on the
## manager and registers only what it names.


static func stock() -> Array[GSDisasterKind]:
	return [
		GSDisasterThunderstorm.new(),
		GSDisasterTornado.new(),
		GSDisasterWind.new(false),
		GSDisasterWind.new(true),
		GSDisasterEarthquake.new(),
	]
