class_name DotDisasterFx
extends RefCounted

## Small drawing helpers shared by the stock views: textures made in code, so the addon ships
## no image it has to credit, and the sounds it does ship.

static var _soft: Texture2D = null
static var _streak: Texture2D = null


static func audio_dir() -> String:
	var script: Script = DotDisasterFx
	return script.resource_path.get_base_dir().get_base_dir().path_join("audio")


## A named sound from the addon's `audio/` folder, or null. A copy each time: a view sets
## looping on its own, and a one-shot and a loop of one file must not share the flag.
static func sound(sound_name: String) -> AudioStream:
	var path := audio_dir().path_join(sound_name + ".ogg")
	if not ResourceLoader.exists(path):
		return null
	var stream: AudioStream = load(path) as AudioStream
	return null if stream == null else stream.duplicate() as AudioStream


## A round soft-edged blob: smoke, dust, snow, a drop seen end on.
static func soft_texture() -> Texture2D:
	if _soft == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_soft = t
	return _soft


## A thin vertical streak: rain, drawn as a billboard stretched along its fall.
static func streak_texture() -> Texture2D:
	if _streak == null:
		var img := Image.create(8, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			var fade := sin(PI * float(y) / 63.0)
			for x in 8:
				var across := 1.0 - absf((float(x) - 3.5) / 3.5)
				img.set_pixel(x, y, Color(1, 1, 1, clampf(fade * across, 0.0, 1.0)))
		_streak = ImageTexture.create_from_image(img)
	return _streak


## An unshaded, vertex-coloured, alpha-blended billboard material for particles.
static func particle_material(texture: Texture2D, mode: int = BaseMaterial3D.BILLBOARD_PARTICLES) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = texture
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if mode != BaseMaterial3D.BILLBOARD_DISABLED:
		m.billboard_mode = mode as BaseMaterial3D.BillboardMode
		m.billboard_keep_scale = true
	return m


## CPU particles drawn with [param texture]. CPU rather than GPU because the Compatibility
## renderer on the web draws both, but only the CPU kind is reproducible in a headless suite
## and costs a few hundred points at this count.
static func particles(texture: Texture2D, amount: int, lifetime: float,
		size: Vector2, color: Color,
		mode: int = BaseMaterial3D.BILLBOARD_PARTICLES) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.preprocess = lifetime
	p.local_coords = false
	p.draw_order = CPUParticles3D.DRAW_ORDER_INDEX
	p.color = color
	p.scale_amount_min = size.x
	p.scale_amount_max = size.y
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = particle_material(texture, mode)
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
