class_name CoinPop
extends Node2D
## "+X or" qui s'élève et s'estompe : pièce sprite si le manifest en fournit
## une, sinon disque doré. S'auto-détruit à la fin de l'animation.

const RISE := 90.0
const DURATION := 0.8


static func spawn(parent: Node, pos: Vector2, text: String, coin: Texture2D, pixel_scale: float) -> void:
	var p := CoinPop.new()
	p.position = pos
	p._build(text, coin, pixel_scale)
	parent.add_child(p)
	p._animate()


func _build(text: String, coin: Texture2D, pixel_scale: float) -> void:
	if coin:
		var s := Sprite2D.new()
		s.texture = coin
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2(pixel_scale, pixel_scale) * 0.6
		add_child(s)
	else:
		add_child(PlaceholderShapes.coin())

	var l := Label.new()
	l.theme_type_variation = "RowName"
	l.add_theme_color_override("font_color", EmpireTheme.GOLD)
	l.text = text
	l.position = Vector2(22, -22)
	add_child(l)


func _animate() -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "position:y", position.y - RISE, DURATION).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 0.0, DURATION * 0.6).set_delay(DURATION * 0.4)
	t.chain().tween_callback(queue_free)
