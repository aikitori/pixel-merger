class_name Abilities
extends RefCounted
## Fähigkeiten der Einheiten: Name, Kurzbeschreibung, aktiv/passiv und Abklingzeit.
## Die Wirkung steckt in Combatant. Welche Einheit welche Fähigkeit hat, steht in tools/content.py.
## Aktive Fähigkeiten lösen im Kampf von selbst aus (Bedingung erfüllt, Abklingzeit vorbei),
## passive wirken dauerhaft. Die Stärke wächst mit der Stufe der Einheit (siehe power).

const INFO := {
	&"shield": {"name": "Schild hoch", "active": true, "cooldown": 10.0,
		"text": "Hebt bei nahen Gegnern kurz das Schild: nur ein Fünftel Schaden."},
	&"arrow_rain": {"name": "Pfeilregen", "active": true, "cooldown": 9.0,
		"text": "Lässt Pfeile auf das Ziel regnen und trifft alle Gegner im Umkreis."},
	&"meteor": {"name": "Feuersturm", "active": true, "cooldown": 12.0,
		"text": "Schlägt eine Explosion beim Ziel ein, die große Fläche verletzt."},
	&"frost_nova": {"name": "Frostnova", "active": true, "cooldown": 10.0,
		"text": "Frostwelle um die Einheit: verletzt und verlangsamt nahe Gegner."},
	&"sprint": {"name": "Sprint", "active": true, "cooldown": 8.0,
		"text": "Rennt kurz viel schneller, wenn das Ziel weit weg ist."},
	&"mass_heal": {"name": "Massenheilung", "active": true, "cooldown": 11.0,
		"text": "Heilt alle verletzten Verbündeten in der Nähe."},
	&"revive": {"name": "Wiederbeleben", "active": true, "cooldown": 22.0,
		"text": "Erweckt den zuletzt gefallenen Verbündeten mit halbem Leben."},
	&"taunt": {"name": "Spott", "active": true, "cooldown": 12.0,
		"text": "Zwingt nahe Gegner kurz, diese Einheit anzugreifen."},
	&"war_cry": {"name": "Kriegsruf", "active": true, "cooldown": 14.0,
		"text": "Verbündete in der Nähe machen kurz mehr Schaden."},
	&"armor": {"name": "Panzerung", "active": false, "cooldown": 0.0,
		"text": "Nimmt dauerhaft weniger Schaden."},
	&"regen": {"name": "Regeneration", "active": false, "cooldown": 0.0,
		"text": "Heilt sich laufend selbst."},
	&"evasion": {"name": "Ausweichen", "active": false, "cooldown": 0.0,
		"text": "Weicht manchen Treffern ganz aus."},
	&"lifesteal": {"name": "Lebensraub", "active": false, "cooldown": 0.0,
		"text": "Heilt sich um einen Teil des verursachten Schadens."},
	&"slow_aura": {"name": "Fluch-Aura", "active": false, "cooldown": 0.0,
		"text": "Gegner in der Nähe bewegen sich langsamer."},
	&"war_aura": {"name": "Anführer-Aura", "active": false, "cooldown": 0.0,
		"text": "Verbündete in der Nähe machen dauerhaft mehr Schaden."},
}


static func display_name(id: StringName) -> String:
	return TranslationServer.translate(INFO[id]["name"]) if INFO.has(id) else ""


static func description(id: StringName) -> String:
	return TranslationServer.translate(INFO[id]["text"]) if INFO.has(id) else ""


static func is_active(id: StringName) -> bool:
	return INFO.has(id) and INFO[id]["active"]


static func cooldown(id: StringName) -> float:
	return INFO[id]["cooldown"] if INFO.has(id) else 0.0


## "Schild hoch (aktiv)" bzw. "(passiv)"
static func label(id: StringName) -> String:
	if not INFO.has(id):
		return ""
	return "%s (%s)" % [display_name(id), TranslationServer.translate("aktiv" if INFO[id]["active"] else "passiv")]


## Stärkefaktor: Stufe 1 = 1,0, jede weitere Stufe +0,4. Kombinationen starten höher.
static func power(level: int, combo: bool) -> float:
	return (1.0 + 0.4 * (level - 1)) * (1.6 if combo else 1.0)
