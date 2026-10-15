class_name DotDisasterKinds
extends RefCounted

## The kinds the addon ships. A game that wants its own tornado registers one over the stock
## id with `replace = true`; a game that wants none of these sets `stock_kinds = false` on the
## manager and registers only what it names.


static func stock() -> Array[DotDisasterKind]:
	return [
		DotDisasterThunderstorm.new(),
		DotDisasterTornado.new(),
		DotDisasterWind.new(false),
		DotDisasterWind.new(true),
		DotDisasterEarthquake.new(),
	]
