extends Node
## Autoload "FirebaseClient" — accès Firebase via REST (aucun SDK natif requis).
## Couvre : Auth anonyme (Identity Toolkit), Cloud Functions callable (HTTPS),
## Firestore (get / commit batch).
##
## Pourquoi REST : pas de SDK Firebase officiel pour Godot ; le REST suffit pour
## la V1 et reste testable. Cloud Messaging (push) nécessitera un plugin natif
## (ex. GodotFirebase / plugin Android-iOS) — hors scope fondations.
##
## Réponse standard de toutes les méthodes : { "ok": bool, "data": Variant, "error": String }

signal signed_in(uid: String)
signal sign_in_failed(error: String)

const SETTINGS_PATH := "res://config/firebase_settings.json"
const AUTH_CACHE_PATH := "user://auth.json"

var project_id: String = ""
var api_key: String = ""
var functions_region: String = "europe-west1"

var uid: String = ""
var _id_token: String = ""
var _refresh_token: String = ""
var _token_expires_at_ms: int = 0
var _configured: bool = false


func _ready() -> void:
	_load_settings()


func is_configured() -> bool:
	return _configured


func is_signed_in() -> bool:
	return uid != "" and _id_token != ""


func _load_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		push_warning("FirebaseClient: %s absent — mode hors-ligne (copier firebase_settings.example.json)" % SETTINGS_PATH)
		return
	var s = JSON.parse_string(file.get_as_text())
	if s is Dictionary:
		project_id = str(s.get("project_id", ""))
		api_key = str(s.get("api_key", ""))
		functions_region = str(s.get("functions_region", functions_region))
		_configured = project_id != "" and api_key != ""


# ============================================================ AUTH (anonyme)

## Connexion anonyme. Réutilise le refresh token en cache pour conserver le même uid.
func sign_in_anonymously() -> bool:
	if not _configured:
		sign_in_failed.emit("not_configured")
		return false

	_load_auth_cache()
	if _refresh_token != "":
		if await _refresh_id_token():
			signed_in.emit(uid)
			return true

	var url := "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=%s" % api_key
	var res := await _request(url, HTTPClient.METHOD_POST, {"returnSecureToken": true})
	if not res.ok:
		sign_in_failed.emit(res.error)
		return false
	_store_tokens(res.data)
	signed_in.emit(uid)
	return true


func _refresh_id_token() -> bool:
	var url := "https://securetoken.googleapis.com/v1/token?key=%s" % api_key
	var res := await _request(url, HTTPClient.METHOD_POST,
		{"grant_type": "refresh_token", "refresh_token": _refresh_token})
	if not res.ok:
		return false
	var d: Dictionary = res.data
	uid = str(d.get("user_id", uid))
	_id_token = str(d.get("id_token", ""))
	_refresh_token = str(d.get("refresh_token", _refresh_token))
	_token_expires_at_ms = int(Time.get_unix_time_from_system() * 1000) + int(d.get("expires_in", "3600")) * 1000 - 60000
	_save_auth_cache()
	return _id_token != ""


func _store_tokens(d: Dictionary) -> void:
	uid = str(d.get("localId", ""))
	_id_token = str(d.get("idToken", ""))
	_refresh_token = str(d.get("refreshToken", ""))
	_token_expires_at_ms = int(Time.get_unix_time_from_system() * 1000) + int(d.get("expiresIn", "3600")) * 1000 - 60000
	_save_auth_cache()


func _ensure_valid_token() -> bool:
	if _id_token == "":
		return false
	if Time.get_unix_time_from_system() * 1000 >= _token_expires_at_ms:
		return await _refresh_id_token()
	return true


func _save_auth_cache() -> void:
	var f := FileAccess.open(AUTH_CACHE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"uid": uid, "refresh_token": _refresh_token}))


func _load_auth_cache() -> void:
	if not FileAccess.file_exists(AUTH_CACHE_PATH):
		return
	var f := FileAccess.open(AUTH_CACHE_PATH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		uid = str(d.get("uid", ""))
		_refresh_token = str(d.get("refresh_token", ""))


# ============================================================ CLOUD FUNCTIONS (callable)

## Appelle une fonction `onCall` v2. Protocole callable : body {"data": ...}, réponse {"result": ...}.
func call_function(function_name: String, payload: Dictionary = {}) -> Dictionary:
	if not await _ensure_valid_token():
		return _err("not_signed_in")
	var url := "https://%s-%s.cloudfunctions.net/%s" % [functions_region, project_id, function_name]
	var res := await _request(url, HTTPClient.METHOD_POST, {"data": payload}, _auth_headers())
	if not res.ok:
		return res
	if res.data is Dictionary and res.data.has("error"):
		return _err(str(res.data["error"].get("message", "function_error")))
	return {"ok": true, "data": res.data.get("result", {}), "error": ""}


# ============================================================ FIRESTORE (REST)

func _firestore_base() -> String:
	return "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents" % project_id


func user_doc_path() -> String:
	return "users/%s" % uid


## Lit un document. Retourne les champs décodés en Dictionary Godot.
func firestore_get(doc_path: String) -> Dictionary:
	if not await _ensure_valid_token():
		return _err("not_signed_in")
	var res := await _request(_firestore_base() + "/" + doc_path, HTTPClient.METHOD_GET, {}, _auth_headers())
	if not res.ok:
		return res
	return {"ok": true, "data": FirestoreCodec.decode_fields(res.data.get("fields", {})), "error": ""}


## Écrit plusieurs documents en une requête (`:commit`).
## writes : [{ "path": "users/uid", "fields": {...}, "mask": ["economy.gold", ...] (optionnel) }]
func firestore_commit(writes: Array) -> Dictionary:
	if not await _ensure_valid_token():
		return _err("not_signed_in")
	var full_name_prefix := "projects/%s/databases/(default)/documents/" % project_id
	var body_writes := []
	for w in writes:
		var entry := {
			"update": {
				"name": full_name_prefix + w["path"],
				"fields": FirestoreCodec.encode_fields(w["fields"]),
			}
		}
		if w.has("mask"):
			entry["updateMask"] = {"fieldPaths": w["mask"]}
		body_writes.append(entry)
	var res := await _request(_firestore_base() + ":commit", HTTPClient.METHOD_POST,
		{"writes": body_writes}, _auth_headers())
	return res


# ============================================================ HTTP bas niveau

func _auth_headers() -> PackedStringArray:
	return PackedStringArray(["Authorization: Bearer %s" % _id_token])


func _request(url: String, method: HTTPClient.Method, body: Dictionary = {}, extra_headers: PackedStringArray = PackedStringArray()) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 15.0
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json"])
	headers.append_array(extra_headers)
	var body_str := "" if method == HTTPClient.METHOD_GET else JSON.stringify(body)
	var err := http.request(url, headers, method, body_str)
	if err != OK:
		http.queue_free()
		return _err("request_error_%d" % err)
	var result: Array = await http.request_completed
	http.queue_free()
	var result_code: int = result[0]
	var response_code: int = result[1]
	var raw: PackedByteArray = result[3]
	if result_code != HTTPRequest.RESULT_SUCCESS:
		return _err("network_error_%d" % result_code)
	var parsed = JSON.parse_string(raw.get_string_from_utf8())
	if response_code < 200 or response_code >= 300:
		var msg := "http_%d" % response_code
		if parsed is Dictionary and parsed.has("error"):
			var e = parsed["error"]
			msg += ": " + str(e.get("message", e) if e is Dictionary else e)
		return _err(msg)
	return {"ok": true, "data": parsed if parsed != null else {}, "error": ""}


func _err(msg: String) -> Dictionary:
	push_warning("FirebaseClient: " + msg)
	return {"ok": false, "data": null, "error": msg}
