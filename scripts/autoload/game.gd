extends Node
## Globaler Spielzustand (Autoload "Game").

enum Phase { BUILD, BATTLE, GAME_OVER }
## Jede fünfte Runde ist besonders: 5, 15, 25 ... Boss, 10, 20, 30 ... Bonus (mehr Gold).
enum RoundKind { NORMAL, BOSS, BONUS }

signal phase_changed(new_phase: Phase)
signal gold_changed(new_gold: int)
signal round_changed(new_round: int)
signal speed_changed(new_speed: float)
signal modifier_changed(modifier: StringName)

const START_GOLD := 50
## Im Kampf dürfen höchstens MAX_UNITS Einheiten antreten, in der Bauphase bis BUILD_MAX_UNITS stehen
## (viele Grundeinheiten zum Verbinden). Überzählige schickt man zurück (REFUND_SHARE vom Kaufpreis).
const MAX_UNITS := 20
const BUILD_MAX_UNITS := 40
const REFUND_SHARE := 0.5
const BASE_BATTLE_SECONDS := 30.0
const BATTLE_SECONDS_PER_ROUND := 5.0
const MAX_BATTLE_SECONDS := 90.0
const BASE_SPAWN_INTERVAL := 3.0
const SPAWN_INTERVAL_STEP := 0.15
const MIN_SPAWN_INTERVAL := 0.6
const HEALTH_SCALE_PER_ROUND := 0.15
const DAMAGE_SCALE_PER_ROUND := 0.08
## Ab dieser Runde wachsen Leben und Schaden der Gegner zusätzlich um einen festen Anteil je Runde,
## aufeinander aufbauend: Stufen, Veteranen und Ausbau machen die eigene Armee schneller als linear stärker.
const LATE_ROUND := 10
const LATE_HEALTH_GROWTH := 1.08
const LATE_DAMAGE_GROWTH := 1.05
## Ausbau der Dorfhäuser: jede Stufe gibt den Einheiten der Kategorie mehr Leben und Stärke,
## der Preis steigt mit jeder Stufe (Goldsenke für späte Runden).
const HOUSE_BONUS_PER_LEVEL := 0.08
const HOUSE_BASE_PRICE := 30
const HOUSE_PRICE_GROWTH := 1.8
## Ab dieser Runde verkauft das Dorf auch Stufe 2 und 3 einer Linie direkt: Preis der Grundeinheiten
## und Verbindungen plus Aufschlag (spart in späten Runden das viele Verbinden).
const DIRECT_BUY_ROUND := 8
const DIRECT_BUY_MAX_LEVEL := 3
const DIRECT_BUY_MARKUP := 1.25
const GOLD_SCALE_PER_ROUND := 0.10
## Ab dieser Runde wächst das Gold pro Gegner nur noch halb so schnell (sonst staut es sich an).
const GOLD_SCALE_SLOWDOWN_ROUND := 10
## Bonusrunde: Gegner geben mehr Gold und kommen schneller, am Ende gibt es eine Prämie.
const BONUS_GOLD_MULT := 3.0
const BONUS_SPAWN_FACTOR := 0.6
const BONUS_FLAT_GOLD := 15
const BONUS_FLAT_GOLD_PER_ROUND := 3
## Ab dieser Runde sind manche Gegner Elite (Combatant.make_elite): Anteil wächst mit der Runde bis ELITE_MAX_CHANCE.
const ELITE_ROUND := 8
const ELITE_BASE_CHANCE := 0.04
const ELITE_CHANCE_PER_ROUND := 0.006
const ELITE_MAX_CHANCE := 0.12
const BATTLE_SPEEDS: Array[float] = [1.0, 2.0, 3.0]

var phase: Phase = Phase.BUILD
var round_number: int = 1
var gold: int = START_GOLD
## Tempo der Kampfphase (1x, 2x, 3x). Wirkt nur auf den Kampf, nicht auf Menüs.
var battle_speed: float = 1.0
## Aktive Fähigkeiten lösen von selbst aus. Aus: Der Spieler löst sie per Knopf aus.
var auto_abilities := true
## Boss ist nach Ablauf der Zeit wütend geworden (nur Bossrunden).
var boss_enraged := false
## Sonderregel der aktuellen Runde (siehe Modifiers), &"" = keine.
var modifier: StringName = &""
## Dauerhafte Segen aus Ereignissen (siehe RoundEvents): Gruppe -> {"hp": Faktor, "atk": Faktor}.
## Gruppen: &"melee", &"ranged", &"heal" (Kampfstil) und &"all" (alle eigenen Einheiten).
var blessings: Dictionary = {}
signal blessings_changed
## Ausbaustufe der Dorfhäuser für diesen Lauf: Kategorie (z.B. "Klassisch") -> Stufe, fehlt = 0.
var house_levels: Dictionary = {}
var _house_factors: Dictionary = {}  # UnitData -> Faktor (Kombinationen sind teuer zu berechnen)
signal houses_changed
## Auswertung des Laufs für den Verloren-Bildschirm (wird mit dem Lauf gespeichert).
## best_unit: Id der wertvollsten Einheit, die man hatte (gemessen am Preis ihrer Grundeinheiten).
var stats: Dictionary = {}
## Das Menü setzt das vor dem Szenenwechsel: Die Arena lädt dann den gespeicherten Lauf (RunSave).
var resume_requested := false


var _art_overlay: CanvasLayer


func _ready() -> void:
	refresh_art_style()


## Hängt die Nachbearbeitung des aktiven Bildstils (ArtStyle) über alle Szenen; nach ArtStyle.set_style aufrufen.
func refresh_art_style() -> void:
	if is_instance_valid(_art_overlay):
		_art_overlay.queue_free()
	_art_overlay = ArtStyle.make_overlay()
	if _art_overlay != null:
		add_child(_art_overlay)


func reset() -> void:
	round_number = 1
	gold = START_GOLD
	boss_enraged = false
	modifier = &""
	blessings = {}
	house_levels = {}
	_reset_house_cache()
	stats = {"kills": 0, "gold": 0, "merges": 0, "best_unit": "", "best_value": 0}
	phase = Phase.BUILD
	round_changed.emit(round_number)
	gold_changed.emit(gold)
	phase_changed.emit(phase)


func set_phase(new_phase: Phase) -> void:
	phase = new_phase
	phase_changed.emit(new_phase)


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


func next_round() -> void:
	round_number += 1
	modifier = Modifiers.roll(round_number, modifier)
	round_changed.emit(round_number)
	modifier_changed.emit(modifier)
	set_phase(Phase.BUILD)


func cycle_battle_speed() -> void:
	var index := BATTLE_SPEEDS.find(battle_speed)
	battle_speed = BATTLE_SPEEDS[(index + 1) % BATTLE_SPEEDS.size()]
	speed_changed.emit(battle_speed)


## Tastenkürzel +/-: eine Stufe schneller oder langsamer (ohne Umlauf).
func step_battle_speed(step: int) -> void:
	var index := clampi(BATTLE_SPEEDS.find(battle_speed) + step, 0, BATTLE_SPEEDS.size() - 1)
	if BATTLE_SPEEDS[index] != battle_speed:
		battle_speed = BATTLE_SPEEDS[index]
		speed_changed.emit(battle_speed)


## Für die Auswertung: merkt sich die wertvollste Einheit des Laufs.
func note_unit(data: UnitData) -> void:
	var value := Registry.bundle_price(Registry.base_units(data))
	if value > int(stats.get("best_value", 0)):
		stats["best_value"] = value
		stats["best_unit"] = String(data.id)


func count_stat(key: String, amount := 1) -> void:
	stats[key] = int(stats.get(key, 0)) + amount


## Zeitschritt für Kampflogik mit eingerechnetem Kampftempo.
func battle_delta(delta: float) -> float:
	return delta * battle_speed


func battle_seconds() -> float:
	return minf(BASE_BATTLE_SECONDS + BATTLE_SECONDS_PER_ROUND * (round_number - 1), MAX_BATTLE_SECONDS)


func spawn_interval() -> float:
	var interval := maxf(BASE_SPAWN_INTERVAL - SPAWN_INTERVAL_STEP * (round_number - 1), MIN_SPAWN_INTERVAL)
	interval *= Modifiers.value("spawn")
	return interval * BONUS_SPAWN_FACTOR if round_kind() == RoundKind.BONUS else interval


## Segen dauerhaft verstärken: `stat` ist "hp" oder "atk", `factor` z.B. 1.2 für +20 %.
func add_blessing(group: StringName, stat: String, factor: float) -> void:
	var entry: Dictionary = blessings.get(group, {"hp": 1.0, "atk": 1.0})
	entry[stat] = float(entry[stat]) * factor
	blessings[group] = entry
	blessings_changed.emit()


## Gesamtfaktor eines Werts für eine Einheit mit Kampfstil-Gruppe `group`.
func blessing(group: StringName, stat: String) -> float:
	var total := 1.0
	for key in [group, &"all"]:
		if blessings.has(key):
			total *= float(blessings[key][stat])
	return total


func house_level(category: String) -> int:
	return int(house_levels.get(category, 0))


func house_price(category: String) -> int:
	return roundi(HOUSE_BASE_PRICE * pow(HOUSE_PRICE_GROWTH, house_level(category)))


## Haus der Kategorie eine Stufe ausbauen (nur in der Bauphase). False bei zu wenig Gold.
func upgrade_house(category: String) -> bool:
	if phase != Phase.BUILD or not spend_gold(house_price(category)):
		return false
	house_levels[category] = house_level(category) + 1
	_reset_house_cache()
	houses_changed.emit()
	return true


func _reset_house_cache() -> void:
	_house_factors = {}


## Faktor auf Leben und Stärke durch den Hausausbau. Kombinationen zählen anteilig nach ihren
## Grundeinheiten (Paladin = Ritter + Magier: halb Kaserne, halb Gildenhaus).
func house_factor(data: UnitData) -> float:
	if house_levels.is_empty() or data == null:
		return 1.0
	if _house_factors.has(data):
		return _house_factors[data]
	var bundle := Registry.base_units(data)
	var total := 0
	var bonus := 0.0
	for base: UnitData in bundle:
		total += bundle[base]
		bonus += bundle[base] * HOUSE_BONUS_PER_LEVEL * house_level(base.category)
	var factor := 1.0 + (bonus / total if total > 0 else HOUSE_BONUS_PER_LEVEL * house_level(data.category))
	_house_factors[data] = factor
	return factor


## Sonderregel setzen (z.B. durch ein Ereignis zwischen den Runden).
func set_modifier(id: StringName) -> void:
	modifier = id
	modifier_changed.emit(modifier)


func round_kind(number := -1) -> RoundKind:
	var n := round_number if number < 0 else number
	if n % 10 == 5:
		return RoundKind.BOSS
	return RoundKind.BONUS if n % 10 == 0 else RoundKind.NORMAL


## Faktor auf das Gold besiegter Gegner (Bonusrunde).
func round_gold_mult() -> float:
	return BONUS_GOLD_MULT if round_kind() == RoundKind.BONUS else 1.0


func bonus_prize() -> int:
	return BONUS_FLAT_GOLD + BONUS_FLAT_GOLD_PER_ROUND * round_number


func health_scale() -> float:
	return (1.0 + HEALTH_SCALE_PER_ROUND * (round_number - 1)) * pow(LATE_HEALTH_GROWTH, _late_rounds())


func damage_scale() -> float:
	return (1.0 + DAMAGE_SCALE_PER_ROUND * (round_number - 1)) * pow(LATE_DAMAGE_GROWTH, _late_rounds())


func _late_rounds() -> int:
	return maxi(round_number - LATE_ROUND, 0)


func elite_chance() -> float:
	if round_number < ELITE_ROUND:
		return 0.0
	return minf(ELITE_BASE_CHANCE + ELITE_CHANCE_PER_ROUND * (round_number - ELITE_ROUND), ELITE_MAX_CHANCE)


func gold_scale() -> float:
	var early := mini(round_number, GOLD_SCALE_SLOWDOWN_ROUND) - 1
	var late := maxi(round_number - GOLD_SCALE_SLOWDOWN_ROUND, 0)
	return 1.0 + GOLD_SCALE_PER_ROUND * (early + 0.5 * late)
