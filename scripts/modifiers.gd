class_name Modifiers
extends RefCounted
## Rundenmodifikatoren: Vor einer normalen Runde wird oft eine Sonderregel ausgelost und in der Bauphase
## angekündigt (Game.modifier). Die Werte sind Faktoren, fehlende Schlüssel bedeuten "keine Änderung".
##   enemy_hp, enemy_damage, enemy_speed, enemy_scale: Gegnerwerte
##   gold: Gold besiegter Gegner, spawn: Abstand zwischen den Gegnerwellen
##   ranged_range: Reichweite aller Fernkämpfer (auch Gegner), all_speed: Tempo aller Figuren
##   ability_cd: Abklingzeit eigener Fähigkeiten, regen: eigene Heilung pro Sekunde (Anteil der LP)
## `weather` ist die Darstellung (siehe Weather).

## Ab dieser Runde gibt es Modifikatoren, und mit dieser Wahrscheinlichkeit hat eine normale Runde einen.
const FIRST_ROUND := 2
const CHANCE := 0.7

const INFO := {
	&"fog": {"name": "Nebel", "text": "Fernkämpfer sehen nur 60 % so weit, auch die Gegner.",
		"ranged_range": 0.6, "weather": &"fog"},
	&"blood_moon": {"name": "Blutmond", "text": "Gegner sind schneller, geben aber doppeltes Gold.",
		"enemy_speed": 1.35, "gold": 2.0, "weather": &"blood_moon"},
	&"holy_ground": {"name": "Heilige Erde", "text": "Deine Einheiten heilen sich ständig ein wenig.",
		"regen": 0.02, "weather": &"holy"},
	&"giants": {"name": "Riesenwuchs", "text": "Wenige, aber riesige Gegner mit viel Leben. Mehr Gold.",
		"enemy_hp": 3.2, "enemy_damage": 1.5, "enemy_scale": 1.4, "spawn": 2.6, "gold": 2.6, "weather": &""},
	&"swarm": {"name": "Schwarm", "text": "Sehr viele, aber schwache Gegner.",
		"enemy_hp": 0.45, "enemy_damage": 0.7, "enemy_scale": 0.8, "spawn": 0.4, "gold": 0.55, "weather": &""},
	&"calm": {"name": "Windstille", "text": "Fähigkeiten deiner Einheiten laden doppelt so schnell.",
		"ability_cd": 0.5, "weather": &"calm"},
	&"gold_rain": {"name": "Goldregen", "text": "Besiegte Gegner lassen 50 % mehr Gold fallen.",
		"gold": 1.5, "weather": &"gold"},
	&"blizzard": {"name": "Schneesturm", "text": "Alle bewegen sich langsamer, Freund und Feind.",
		"all_speed": 0.7, "weather": &"snow"},
}


## Wert eines Schlüssels für den aktiven Modifikator (1.0 ohne Modifikator, bzw. 0.0 bei "regen").
static func value(key: String) -> float:
	var neutral := 0.0 if key == "regen" else 1.0
	if not INFO.has(Game.modifier):
		return neutral
	return float(INFO[Game.modifier].get(key, neutral))


static func display_name(id: StringName) -> String:
	return TranslationServer.translate(INFO[id]["name"]) if INFO.has(id) else ""


static func description(id: StringName) -> String:
	return TranslationServer.translate(INFO[id]["text"]) if INFO.has(id) else ""


static func weather(id: StringName) -> StringName:
	return INFO[id]["weather"] if INFO.has(id) else &""


## Auslosen für die Runde `round_number`: nur normale Runden, nie zweimal derselbe hintereinander.
static func roll(round_number: int, previous: StringName) -> StringName:
	if round_number < FIRST_ROUND or Game.round_kind(round_number) != Game.RoundKind.NORMAL or randf() >= CHANCE:
		return &""
	var pool: Array = INFO.keys()
	pool.erase(previous)
	return pool.pick_random()
