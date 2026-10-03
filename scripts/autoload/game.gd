extends Node
## Globaler Spielzustand (Autoload "Game").

enum Phase { BUILD, BATTLE, GAME_OVER }
## Jede fünfte Runde ist besonders: 5, 15, 25 ... Boss, 10, 20, 30 ... Bonus (mehr Gold).
enum RoundKind { NORMAL, BOSS, BONUS }

signal phase_changed(new_phase: Phase)
signal gold_changed(new_gold: int)
signal round_changed(new_round: int)
signal speed_changed(new_speed: float)

const START_GOLD := 50
const MAX_UNITS := 12
const BASE_BATTLE_SECONDS := 30.0
const BATTLE_SECONDS_PER_ROUND := 5.0
const MAX_BATTLE_SECONDS := 90.0
const BASE_SPAWN_INTERVAL := 3.0
const SPAWN_INTERVAL_STEP := 0.15
const MIN_SPAWN_INTERVAL := 0.6
const HEALTH_SCALE_PER_ROUND := 0.15
const DAMAGE_SCALE_PER_ROUND := 0.08
const GOLD_SCALE_PER_ROUND := 0.10
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


func reset() -> void:
	round_number = 1
	gold = START_GOLD
	boss_enraged = false
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
	round_changed.emit(round_number)
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
	return interval * BONUS_SPAWN_FACTOR if round_kind() == RoundKind.BONUS else interval


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
	return 1.0 + GOLD_SCALE_PER_ROUND * (round_number - 1)
