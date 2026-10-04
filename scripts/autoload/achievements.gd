extends Node
## Erfolge (Autoload "Achievements"). Das Spiel meldet Ereignisse mit report() (zählt hoch) oder
## report_max() (merkt sich den Höchstwert), hier wird daraus der Fortschritt. Gespeichert wird in
## user://achievements.cfg, damit Erfolge über Spielstarts hinweg bleiben.

signal unlocked(id: StringName)

const SAVE_PATH := "user://achievements.cfg"

## id, Name, Beschreibung, Ereignis, Ziel; "max": true = Höchstwert statt Zähler.
const LIST: Array[Dictionary] = [
	{"id": &"first_merge", "name": "Erste Verbindung", "text": "Verbinde zwei Einheiten.", "event": &"merge", "goal": 1},
	{"id": &"first_combo", "name": "Alchemist", "text": "Erschaffe deine erste Kombination aus zwei verschiedenen Einheiten.", "event": &"combo", "goal": 1},
	{"id": &"combos_10", "name": "Meisteralchemist", "text": "Erschaffe 10 Kombinationen.", "event": &"combo", "goal": 10},
	{"id": &"first_lvl5", "name": "Meisterwerk", "text": "Erreiche mit einer Einheit Stufe 5.", "event": &"level5", "goal": 1},
	{"id": &"combo_max", "name": "Kombi-Meister", "text": "Bringe eine Kombination auf ihre höchste Stufe.", "event": &"combo_max", "goal": 1},
	{"id": &"first_boss", "name": "Bossbezwinger", "text": "Besiege den ersten Boss.", "event": &"boss", "goal": 1},
	{"id": &"bosses_5", "name": "Drachentöter", "text": "Besiege 5 Bosse.", "event": &"boss", "goal": 5},
	{"id": &"first_perfect", "name": "Makellos", "text": "Überstehe eine Runde, ohne eine Einheit zu verlieren.", "event": &"perfect", "goal": 1},
	{"id": &"perfect_5", "name": "Unbesiegbar", "text": "Überstehe 5 Runden ohne Verluste.", "event": &"perfect", "goal": 5},
	{"id": &"round_10", "name": "Durchhalter", "text": "Erreiche Runde 10.", "event": &"round", "goal": 10, "max": true},
	{"id": &"round_25", "name": "Veteran", "text": "Erreiche Runde 25.", "event": &"round", "goal": 25, "max": true},
	{"id": &"first_bonus", "name": "Goldrausch", "text": "Schließe eine Bonusrunde ab.", "event": &"bonus", "goal": 1},
	{"id": &"rich", "name": "Schatzkammer", "text": "Besitze 200 Gold gleichzeitig.", "event": &"gold", "goal": 200, "max": true},
	{"id": &"kills_100", "name": "Gegnerschreck", "text": "Besiege 100 Gegner.", "event": &"kill", "goal": 100},
	{"id": &"kills_1000", "name": "Legende der Arena", "text": "Besiege 1000 Gegner.", "event": &"kill", "goal": 1000},
	{"id": &"full_army", "name": "Volle Arena", "text": "Stelle 12 Einheiten gleichzeitig auf.", "event": &"army", "goal": 12, "max": true},
	{"id": &"first_revive", "name": "Zurück ins Leben", "text": "Erwecke einen gefallenen Verbündeten wieder.", "event": &"revive", "goal": 1},
	{"id": &"weatherproof", "name": "Wetterfest", "text": "Überstehe 10 Runden mit Sonderregel.", "event": &"modifier", "goal": 10},
	{"id": &"wanderer", "name": "Weltenbummler", "text": "Nimm 10 Angebote zwischen den Runden an.", "event": &"event", "goal": 10},
	{"id": &"lucky", "name": "Glückspilz", "text": "Gewinne ein Glücksspiel.", "event": &"gamble", "goal": 1},
	{"id": &"first_secret", "name": "Entdecker", "text": "Entdecke ein Geheimrezept.", "event": &"secret", "goal": 1},
	{"id": &"all_secrets", "name": "Geheimniskrämer", "text": "Entdecke alle Geheimrezepte.", "event": &"secret", "goal": 5},
	{"id": &"veteran_5", "name": "Kampferprobt", "text": "Bringe eine Einheit auf Veteranenstufe 5.", "event": &"veteran", "goal": 5, "max": true},
	{"id": &"veteran_10", "name": "Kriegsveteran", "text": "Bringe eine Einheit auf Veteranenstufe 10.", "event": &"veteran", "goal": 10, "max": true},
	{"id": &"tactician", "name": "Taktiker", "text": "Löse 10 Fähigkeiten selbst aus.", "event": &"manual", "goal": 10},
]

var progress: Dictionary = {}  # id -> Fortschritt (höchstens das Ziel)
## Speichern nur mit Fenster: Tests (headless) sollen keinen echten Spielstand verändern.
var persist := DisplayServer.get_name() != "headless"


func _ready() -> void:
	if persist:
		var file := ConfigFile.new()
		if file.load(SAVE_PATH) == OK:
			for entry in LIST:
				progress[entry["id"]] = int(file.get_value("progress", String(entry["id"]), 0))
	Game.gold_changed.connect(func(amount: int) -> void: report_max(&"gold", amount))


func report(event: StringName, amount := 1) -> void:
	_apply(event, amount, false)


func report_max(event: StringName, value: int) -> void:
	_apply(event, value, true)


func is_unlocked(id: StringName) -> bool:
	for entry in LIST:
		if entry["id"] == id:
			return progress.get(id, 0) >= entry["goal"]
	return false


func unlocked_count() -> int:
	return LIST.filter(func(entry: Dictionary) -> bool: return is_unlocked(entry["id"])).size()


func display_name(id: StringName) -> String:
	for entry in LIST:
		if entry["id"] == id:
			return TranslationServer.translate(entry["name"])
	return ""


## Alles zurücksetzen (nur für Tests und einen späteren "Spielstand löschen"-Knopf).
func reset() -> void:
	progress.clear()
	_save()


func _apply(event: StringName, value: int, as_max: bool) -> void:
	var changed := false
	for entry in LIST:
		if entry["event"] != event:
			continue
		var id: StringName = entry["id"]
		if is_unlocked(id):
			continue
		var current: int = progress.get(id, 0)
		var updated := maxi(current, value) if as_max else current + value
		progress[id] = mini(updated, entry["goal"])
		changed = true
		if progress[id] >= entry["goal"]:
			unlocked.emit(id)
	if changed:
		_save()


func _save() -> void:
	if not persist:
		return
	var file := ConfigFile.new()
	for id in progress:
		file.set_value("progress", String(id), progress[id])
	file.save(SAVE_PATH)
