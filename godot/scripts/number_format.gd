class_name NumberFormat
extends RefCounted
## Formatage lisible des grands nombres pour l'UI (placeholder, à affiner plus tard).

const SUFFIXES := ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]


static func short(value: float, decimals: int = 2) -> String:
	if value < 1000.0:
		return String.num(value, 1 if value < 100.0 else 0)
	var idx := 0
	var v := value
	while v >= 1000.0 and idx < SUFFIXES.size() - 1:
		v /= 1000.0
		idx += 1
	return String.num(v, decimals) + SUFFIXES[idx]


## "2h30" ou "45 min" — pour les durées de boost, cap hors-ligne, etc.
static func duration(seconds: int) -> String:
	@warning_ignore("integer_division")
	var h := seconds / 3600
	@warning_ignore("integer_division")
	var m := (seconds % 3600) / 60
	return "%dh%02d" % [h, m] if h > 0 else "%d min" % m
