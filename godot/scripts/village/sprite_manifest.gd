class_name SpriteManifest
extends RefCounted
## Charge assets/sprites/manifest.json et fabrique les textures (AtlasTexture
## pour une région d'une planche). Toute entrée absente renvoie null / tableau
## vide et l'appelant retombe sur PlaceholderShapes : le jeu reste jouable et
## testable sans aucun asset externe.
##
## Format (chemins res://, régions et frames en pixels source) :
## {
##   "pixel_scale": 6,
##   "background": { "sky": {"texture": "..."}, "ground": {"texture": "..."} },
##   "coin": { "texture": "...", "region": [x, y, w, h] },
##   "generators": {
##     "<id>": {
##       "building": { "texture": "...", "region": [x, y, w, h] },
##       "worker":   { "texture": "...planche.png", "frame_size": [w, h],
##                     "frames": [[col, row], [col, row]], "fps": 6 }
##                ou { "files": ["...1.png", "...2.png"], "fps": 6 }
##     }
##   }
## }

const PATH := "res://assets/sprites/manifest.json"

var pixel_scale: float = 6.0
var _background: Dictionary = {}
var _coin: Dictionary = {}
var _generators: Dictionary = {}
var _cache: Dictionary = {}   # "chemin|région" -> Texture2D


static func load_default() -> SpriteManifest:
	var m := SpriteManifest.new()
	if not FileAccess.file_exists(PATH):
		return m
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		m._apply(parsed)
	else:
		push_warning("SpriteManifest: JSON invalide dans %s, silhouettes utilisées" % PATH)
	return m


func _apply(d: Dictionary) -> void:
	pixel_scale = JsonUtil.num(d, "pixel_scale", pixel_scale)
	if d.get("background") is Dictionary:
		_background = d["background"]
	if d.get("coin") is Dictionary:
		_coin = d["coin"]
	if d.get("generators") is Dictionary:
		_generators = d["generators"]


func background_texture(key: String) -> Texture2D:
	var spec = _background.get(key)
	return _texture(spec) if spec is Dictionary else null


func coin_texture() -> Texture2D:
	return _texture(_coin)


func building_texture(id: String) -> Texture2D:
	return _texture(_entry(id, "building"))


## Hauteur cible en pixels de conception (indépendante de la résolution
## source) : nécessaire pour des illustrations peintes haute résolution, où
## `pixel_scale` (pensé pour de petites tuiles pixel art) donnerait un résultat
## énorme. 0.0 si non précisée -> l'appelant retombe sur pixel_scale.
func building_height(id: String) -> float:
	return JsonUtil.num(_entry(id, "building"), "height", 0.0)


## Frames d'animation du personnage ; tableau vide si non défini.
func worker_frames(id: String) -> Array[Texture2D]:
	var w := _entry(id, "worker")
	var out: Array[Texture2D] = []
	if w.get("files") is Array:
		for f in w["files"]:
			var t := _texture({"texture": str(f)})
			if t:
				out.append(t)
		return out
	if not w.has("texture"):
		return out
	var frames = w.get("frames")
	if not (frames is Array) or frames.is_empty():
		var single := _texture(w)
		if single:
			out.append(single)
		return out
	var size := JsonUtil.vec2(w.get("frame_size"), Vector2(16, 16))
	for cell in frames:
		var c := JsonUtil.vec2(cell, Vector2.ZERO)
		var t := _texture({"texture": w["texture"], "region": [c.x * size.x, c.y * size.y, size.x, size.y]})
		if t:
			out.append(t)
	return out


func worker_fps(id: String) -> float:
	return JsonUtil.num(_entry(id, "worker"), "fps", 6.0)


func _entry(id: String, key: String) -> Dictionary:
	var g = _generators.get(id)
	if g is Dictionary and g.get(key) is Dictionary:
		return g[key]
	return {}


func _texture(spec: Dictionary) -> Texture2D:
	var path := JsonUtil.text(spec, "texture", "")
	if path == "":
		return null
	var region = spec.get("region")
	var has_region: bool = region is Array and region.size() == 4
	var key := path + ("|%s" % str(region) if has_region else "")
	if _cache.has(key):
		return _cache[key]
	if not ResourceLoader.exists(path):
		push_warning("SpriteManifest: texture introuvable %s (silhouette utilisée)" % path)
		return null
	var base: Texture2D = load(path)
	var tex: Texture2D = base
	if has_region:
		var atlas := AtlasTexture.new()
		atlas.atlas = base
		atlas.region = Rect2(float(region[0]), float(region[1]), float(region[2]), float(region[3]))
		tex = atlas
	_cache[key] = tex
	return tex
