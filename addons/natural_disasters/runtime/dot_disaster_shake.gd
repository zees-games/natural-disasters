class_name DotDisasterShake
extends Node

## Shakes a camera when [method DotDisasterManager.shake_at] says the ground is moving where
## it is. Moves `h_offset` and `v_offset` only, never the camera's transform: a first-person
## controller owns that every frame and would fight a rotation, while the offsets are a
## projection shift no controller touches. Put it next to the player's camera.

const MAX_OFFSET := 0.35

## The camera to shake, resolved against this node. Defaults to the parent.
@export var camera_ref: DotNodeRef
@export var manager_ref: DotNodeRef
## Scales the result; a game with an accessibility setting sets this to 0.
@export_range(0.0, 2.0, 0.05) var strength: float = 1.0

var manager: DotDisasterManager = null
var camera: Camera3D = null
## The last amount applied, 0..1, for a game that also wants a sound or a rumble from it.
var current: float = 0.0

var _t: float = 0.0


func _ready() -> void:
	if camera == null:
		if camera_ref == null:
			camera_ref = DotNodeRef.new()
			camera_ref.mode = DotNodeRef.Mode.PARENT
		var res := camera_ref.resolve(self)
		if res.ok and res.value is Camera3D:
			camera = res.value
	if manager == null and manager_ref != null:
		manager = manager_ref.resolve_or_null(self, "disasters.shake") as DotDisasterManager


func _process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	_t += delta
	var amount := 0.0
	if manager != null and is_instance_valid(manager):
		amount = manager.shake_at(camera.global_position) * strength
	current = amount
	# Two incommensurate sines per axis read as noise without a noise resource, and cost
	# nothing on the web.
	var k := amount * amount * MAX_OFFSET
	camera.h_offset = k * (sin(_t * 43.0) * 0.6 + sin(_t * 71.3) * 0.4)
	camera.v_offset = k * (sin(_t * 37.7 + 1.3) * 0.6 + sin(_t * 59.1) * 0.4)


func _exit_tree() -> void:
	if camera != null and is_instance_valid(camera):
		camera.h_offset = 0.0
		camera.v_offset = 0.0
