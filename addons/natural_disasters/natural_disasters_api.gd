extends RefCounted

## natural-disasters' API level. The rule for bumping it is on [DotAddonApi].
##
## LEVEL rises by one for anything a game could call that did not exist before. OLDEST is
## raised to LEVEL when something a game could have called is removed or changes meaning,
## because every pack built before that no longer compiles against this addon.

# 1: everything: DotDisasterManager (register_kind, start, stop, receive, send_fn, snapshot),
#    DotDisasterDirector, DotDisasterKind and the four stock kinds, DotDisasterShake,
#    DotDisasterCvars and DotDisasterCommands.
const LEVEL := 1
const OLDEST := 1
