class_name FirestoreCodec
extends RefCounted
## Conversion Dictionary Godot <-> format "typed values" de l'API REST Firestore.
## Convention : les entiers (timestamps ms, niveaux, gemmes) -> integerValue ;
## les floats (or, multiplicateurs) -> doubleValue.


static func encode_fields(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[str(k)] = encode_value(d[k])
	return out


static func encode_value(v) -> Dictionary:
	match typeof(v):
		TYPE_NIL:
			return {"nullValue": null}
		TYPE_BOOL:
			return {"booleanValue": v}
		TYPE_INT:
			return {"integerValue": str(v)}
		TYPE_FLOAT:
			return {"doubleValue": v}
		TYPE_STRING, TYPE_STRING_NAME:
			return {"stringValue": str(v)}
		TYPE_DICTIONARY:
			return {"mapValue": {"fields": encode_fields(v)}}
		TYPE_ARRAY:
			var arr := []
			for item in v:
				arr.append(encode_value(item))
			return {"arrayValue": {"values": arr}}
		_:
			return {"stringValue": str(v)}


static func decode_fields(fields: Dictionary) -> Dictionary:
	var out := {}
	for k in fields:
		out[k] = decode_value(fields[k])
	return out


static func decode_value(tv: Dictionary):
	if tv.has("nullValue"):
		return null
	if tv.has("booleanValue"):
		return bool(tv["booleanValue"])
	if tv.has("integerValue"):
		return int(tv["integerValue"])
	if tv.has("doubleValue"):
		return float(tv["doubleValue"])
	if tv.has("stringValue"):
		return str(tv["stringValue"])
	if tv.has("timestampValue"):
		return str(tv["timestampValue"])   # non utilisé : on stocke des ms epoch en integerValue
	if tv.has("mapValue"):
		return decode_fields(tv["mapValue"].get("fields", {}))
	if tv.has("arrayValue"):
		var arr := []
		for item in tv["arrayValue"].get("values", []):
			arr.append(decode_value(item))
		return arr
	return null
