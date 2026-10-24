class_name RunSave
extends RefCounted
## Spielstand des laufenden Laufs (user://run.cfg), damit ein Lauf das Schließen der App übersteht.
## Gespeichert wird nur der Stand einer Bauphase: zu Beginn jeder Bauphase, beim Kampfstart (Stand vor
## dem Kampf), beim Verlassen und wenn die App in den Hintergrund geht. Nach einer Niederlage gelöscht.
## Ohne Fenster (Tests) wird nichts geschrieben, außer ein Test schaltet `enabled` ein.

const FORMAT := 1

static var path := "user://run.cfg"
static var enabled := DisplayServer.get_name() != "headless"


static func exists() -> bool:
	return enabled and FileAccess.file_exists(path)


## Gespeicherter Stand oder {} (keine Datei, beschädigt oder altes Format).
static func read() -> Dictionary:
	if not exists():
		return {}
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return {}
	var data = file.get_value("run", "data", {})
	if not data is Dictionary or int(data.get("format", 0)) != FORMAT:
		return {}
	return data


static func write(data: Dictionary) -> void:
	if not enabled:
		return
	var file := ConfigFile.new()
	file.set_value("run", "data", data)
	file.save(path)


static func clear() -> void:
	if enabled and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Stand von Game und den Einheiten der Arena als einfache Werte (nur Text- und Zahlenschlüssel).
## `offers`: Angebote eines offenen Ereignisses, sie stehen beim Fortsetzen wieder zur Wahl.
static func capture(arena: Node, offers: Array[Dictionary] = []) -> Dictionary:
	var units: Array[Dictionary] = []
	for unit: Combatant in arena.get_player_units():
		var pos := unit.home_position if Game.phase == Game.Phase.BATTLE else unit.position
		units.append({"id": String(unit.unit_data.id), "x": pos.x, "y": pos.y, "xp": unit.xp})
	var blessings := {}
	for group: StringName in Game.blessings:
		blessings[String(group)] = Game.blessings[group].duplicate()
	return {
		"format": FORMAT,
		"round": Game.round_number,
		"gold": Game.gold,
		"modifier": String(Game.modifier),
		"blessings": blessings,
		"houses": Game.house_levels.duplicate(),
		"stats": Game.stats.duplicate(),
		"auto_abilities": Game.auto_abilities,
		"battle_speed": Game.battle_speed,
		"rounds_without_event": int(arena.get("_rounds_without_event")),
		"event_pending": not offers.is_empty(),
		"event_offers": offers.map(func(offer: Dictionary) -> Dictionary: return RoundEvents.to_save(offer, arena)),
		"units": units,
	}


## Werte aus `data` in Game übernehmen (vor dem Aufbau der Arena, damit Gelände und Anzeige stimmen).
static func apply_game(data: Dictionary) -> void:
	Game.round_number = maxi(int(data.get("round", 1)), 1)
	Game.gold = maxi(int(data.get("gold", Game.START_GOLD)), 0)
	Game.modifier = StringName(data.get("modifier", ""))
	Game.blessings = {}
	var blessings: Dictionary = data.get("blessings", {})
	for group: String in blessings:
		var entry: Dictionary = blessings[group]
		Game.blessings[StringName(group)] = {"hp": float(entry.get("hp", 1.0)), "atk": float(entry.get("atk", 1.0))}
	Game.house_levels = {}
	var houses: Dictionary = data.get("houses", {})
	for category: String in houses:
		Game.house_levels[category] = int(houses[category])
	Game._reset_house_cache()
	Game.stats.merge(data.get("stats", {}), true)
	Game.auto_abilities = bool(data.get("auto_abilities", true))
	var speed := float(data.get("battle_speed", 1.0))
	Game.battle_speed = speed if Game.BATTLE_SPEEDS.has(speed) else 1.0
	Game.phase = Game.Phase.BUILD


## Einheiten aus `data`: [{"data": UnitData, "position": Vector2, "xp": int}]. Unbekannte Ids fallen weg.
static func units(data: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in data.get("units", []):
		var unit: UnitData = Registry.units.get(StringName(entry.get("id", "")))
		if unit == null:
			continue
		result.append({"data": unit, "position": Vector2(float(entry.get("x", 0.0)), float(entry.get("y", 0.0))),
				"xp": int(entry.get("xp", 0))})
	return result
