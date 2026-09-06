class_name VillageBackdrop
extends Control
## Fond de la scène village : un dégradé vertical unique du ciel au sol (pas
## deux blocs de couleur juxtaposés), avec une silhouette de collines
## lointaines à l'horizon ("style campagne" plutôt qu'un dégradé plat). Utilise
## les textures du manifest si fournies (sky/ground) ; sinon repli 100%
## procédural sur la palette EmpireTheme.

# Collines lointaines : offsets (x, y relatif à l'horizon) d'une silhouette
# Polygon2D, aucun asset externe.
const HILLS := [
	Vector2(0, 40), Vector2(160, -20), Vector2(320, 20), Vector2(480, -35),
	Vector2(640, 10), Vector2(800, -25), Vector2(960, 15), Vector2(1080, -10),
]

var _manifest: SpriteManifest


static func create(manifest: SpriteManifest) -> VillageBackdrop:
	var b := VillageBackdrop.new()
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b._manifest = manifest
	b._build()
	return b


func _build() -> void:
	var sky_tex := _manifest.background_texture("sky")
	var ground_tex := _manifest.background_texture("ground")

	if not sky_tex and not ground_tex:
		var horizon_ratio := VillageScene.GROUND_TOP / VillageScene.DESIGN_HEIGHT
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([
			EmpireTheme.SKY_TOP, EmpireTheme.SKY_HORIZON,
			EmpireTheme.GROUND, EmpireTheme.GROUND_DARK,
		])
		gradient.offsets = PackedFloat32Array([0.0, horizon_ratio, horizon_ratio, 1.0])
		var grad_tex := GradientTexture2D.new()
		grad_tex.gradient = gradient
		grad_tex.fill_from = Vector2(0, 0)
		grad_tex.fill_to = Vector2(0, 1)
		var backdrop := TextureRect.new()
		backdrop.texture = grad_tex
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(backdrop)
		_add_hills()
		return

	var sky := TextureRect.new()
	if sky_tex:
		sky.texture = sky_tex
		sky.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sky.stretch_mode = TextureRect.STRETCH_SCALE
	else:
		sky.texture = _solid_gradient(EmpireTheme.SKY_TOP, EmpireTheme.SKY_HORIZON)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sky)

	var ground: Control
	if ground_tex:
		var ground_rect := TextureRect.new()
		ground_rect.texture = ground_tex
		ground_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ground_rect.stretch_mode = TextureRect.STRETCH_TILE
		ground = ground_rect
	else:
		var gr := TextureRect.new()
		gr.texture = _solid_gradient(EmpireTheme.GROUND, EmpireTheme.GROUND_DARK)
		ground = gr
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	ground.offset_top = VillageScene.GROUND_TOP - VillageScene.DESIGN_HEIGHT
	add_child(ground)
	_add_hills()


## Silhouette de collines par-dessus le dégradé, à cheval sur l'horizon.
func _add_hills() -> void:
	var points := PackedVector2Array()
	for p in HILLS:
		points.append(Vector2(p.x, VillageScene.GROUND_TOP + p.y))
	points.append(Vector2(VillageScene.DESIGN_WIDTH, VillageScene.GROUND_TOP + 200))
	points.append(Vector2(0, VillageScene.GROUND_TOP + 200))

	var hills := Polygon2D.new()
	hills.polygon = points
	hills.color = Color(EmpireTheme.SAGE.r, EmpireTheme.SAGE.g, EmpireTheme.SAGE.b, 0.35)
	add_child(hills)


func _solid_gradient(top: Color, bottom: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, top)
	gradient.set_color(1, bottom)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	return tex
