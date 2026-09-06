class_name WorkerActor
extends Node2D
## Un personnage qui va et vient devant son bâtiment. AnimatedSprite2D si le
## manifest fournit des frames, sinon silhouette PlaceholderShapes avec un
## petit sautillement procédural. Les pieds sont en y=0.

var _half_range: float
var _speed: float
var _dir: float = 1.0
var _sprite: AnimatedSprite2D
var _placeholder: Node2D
var _hop_phase: float = 0.0


static func create(frames: Array[Texture2D], fps: float, pixel_scale: float, half_range: float) -> WorkerActor:
	var w := WorkerActor.new()
	w._half_range = half_range
	w._speed = randf_range(30.0, 55.0)
	w._dir = 1.0 if randf() < 0.5 else -1.0
	w.position.x = randf_range(-half_range, half_range)
	w._build(frames, fps, pixel_scale)
	return w


func _build(frames: Array[Texture2D], fps: float, pixel_scale: float) -> void:
	if frames.is_empty():
		_placeholder = PlaceholderShapes.worker()
		add_child(_placeholder)
		return

	var sf := SpriteFrames.new()
	sf.add_animation("walk")
	sf.set_animation_speed("walk", fps)
	sf.set_animation_loop("walk", true)
	for t in frames:
		sf.add_frame("walk", t)

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = sf
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(pixel_scale, pixel_scale)
	_sprite.offset = Vector2(0, -frames[0].get_height() * 0.5)   # sprite centré -> pieds au sol
	_sprite.play("walk")
	add_child(_sprite)


func _process(delta: float) -> void:
	position.x += _dir * _speed * delta
	if absf(position.x) > _half_range:
		position.x = clampf(position.x, -_half_range, _half_range)
		_dir = -_dir

	if _sprite:
		_sprite.flip_h = _dir < 0.0
	else:
		_placeholder.scale.x = absf(_placeholder.scale.x) * (-1.0 if _dir < 0.0 else 1.0)
		_hop_phase += delta * 10.0
		_placeholder.position.y = -absf(sin(_hop_phase)) * 6.0
