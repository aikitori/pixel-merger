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
const GOLD_SCALE_PER_ROUND := 0.10
## Ab dieser Runde wächst das Gold pro Gegner nur noch halb so schnell (sonst staut es sich an).
const GOLD_SCALE_SLOWDOWN_ROUND := 10
## Bonusrunde: Gegner geben mehr Gold und kommen schneller, am Ende gibt es eine Prämie.
const BONUS_GOLD_MULT := 3.0
const BONUS_SPAWN_FACTOR := 0.6
const BONUS_FLAT_GOLD := 15
const BONUS_FLAT_GOLD_PER_ROUND := 3
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
	return 1.0 + HEALTH_SCALE_PER_ROUND * (round_number - 1)


func damage_scale() -> float:
	return 1.0 + DAMAGE_SCALE_PER_ROUND * (round_number - 1)


func gold_scale() -> float:
	var early := mini(round_number, GOLD_SCALE_SLOWDOWN_ROUND) - 1
	var late := maxi(round_number - GOLD_SCALE_SLOWDOWN_ROUND, 0)
	return 1.0 + GOLD_SCALE_PER_ROUND * (early + 0.5 * late)
