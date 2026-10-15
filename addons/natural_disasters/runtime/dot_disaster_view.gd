class_name DotDisasterView
extends Node3D

## The drawing of one running disaster on one machine. Base class: a kind's
## [method DotDisasterKind.make_view] returns a subclass that builds its particles, meshes and
## sounds in [method build] and moves them in [method refresh].
##
## A view reads the event and the manager and writes to nothing but itself. It owns its own
## audio and its own screen overlays, so freeing it (the manager does that when the event
## ends) silences and clears everything the disaster added.

var event: DotDisasterEvent
var ctx: DotDisasterManager
var _overlay_layer: CanvasLayer = null
var _sounds: Array[AudioStreamPlayer] = []
var _age: float = 0.0


func setup(ev: DotDisasterEvent, manager: DotDisasterManager) -> void:
	event = ev
	ctx = manager
	name = "Disaster%d_%s" % [ev.id, ev.kind]
	build()


## Override: create the particles, meshes, overlays and sounds.
func build() -> void:
	pass


## Override: called every frame with the time since the last one.
func update_view(_delta: float) -> void:
	pass


func refresh(delta: float) -> void:
	_age += delta
	update_view(delta)


## The point the weather is drawn around: the viewer's camera, kept inside the area so the
## storm is not drawn over the other side of the map. Falls back to the event's origin where
## there is no camera (a suite, a headless render).
func viewer_position() -> Vector3:
	var cam: Camera3D = null
	if is_inside_tree():
		cam = get_viewport().get_camera_3d()
	if cam == null:
		return event.origin
	return cam.global_position


## 0..1: how much of the event the viewer is inside, by horizontal distance to its origin.
func presence(at: Vector3) -> float:
	var d := event.flat_distance(at)
	return clampf(1.0 - (d - event.radius * 0.6) / maxf(event.radius * 0.4, 0.001), 0.0, 1.0)


## A full-screen colour overlay, mouse-transparent, under [member _overlay_layer].
func add_overlay(color: Color) -> ColorRect:
	if _overlay_layer == null:
		_overlay_layer = CanvasLayer.new()
		_overlay_layer.layer = 60
		add_child(_overlay_layer)
	var rect := ColorRect.new()
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_layer.add_child(rect)
	return rect


## A looping or one-shot non-positional sound from the addon's own bed, or null when the
## manager has sound turned off or the file is missing (a pack that stripped the audio).
func add_sound(sound_name: String, loop: bool, volume_db: float = -6.0, autoplay: bool = true) -> AudioStreamPlayer:
	if ctx != null and not ctx.sound_enabled:
		return null
	var stream: AudioStream = DotDisasterFx.sound(sound_name)
	if stream == null:
		return null
	var player := AudioStreamPlayer.new()
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop
	player.stream = stream
	player.volume_db = volume_db
	player.bus = ctx.audio_bus if ctx != null else &"Master"
	add_child(player)
	_sounds.append(player)
	if autoplay:
		player.play()
	return player


## A volume in dB for a 0..1 loudness, silent at zero.
static func db(loudness: float, full_db: float = -4.0) -> float:
	return -80.0 if loudness <= 0.001 else minf(linear_to_db(loudness) + full_db, 6.0)
