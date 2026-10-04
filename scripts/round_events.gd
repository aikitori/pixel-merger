class_name RoundEvents
extends RefCounted
## Ereignisse zwischen den Runden: Nach manchen Runden kreuzt jemand den Weg und bietet drei Karten an,
## von denen der Spieler eine wählt (oder weiterzieht). Angebote haben oft einen Preis oder einen Haken.
## Ein Angebot ist ein Dictionary: id, title, text, cost (Gold), enabled, icon (Texture2D oder null), data.

## Erstes Ereignis frühestens vor dieser Runde, danach mit CHANCE; nach PITY Runden ohne Ereignis sicher.
const FIRST_ROUND := 3
const CHANCE := 0.4
const PITY := 3
const OFFERS := 3

## Häufigkeit der Ereignisse.
const WEIGHTS := {
	&"treasure": 3.0, &"merchant": 3.0, &"recruit": 2.0, &"gamble": 2.0, &"smith": 2.0, &"armorer": 2.0,
	&"trainer": 2.0, &"witch": 1.0, &"shrine": 1.0, &"pact": 1.0,
}
const GROUP_ICON := {&"melee": "knight", &"ranged": "archer", &"heal": "healer"}
const GROUP_NAMES := {&"melee": "Nahkampf-Einheiten", &"ranged": "Fernkampf-Einheiten", &"heal": "Heil-Einheiten"}


static func should_offer(round_number: int, rounds_without: int) -> bool:
	if round_number < FIRST_ROUND:
		return false
	return rounds_without >= PITY or randf() < CHANCE


## Bis zu drei verschiedene Angebote, gewichtet gezogen aus allen, die gerade möglich sind.
static func offers(arena: Node) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for id: StringName in WEIGHTS:
		var offer := build(id, arena)
		if not offer.is_empty():
			pool.append(offer)
	var result: Array[Dictionary] = []
	while result.size() < OFFERS and not pool.is_empty():
		var total := 0.0
		for offer in pool:
			total += WEIGHTS[offer["id"]]
		var roll := randf() * total
		for offer in pool:
			roll -= WEIGHTS[offer["id"]]
			if roll <= 0.0:
				result.append(offer)
				pool.erase(offer)
				break
	return result


## Ein Angebot bauen, leer wenn es gerade nicht passt (z.B. Arena voll, keine passende Einheit).
static func build(id: StringName, arena: Node) -> Dictionary:
	var round_number := Game.round_number
	var units: Array[Combatant] = arena.get_player_units()
	var room: bool = units.size() < Game.MAX_UNITS
	var offer := {"id": id, "cost": 0, "icon": null, "data": {}}
	match id:
		&"treasure":
			var amount := 8 + 2 * round_number
			offer["title"] = tr_("Schatztruhe")
			offer["text"] = tr_("Am Wegrand liegt eine Truhe: +%d Gold.") % amount
			offer["data"] = {"gold": amount}
			offer["icon"] = UiTheme.coin()
		&"gamble":
			var stake := 15 + 2 * round_number
			offer["title"] = tr_("Glücksspiel")
			offer["text"] = tr_("Setze %d Gold. Bei Glück (50 %%) bekommst du das Dreifache zurück.") % stake
			offer["cost"] = stake
			offer["icon"] = UiTheme.coin()
		&"merchant":
			if not room:
				return {}
			var candidates: Array[UnitData] = []
			for recipe in Registry.recipes:
				if recipe.ingredient_a != recipe.ingredient_b and not recipe.secret \
						and recipe.unlock_round <= round_number + 3:
					candidates.append(recipe.result)
			if candidates.is_empty():
				return {}
			var unit: UnitData = candidates.pick_random()
			var price := maxi(8, roundi(Registry.bundle_price(Registry.base_units(unit)) * 0.6))
			offer["title"] = tr_("Wanderhändler")
			offer["text"] = tr_("Bietet an: %s, zum Freundschaftspreis.") % unit.display_name
			offer["cost"] = price
			offer["icon"] = unit.sprite
			offer["data"] = {"unit": unit}
		&"recruit":
			if not room:
				return {}
			var unit: UnitData = Registry.shop_units().pick_random()
			offer["title"] = tr_("Rekrut")
			offer["text"] = tr_("%s möchte sich dir anschließen, umsonst.") % unit.display_name
			offer["icon"] = unit.sprite
			offer["data"] = {"unit": unit}
		&"smith", &"armorer":
			var groups := {}
			for unit in units:
				groups[unit.style_group()] = true
			if groups.is_empty():
				return {}
			var group: StringName = groups.keys().pick_random()
			var smith := id == &"smith"
			offer["title"] = tr_("Schmied") if smith else tr_("Rüstmeister")
			offer["text"] = (tr_("%s: dauerhaft +20 %% Stärke.") if smith else tr_("%s: dauerhaft +25 %% Lebenspunkte.")) \
					% tr_(GROUP_NAMES[group])
			offer["cost"] = 10 + 2 * round_number
			offer["icon"] = _sprite(GROUP_ICON[group])
			offer["data"] = {"group": group, "stat": "atk" if smith else "hp", "factor": 1.2 if smith else 1.25}
		&"trainer":
			var candidates: Array[Combatant] = []
			for unit in units:
				if unit.unit_data.upgrade != null and unit.unit_data.upgrade.unlock_round <= round_number:
					candidates.append(unit)
			if candidates.is_empty():
				return {}
			var unit: Combatant = candidates.pick_random()
			offer["title"] = tr_("Ausbilder")
			offer["text"] = tr_("Bildet %s aus: wird ohne zweite Einheit zu %s.") % [unit.display_name, unit.unit_data.upgrade.display_name]
			offer["cost"] = unit.unit_data.upgrade_cost
			offer["icon"] = unit.unit_data.upgrade.sprite
			offer["data"] = {"unit": unit}
		&"witch":
			if units.size() < 3:
				return {}
			var weakest: Combatant = units[0]
			for unit in units:
				if unit.max_health < weakest.max_health:
					weakest = unit
			offer["title"] = tr_("Hexe")
			offer["text"] = tr_("Opfere %s: alle anderen Einheiten dauerhaft +10 %% Leben und Stärke.") % weakest.display_name
			offer["icon"] = weakest.sprite
			offer["data"] = {"unit": weakest}
		&"shrine":
			if Game.round_kind() != Game.RoundKind.NORMAL or Game.modifier == &"holy_ground":
				return {}
			offer["title"] = tr_("Schrein")
			offer["icon"] = _sprite("priest")
			offer["text"] = tr_("Ein Gebet, und die nächste Runde steht unter: %s.") % Modifiers.display_name(&"holy_ground")
		&"pact":
			if Game.round_kind() != Game.RoundKind.NORMAL or Game.modifier == &"giants":
				return {}
			var amount := 25 + 3 * round_number
			offer["title"] = tr_("Dunkler Pakt")
			offer["icon"] = _sprite("dark_witch")
			offer["text"] = tr_("+%d Gold, aber die nächste Runde bringt %s.") % [amount, Modifiers.display_name(&"giants")]
			offer["data"] = {"gold": amount}
		_:
			return {}
	offer["enabled"] = Game.gold >= int(offer["cost"])
	return offer


## Angebot ausführen. Gibt die Meldung für den Spieler zurück, leer wenn es nicht ging.
static func apply(offer: Dictionary, arena: Node) -> String:
	if not Game.spend_gold(int(offer["cost"])):
		return ""
	var data: Dictionary = offer["data"]
	match offer["id"]:
		&"treasure":
			Game.add_gold(data["gold"])
			return tr_("+%d Gold!") % data["gold"]
		&"gamble":
			if randf() < 0.5:
				Game.add_gold(int(offer["cost"]) * 3)
				Achievements.report(&"gamble")
				return tr_("Gewonnen! +%d Gold") % (int(offer["cost"]) * 3)
			return tr_("Verloren. Das Glück war dir nicht hold.")
		&"merchant", &"recruit":
			var unit: UnitData = data["unit"]
			arena.call("_spawn_player", unit, arena.call("_free_position"))
			return tr_("%s schließt sich dir an!") % unit.display_name
		&"smith", &"armorer":
			Game.add_blessing(data["group"], data["stat"], data["factor"])
			_refresh_blessings(arena)
			return tr_("Segen erhalten!")
		&"trainer":
			var unit: Combatant = data["unit"]
			if not is_instance_valid(unit):
				return ""
			var result: UnitData = unit.unit_data.upgrade
			var pos := unit.position
			unit.discard()
			arena.call("_spawn_player", result, pos)
			return tr_("%s ist jetzt %s!") % [unit.display_name, result.display_name]
		&"witch":
			var victim: Combatant = data["unit"]
			if is_instance_valid(victim):
				victim.discard()
			Game.add_blessing(&"all", "hp", 1.1)
			Game.add_blessing(&"all", "atk", 1.1)
			_refresh_blessings(arena)
			return tr_("Die Hexe nimmt ihr Opfer. Deine Einheiten werden stärker.")
		&"shrine":
			Game.set_modifier(&"holy_ground")
			return tr_("Die Erde wird geweiht.")
		&"pact":
			Game.add_gold(data["gold"])
			Game.set_modifier(&"giants")
			return tr_("Der Pakt ist geschlossen. Riesen nahen ...")
	return ""


static func _refresh_blessings(arena: Node) -> void:
	for unit: Combatant in arena.get_player_units():
		unit.refresh_blessings()


static func _sprite(unit_id: String) -> Texture2D:
	return Registry.units[unit_id].sprite if Registry.units.has(unit_id) else null


static func tr_(text: String) -> String:
	return TranslationServer.translate(text)
