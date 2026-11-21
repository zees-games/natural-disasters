extends RefCounted

## natural-disasters' API level. The rule for bumping it is on [GSAddonApi].
##
## LEVEL rises by one for anything a game could call that did not exist before. OLDEST is
## raised to LEVEL when something a game could have called is removed or changes meaning,
## because every pack built before that no longer compiles against this addon.

# 1: everything: GSDisasterManager (register_kind, start, stop, receive, send_fn, snapshot),
#    GSDisasterDirector, GSDisasterKind and the four stock kinds, GSDisasterShake,
#    GSDisasterCvars and GSDisasterCommands.
const LEVEL := 1
const OLDEST := 1
