class_name Combatant
extends Node2D
## Einheit oder Gegner. Kämpft in der Kampfphase automatisch.
## Eigene Einheiten können einen Positionsbefehl bekommen: Sie laufen dorthin und
## halten die Stellung (greifen nur an, was in Reichweite kommt), bis der Befehl endet.

enum Team { PLAYER, ENEMY }

signal died(combatant: Combatant)

const GROUP_PLAYER := &"player"
const GROUP_ENEMY := &"enemy"
const ARRIVE_DISTANCE := 2.0
const SEPARATION_SPEED := 50.0
const RETARGET_INTERVAL := 0.4
const SWING_SECONDS := 0.25
const SWING_ARC := 1.3
## Dauer der Angriffsbilder im Animationsstreifen.
const ATTACK_ANIM_SECONDS := 0.32
## Richtungswechsel: Mindestabstand in x, Drehgeschwindigkeit (Sprite-Spiegelung pro Sekunde)
## und wie schnell die Laufrichtung der Zielrichtung folgt (mal Bewegungstempo pro Sekunde).
const FACE_DEADZONE := 5.0
const FLIP_SPEED := 9.0
const TURN_ACCELERATION := 8.0
const WALK_STEP_RATE := 0.35
const WALK_BOB := 2.0
## Animationsstreifen (assets/sprites/anim/): 4 Bilder Stehen, dann 4 Bilder Laufen.
## Streifen: 4 Bilder Stehen, 4 Laufen, 4 Angriff, 4 Tod (siehe tools/sprite_dcss.py).
const ANIM_FRAMES := 16
const ATTACK_FRAME := 8
const DEATH_FRAME := 12
const IDLE_FRAME_SECONDS := 0.2
## Laufbilder pro Schrittphase (eine Phase von 2*PI zeigt alle vier Laufbilder).
const RUN_FRAMES_PER_RADIAN := 2.0 / PI
const WALK_TILT := 0.08
## Intelligenz in Prozent = Chance, gezielt den schwächsten Gegner in der Nähe zu wählen.
const MAX_SMART_CHANCE := 90.0
const SMART_RADIUS := 60.0
## Heiler ohne Patient bleiben so nah bei ihren Verbündeten.
const HEALER_FOLLOW_DISTANCE := 40.0
## Schützen: Gegner in diesem Umkreis um den Schützling werden bekämpft, man entfernt sich nie weiter
## als die Leine von ihm, und ohne Gegner bleibt man in Folgeabstand.
const GUARD_ENGAGE := 70.0
const GUARD_LEASH := 90.0
const GUARD_FOLLOW_DISTANCE := 26.0
## Fähigkeiten: Reichweite der Auren, Prüfabstand der Auren und Tempo-Faktor beim Sprint.
const AURA_RADIUS := 60.0
const AURA_INTERVAL := 0.3
const SPRINT_FACTOR := 1.8
## Wuseln: Wer nichts zu tun hat, streift in der Nähe herum bzw. hüpft in der Bauphase vor Langeweile.
const WANDER_RADIUS := 34.0
const WANDER_SPEED_FACTOR := 0.45
const IDLE_HOP_SECONDS := 0.35
const IDLE_HOP_HEIGHT := 4.0
## Ab dieser Reichweite gilt eine Figur als Fernkämpfer (Modifikator Nebel).
const RANGED_MIN := 30.0
## Veteranen: Erfahrung aus Kämpfen hebt die Veteranenstufe (1 bis 10, getrennt von der Stufe durchs
## Verbinden). Jede Stufe über 1 gibt mehr Leben und Stärke, ab VETERAN_ABILITY_LEVEL eine zweite Fähigkeit.
const VETERAN_MAX := 10
const VETERAN_ABILITY_LEVEL := 5
const VETERAN_BONUS := 0.04
## Benötigte Gesamterfahrung je Veteranenstufe (Index = Stufe - 1).
const VETERAN_XP: Array[int] = [0, 3, 7, 12, 18, 25, 33, 42, 52, 63]
const XP_KILL := 1
const XP_BOSS := 6
const XP_SURVIVE := 2
## Heiler lernen vom Heilen: Heilung im Umfang der Lebenspunkte der Patienten, die so viel Erfahrung ergibt.
const XP_HEAL_PER_FULL := 1.0
## Zweite Fähigkeit der Veteranen je Kampfstil: die erste der Liste, die die Einheit noch nicht hat.
const VETERAN_ABILITIES := {
	&"melee": [&"war_cry", &"shield", &"taunt"],
	&"ranged": [&"arrow_rain", &"frost_nova", &"meteor"],
	&"heal": [&"mass_heal", &"revive"],
}
## Beschwörung: Helfer je Einheit (Id-Anfang) und wie lange sie bleiben. Bosse sind nur kürzer betäubt.
const SUMMON_UNITS := {"necromancer": "skeleton"}
const SUMMON_DEFAULT := "wolf_pup"
const SUMMON_SECONDS := 10.0
## Elite-Gegner: Faktoren auf Leben, Schaden, Beute und Größe.
const ELITE_HEALTH := 2.2
const ELITE_DAMAGE := 1.25
const ELITE_GOLD := 3
const ELITE_SCALE := 1.15
const BOSS_STUN_FACTOR := 0.4
## Rasterweite für das Abstandhalten. Große Figuren (Abstand body_size / 2 ab dieser Weite)
## prüfen weiter die ganze Gruppe.
const GRID_CELL := 16.0

## Mitglieder der Gruppen und Nachbarschaftsraster, gemeinsam für alle Figuren: get_nodes_in_group legt
## bei jedem Aufruf ein neues Array an, und das Abstandhalten prüfte jede Figur gegen jede ihres Teams.
## Die Listen werden neu gebaut, sobald eine Figur eine Gruppe betritt oder verlässt, das Raster
## einmal je Physik-Schritt.
static var _members: Dictionary = {}  # Gruppe -> Array (wie get_nodes_in_group)
static var _grids: Dictionary = {}  # Gruppe -> {Vector2i: Array[Combatant]}
static var _grid_frame := -1

var team: Team = Team.PLAYER
var unit_data: UnitData
var display_name := ""
var sprite: Texture2D
## Animationsstreifen zum Sprite, null wenn es keinen gibt.
var anim: Texture2D
var _anim_clock := randf() * 4.0
var _anim_frame := 0
var color := Color.WHITE
var level := 1
var body_size := 12.0
var max_health := 1.0
var health := 1.0
var attack := 1.0
var intelligence := 0.0
var attack_range := 12.0
var attack_cooldown := 1.0
var move_speed := 30.0
var gold_reward := 0
var is_boss := false
## Position vor der Kampfphase, wird danach wiederhergestellt.
var home_position := Vector2.ZERO
var has_order := false
var order_position := Vector2.ZERO
## Schützling: Die Einheit weicht ihm nicht von der Seite und greift an, was ihn bedroht.
var guard_target: Combatant
## Angriffsziel (Rechtsklick oder Tipp auf einen Gegner): verfolgt ihn, bis er fällt, dann wieder frei.
var attack_target: Combatant
## Fähigkeit (siehe Abilities) und ihre Stärke; aktive lösen von selbst aus.
var ability: StringName = &""
var ability_power := 1.0
var ability_casts := 0
var _ability_cd := 0.0
## Veteranen: Erfahrung, Stufe 1-10 und ab Stufe 5 eine zweite (aktive) Fähigkeit.
var xp := 0
var _heal_xp_pool := 0.0
var veteran_level := 1
var veteran_ability: StringName = &""
var _veteran_cd := 0.0
## Beschworener Helfer: zählt nicht als eigene Einheit und verschwindet nach Ablauf (oder Rundenende).
var summoned := false
var minion_id: StringName = &""  # Gegner: wen "Beschwörung" ruft
var elite := false  # Gegner: stärker, größer, goldener Ring, bringt mehr Gold
var summoner: Combatant
var _summon_left := 0.0
var _poison_source: Combatant
var _aura_left := 0.0
## Wirkungen auf diese Einheit: Name -> [Restzeit, Wert]. Namen: shield, sprint, slow, buff.
var _effects: Dictionary = {}
var _forced_target: Combatant
var _forced_left := 0.0
var highlighted := false:
	set(value):
		highlighted = value
		queue_redraw()
## Maus darüber (nur mit Maus, Touch hat kein Schweben).
var hovered := false:
	set(value):
		if hovered != value:
			hovered = value
			queue_redraw()

var _target: Combatant
var _retarget_left := 0.0
var _cooldown_left := 0.0
var attack_style: StringName = &"melee"
## Eigenart (siehe Behaviors, AttackKinds, Traits): Verhalten, Angriffsform und zusammengefasste Merkmale.
var behavior: StringName = &"frontline"
var attack_kind: StringName = &"slash"
var fx: Dictionary = {}
## Wächter: der beschützte Verbündete. Stürmer: Restzeit des Rückzugs. Hüpfer: Uhr für die Sprünge.
var ward: Combatant
var behavior_left := 0.0
var hop_clock := 0.0
## Aus dem Verhalten abgeleitet, damit der Physik-Schritt nur bei Bedarf in Behaviors ruft.
var _steers := false
var _hops := false
var _floats := false
var _opened := false  # erster Treffer im Kampf schon gesetzt (Merkmal "opener")
var _revived := false  # Merkmal "revive" schon verbraucht
var _trait_aura_left := 0.0
var _attack_anim_left := 0.0
var _swing_dir := Vector2.RIGHT
var _swing_left := 0.0
var _alive := true
## Die Sprites sind nach rechts gezeichnet. Gegner starten nach links blickend.
var _facing_left := false
## 1 = nach rechts, -1 = nach links, dazwischen dreht sich die Figur gerade.
var _flip := 1.0
var _velocity := Vector2.ZERO
var _walking := false
var _walk_phase := 0.0
## Jeder läuft ein wenig anders schnell, damit Gruppen nicht im Gleichschritt marschieren.
var _speed_jitter := randf_range(0.88, 1.15)
var _wander_point := Vector2.ZERO
var _wander_wait := 0.0
var _hop_t := -1.0
var _idle_left := randf_range(0.5, 4.0)


func setup_player(data: UnitData) -> void:
	team = Team.PLAYER
	unit_data = data
	display_name = data.display_name
	sprite = data.sprite
	anim = _load_anim(sprite)
	color = data.color
	level = data.level
	body_size = _sprite_height(10.0 + 2.0 * data.level)
	max_health = data.max_health
	attack = data.attack
	intelligence = data.intelligence
	attack_range = data.attack_range
	attack_style = data.attack_style
	attack_cooldown = data.attack_cooldown
	move_speed = data.move_speed
	ability = data.ability
	_set_behavior(data.behavior)
	attack_kind = data.attack_kind if AttackKinds.INFO.has(data.attack_kind) else AttackKinds.for_style(attack_style)
	fx = Traits.combine(data.traits)
	attack_range = _base_range()
	move_speed = _base_speed()
	attack_cooldown *= float(fx.get("cooldown", 1.0))
	ability_power = Abilities.power(data.level, data.category == "Kombination")
	_ability_cd = randf_range(2.0, 5.0)
	max_health *= _player_factor("hp")
	attack *= _player_factor("atk")
	health = max_health
	add_to_group(GROUP_PLAYER)
	_groups_changed()


func _set_behavior(id: StringName) -> void:
	behavior = id
	_steers = behavior in [&"guardian", &"skirmisher", &"flanker", &"charger", &"artillery"]
	_hops = behavior == &"hopper"
	_floats = behavior == &"floater"


## Gruppe für Segen: Nahkämpfer, Fernkämpfer (Pfeil oder Magie) oder Heiler.
func style_group() -> StringName:
	match attack_style:
		&"melee": return &"melee"
		&"heal": return &"heal"
	return &"ranged"


## Segen und Hausausbau neu anwenden, der Lebensanteil bleibt erhalten.
func refresh_blessings() -> void:
	if unit_data == null:
		return
	var share := health / maxf(max_health, 0.001)
	max_health = unit_data.max_health * _player_factor("hp")
	attack = unit_data.attack * _player_factor("atk")
	health = max_health * share
	queue_redraw()


## Faktor auf Leben ("hp") oder Stärke ("atk"): Segen, Veteranenstufe und Ausbau des Dorfhauses.
func _player_factor(stat: String) -> float:
	return Game.blessing(style_group(), stat) * veteran_factor() * Game.house_factor(unit_data) * float(fx.get(stat, 1.0))


## Reichweite und Tempo aus den Daten mit den Merkmalen (ohne Sonderregel der Runde).
func _base_range() -> float:
	return unit_data.attack_range * float(fx.get("range", 1.0))


func _base_speed() -> float:
	return unit_data.move_speed * float(fx.get("speed", 1.0))


# --- Veteranen -------------------------------------------------------------------

func veteran_factor() -> float:
	return 1.0 + VETERAN_BONUS * (veteran_level - 1)


## Erfahrung bis zur nächsten Veteranenstufe: [bisher in dieser Stufe, nötig]. Auf Stufe 10: [0, 0].
func veteran_progress() -> Array[int]:
	if veteran_level >= VETERAN_MAX:
		return [0, 0]
	var floor_xp := VETERAN_XP[veteran_level - 1]
	return [xp - floor_xp, VETERAN_XP[veteran_level] - floor_xp]


## Erfahrung gutschreiben (nur eigene Einheiten). Steigt die Stufe, wird die Einheit stärker und
## bekommt ab Stufe 5 ihre Veteranenfähigkeit.
func gain_xp(amount: int) -> void:
	if summoned:
		if is_instance_valid(summoner):
			summoner.gain_xp(amount)
		return
	if team != Team.PLAYER or amount <= 0:
		return
	set_xp(xp + amount, true)


## Erfahrung setzen (z.B. beim Verbinden: das Ergebnis behält die Erfahrung der erfahreneren Zutat).
func set_xp(value: int, announce := false) -> void:
	xp = mini(value, VETERAN_XP[VETERAN_MAX - 1])
	var new_level := 1
	for index in VETERAN_XP.size():
		if xp >= VETERAN_XP[index]:
			new_level = index + 1
	if new_level == veteran_level:
		return
	var gained := new_level > veteran_level
	veteran_level = new_level
	veteran_ability = _pick_veteran_ability() if veteran_level >= VETERAN_ABILITY_LEVEL else &""
	refresh_blessings()
	if gained and announce:
		heal(max_health * 0.25)
		var text := tr("Veteran %d!") % veteran_level
		if veteran_level == VETERAN_ABILITY_LEVEL:
			text = tr("Neue Fähigkeit: %s") % Abilities.display_name(veteran_ability)
		_spawn_effect(&"text", position + Vector2(0, -body_size - 18.0), 0.0, Color("#c8f0ff"), text)
		_spawn_effect(&"ring", position + Vector2(0, -body_size / 2.0), body_size, Color("#c8f0ff"))
		Achievements.report_max(&"veteran", veteran_level)


func _pick_veteran_ability() -> StringName:
	for id: StringName in VETERAN_ABILITIES[style_group()]:
		if id != ability:
			return id
	return &""


func setup_enemy(data: EnemyData) -> void:
	team = Team.ENEMY
	display_name = data.display_name
	sprite = data.sprite
	anim = _load_anim(sprite)
	color = data.color
	body_size = _sprite_height(data.body_size)
	max_health = data.max_health * Game.health_scale()
	attack = data.attack * Game.damage_scale()
	intelligence = data.intelligence
	attack_range = data.attack_range
	attack_style = data.attack_style
	attack_kind = AttackKinds.for_style(attack_style)
	attack_cooldown = data.attack_cooldown
	move_speed = data.move_speed
	gold_reward = roundi(data.gold_reward * Game.gold_scale() * Game.round_gold_mult())
	is_boss = data.is_boss
	ability = data.ability
	ability_power = data.ability_power
	_set_behavior(data.behavior)
	fx = data.fx.duplicate(true)
	minion_id = data.minion
	_ability_cd = randf_range(2.0, 5.0)
	if not is_boss:  # Sonderregel der Runde (Bosse bleiben, wie sie sind)
		max_health *= Modifiers.value("enemy_hp")
		attack *= Modifiers.value("enemy_damage")
		move_speed *= Modifiers.value("enemy_speed") * Modifiers.value("all_speed")
		gold_reward = maxi(1, roundi(gold_reward * Modifiers.value("gold")))
		if attack_range > RANGED_MIN:
			attack_range *= Modifiers.value("ranged_range")
		scale = Vector2.ONE * Modifiers.value("enemy_scale")
	health = max_health
	_facing_left = true
	_flip = -1.0
	add_to_group(GROUP_ENEMY)
	_groups_changed()


## Elite-Gegner (nach dem Setup aufrufen): mehr Leben und Schaden, etwas größer, dreifache Beute.
func make_elite() -> void:
	if team != Team.ENEMY or is_boss or elite:
		return
	elite = true
	display_name = tr("Elite %s") % display_name
	max_health *= ELITE_HEALTH
	health = max_health
	attack *= ELITE_DAMAGE
	ability_power *= ELITE_DAMAGE
	gold_reward *= ELITE_GOLD
	scale *= ELITE_SCALE
	queue_redraw()


static func _load_anim(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var path := texture.resource_path.replace("/sprites/", "/sprites/anim/")
	return load(path) if path != texture.resource_path and ResourceLoader.exists(path) else null


## Vier Bilder Stehen oder Laufen als AnimatedTexture (für Oberflächen), ohne Streifen das Einzelbild.
## AnimatedTexture beachtet keine AtlasTexture-Ausschnitte, deshalb eigene Bilder je Frame.
static func frames_texture(texture: Texture2D, running: bool) -> Texture2D:
	var strip := _load_anim(texture)
	if strip == null:
		return texture
	var image := strip.get_image()
	var frame_w := image.get_width() / ANIM_FRAMES
	var frames := AnimatedTexture.new()
	frames.frames = 4
	for i in 4:
		var region := Rect2i(frame_w * (i + (4 if running else 0)), 0, frame_w, image.get_height())
		frames.set_frame_texture(i, ImageTexture.create_from_image(image.get_region(region)))
		frames.set_frame_duration(i, 0.11 if running else IDLE_FRAME_SECONDS)
	return frames


## Aktuelles Bild im Streifen: Laufen nach Schrittphase, sonst Stehen nach Zeit.
func _current_frame() -> int:
	if _attack_anim_left > 0.0:
		return ATTACK_FRAME + mini(int((1.0 - _attack_anim_left / ATTACK_ANIM_SECONDS) * 4.0), 3)
	if _walk_phase != 0.0:
		return 4 + int(_walk_phase * RUN_FRAMES_PER_RADIAN) % 4
	return int(_anim_clock / IDLE_FRAME_SECONDS) % 4


func _sprite_height(fallback: float) -> float:
	return float(sprite.get_height()) if sprite != null else fallback


func _face(point_x: float) -> void:
	var left := point_x < position.x
	if absf(point_x - position.x) > FACE_DEADZONE and left != _facing_left:
		_facing_left = left


func center() -> Vector2:
	return position + Vector2(0, -body_size / 2.0)


func give_order(point: Vector2) -> void:
	has_order = true
	order_position = point
	guard_target = null
	attack_target = null


## Position halten: an Ort und Stelle bleiben, nur angreifen, was in Reichweite kommt.
func hold_position() -> void:
	give_order(position)


func guard(other: Combatant) -> void:
	has_order = false
	guard_target = other
	attack_target = null


## Gegner gezielt angreifen. Heiler greifen nicht an, sie kämpfen frei weiter (heilen).
func attack_unit(enemy: Combatant) -> void:
	clear_order()
	if attack_style != &"heal":
		attack_target = enemy


func clear_order() -> void:
	has_order = false
	guard_target = null
	attack_target = null


func is_attacking() -> bool:
	return attack_target != null and is_instance_valid(attack_target) and attack_target._alive


func is_guarding() -> bool:
	return guard_target != null and is_instance_valid(guard_target) and guard_target._alive


## &"free" (Freikampf), &"hold" (Position halten), &"guard" (Schützen) oder &"attack" (Angriffsziel).
func order_mode() -> StringName:
	if is_guarding():
		return &"guard"
	if is_attacking():
		return &"attack"
	return &"hold" if has_order else &"free"


func order_text() -> String:
	match order_mode():
		&"hold":
			return tr("  [Halten]")
		&"guard":
			return tr("  [Schützt %s]") % guard_target.display_name
		&"attack":
			return tr("  [Greift %s an]") % attack_target.display_name
	return ""


## Nach der Runde: volle Lebenspunkte und alle Kampf-Animationen zurücksetzen, sonst bliebe
## z.B. eine halbe Drehung (schmales Sprite) oder ein Schwertschwung stehen.
func reset_after_battle() -> void:
	_hop_t = -1.0
	_wander_point = Vector2.ZERO
	_wander_wait = 0.0
	health = max_health
	clear_order()
	_target = null
	_velocity = Vector2.ZERO
	_walking = false
	_walk_phase = 0.0
	_swing_left = 0.0
	_effects.clear()
	_forced_target = null
	_ability_cd = randf_range(2.0, 5.0)
	_veteran_cd = randf_range(3.0, 6.0)
	modulate = Color.WHITE
	_flip = -1.0 if _facing_left else 1.0
	behavior_left = 0.0
	_attack_anim_left = 0.0
	if unit_data != null:  # Sonderregel der Runde zurücknehmen
		attack_range = _base_range()
		move_speed = _base_speed()
	queue_redraw()


## Kampfbeginn: Sonderregel der Runde auf die eigene Einheit anwenden (reset_after_battle nimmt sie zurück).
func apply_round_modifier() -> void:
	if unit_data == null:
		return
	attack_range = _base_range()
	if attack_range > RANGED_MIN:
		attack_range *= Modifiers.value("ranged_range")
	move_speed = _base_speed() * Modifiers.value("all_speed")
	# Merkmale: Eröffnungsschlag und Wiederaufstehen gelten je Kampf, Schutz zu Kampfbeginn
	_opened = false
	_revived = false
	_trait_aura_left = randf() * Traits.AURA_INTERVAL
	if fx.has("start_shield"):
		apply_effect(&"shield", float(fx["start_shield"][1]), float(fx["start_shield"][0]))


## Fläche, auf der die Figur angetippt werden kann (gezeichnetes Sprite plus Rand), in Elternkoordinaten.
func hit_rect(margin := 4.0) -> Rect2:
	var size := sprite.get_size() if sprite != null else Vector2(body_size, body_size)
	return Rect2(position + Vector2(-size.x / 2.0, -size.y), size).grow(margin)


## `over_time`: Gift, Brand oder Dornen: kein Ausweichen, kein Funke, keine Gegenwirkung.
func take_damage(amount: float, source: Combatant = null, over_time := false) -> void:
	if not _alive:
		return
	var valid_source := source != null and is_instance_valid(source)
	if not over_time and ability == &"evasion" and randf() < minf(0.5, 0.08 * ability_power):
		return
	if not fx.is_empty() and not over_time:
		if fx.has("dodge") and randf() < float(fx["dodge"]):
			return
		if fx.has("block") and valid_source and AttackKinds.is_melee(source.attack_kind) and randf() < float(fx["block"]):
			if Effect.can_spawn_ambient():
				_spawn_effect(&"ring", position + Vector2(0, -body_size / 2.0), body_size * 0.5, Color("#eef3ff"))
			return
	if has_effect(&"mark"):
		amount *= effect_value(&"mark")
	if has_effect(&"guard"):  # Schutz-Aura eines Verbündeten (unsichtbar, anders als der Schild)
		amount *= effect_value(&"guard")
	if not fx.is_empty():
		amount *= 1.0 - float(fx.get("reduce", 0.0))
		if fx.has("last_stand") and health < max_health / 3.0:
			amount *= 1.0 - float(fx["last_stand"])
		if fx.has("thorns") and valid_source and not over_time and AttackKinds.is_melee(source.attack_kind) and amount > 0.0:
			source.take_damage(amount * float(fx["thorns"]), self, true)
	if ability == &"armor":
		amount *= 1.0 - minf(0.5, 0.1 * ability_power)
	if has_effect(&"shield"):
		amount *= effect_value(&"shield")
	if valid_source and not over_time:
		if source.ability == &"lifesteal":
			source.heal(amount * minf(0.6, 0.15 * source.ability_power))
		if ability == &"thorns" and source.attack_style == &"melee" and amount > 0.0:
			source.take_damage(amount * minf(0.5, 0.12 * ability_power), self, true)
	health -= amount
	if valid_source and not over_time and source.ability == &"execute" and not is_boss and health > 0.0 \
			and health < max_health * minf(0.3, 0.1 + 0.03 * source.ability_power):
		health = 0.0
		_spawn_effect(&"text", position + Vector2(0, -body_size - 4.0), 0.0, Color("#ffd91f"), tr("Gerichtet!"))
	queue_redraw()
	if amount > 0.0 and not over_time and Effect.can_spawn_ambient():
		_spawn_effect(&"spark", center(), randf() * TAU, Color(1.0, 0.95, 0.7))
	if health <= 0.0 and _alive and fx.has("revive") and not _revived:
		# Merkmal: einmal je Kampf wieder aufstehen statt zu fallen
		_revived = true
		health = max_health * float(fx["revive"])
		_effects.erase(&"poison")
		_spawn_effect(&"ring", position + Vector2(0, -body_size / 2.0), body_size, Color("#fff3a0"))
		_spawn_effect(&"text", position + Vector2(0, -body_size - 10.0), 0.0, Color("#fff3a0"), Traits.display_name(_revive_trait()))
		return
	if health <= 0.0 and _alive:
		if Effect.can_spawn_ambient():
			_spawn_effect(&"puff", position + Vector2(0, -body_size * 0.3), randf() * TAU, Color(0.8, 0.75, 0.7) if team == Team.ENEMY else Color(0.9, 0.85, 1.0))
		Sound.play(&"death")
		_alive = false
		_leave_group()
		if team == Team.ENEMY and source != null and is_instance_valid(source):
			source.gain_xp(XP_BOSS if is_boss else XP_KILL)
		if source != null and is_instance_valid(source):
			source._on_kill(self)
		if fx.has("death_blast"):
			var blast: Array = fx["death_blast"]
			for foe in _opponents_near(position, float(blast[1])):
				foe.take_damage(attack * float(blast[0]), null)
			_spawn_effect(&"burst", position, float(blast[1]), Color("#ff8a1f"))
		DeathAnim.spawn(self)
		died.emit(self)
		queue_free()


## Entfernt die Einheit sofort aus allen Zählungen (z.B. beim Verbinden).
func discard() -> void:
	_alive = false
	_leave_group()
	queue_free()


func _leave_group() -> void:
	remove_from_group(GROUP_PLAYER if team == Team.PLAYER else GROUP_ENEMY)
	_groups_changed()


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE or what == NOTIFICATION_EXIT_TREE:
		_groups_changed()


static func _groups_changed() -> void:
	_members.clear()
	_grid_frame = -1


## Alle Figuren der Gruppe, wie get_nodes_in_group, aber ohne jedes Mal ein neues Array.
## Nicht verändern: das Array wird geteilt.
func _group(group: StringName) -> Array:
	if not _members.has(group):
		_members[group] = get_tree().get_nodes_in_group(group)
	return _members[group]


## Figuren der Gruppe in den Rasterzellen um `point` (für kurze Abstände).
func _nearby(group: StringName, point: Vector2) -> Array[Combatant]:
	var frame := Engine.get_physics_frames()
	if _grid_frame != frame:
		_grid_frame = frame
		_grids.clear()
	if not _grids.has(group):
		var grid := {}
		for node in _group(group):
			var cell := Vector2i(((node as Combatant).position / GRID_CELL).floor())
			if not grid.has(cell):
				grid[cell] = [] as Array[Combatant]
			(grid[cell] as Array[Combatant]).append(node as Combatant)
		_grids[group] = grid
	var cells: Dictionary = _grids[group]
	var center_cell := Vector2i((point / GRID_CELL).floor())
	var result: Array[Combatant] = []
	for x in range(-1, 2):
		for y in range(-1, 2):
			var cell: Array = cells.get(center_cell + Vector2i(x, y), [])
			result.append_array(cell)
	return result


## Bauphase: Eigene Einheiten hüpfen ab und zu und schauen mal in die andere Richtung.
func _process(delta: float) -> void:
	if _attack_anim_left > 0.0:
		_attack_anim_left -= Game.battle_delta(delta) if Game.phase == Game.Phase.BATTLE else delta
	if anim != null:
		_anim_clock += delta
		var frame := _current_frame()
		if frame != _anim_frame:
			_anim_frame = frame
			queue_redraw()
	if Game.phase != Game.Phase.BUILD or team != Team.PLAYER or highlighted:
		if _hop_t >= 0.0:
			_hop_t = -1.0
			queue_redraw()
		return
	if _hop_t >= 0.0:
		_hop_t += delta / IDLE_HOP_SECONDS
		if _hop_t >= 1.0:
			_hop_t = -1.0
		queue_redraw()
	else:
		_idle_left -= delta
		if _idle_left <= 0.0:
			_hop_t = 0.0
			_idle_left = randf_range(1.5, 5.0)
			if randf() < 0.35:
				_facing_left = not _facing_left
	var target := -1.0 if _facing_left else 1.0
	if not is_equal_approx(_flip, target):
		_flip = move_toward(_flip, target, FLIP_SPEED * delta)
		queue_redraw()


func _physics_process(frame_delta: float) -> void:
	if Game.phase != Game.Phase.BATTLE or not _alive:
		return
	var delta := Game.battle_delta(frame_delta)
	if summoned:
		_summon_left -= delta
		if _summon_left <= 0.0:
			_spawn_effect(&"puff", position + Vector2(0, -body_size * 0.3), randf() * TAU, Color(0.8, 0.75, 1.0))
			discard()
			return
	_cooldown_left -= delta
	_update_effects(delta)
	if not _alive:
		return
	if has_effect(&"stun"):  # betäubt, versteinert oder betört: steht still
		_walking = false
		position = _clamp(position + _separation() * delta)
		_animate(delta)
		return
	_update_ability(delta)
	if _swing_left > 0.0:
		_swing_left -= delta
		queue_redraw()
	_walking = false

	if guard_target != null and not is_guarding():
		guard_target = null  # Schützling ist gefallen: zurück in den Freikampf
	if attack_target != null and not is_attacking():
		attack_target = null  # Ziel ist gefallen: zurück in den Freikampf
	if has_order and position.distance_to(order_position) > ARRIVE_DISTANCE:
		_move_towards(order_position, delta)
	elif is_guarding():
		_guard(delta)
	else:
		_fight(delta)
	position = _clamp(position + _separation() * delta)
	_animate(delta)


func _fight(delta: float) -> void:
	if is_instance_valid(_forced_target) and _forced_target._alive and _forced_left > 0.0:
		_target = _forced_target
		_retarget_left = RETARGET_INTERVAL
	if attack_style == &"heal":
		_heal_allies(delta)
		return
	if attack_target != null:
		_target = attack_target
		_retarget_left = RETARGET_INTERVAL
	_retarget_left -= delta
	if not is_instance_valid(_target) or not _target._alive or _retarget_left <= 0.0:
		var picked := Behaviors.pick_target(self) if _steers or behavior == &"assassin" else null
		_target = picked if picked != null else _find_target()
		_retarget_left = RETARGET_INTERVAL
	if _target == null:
		if team == Team.PLAYER and not has_order:
			_wander(delta)
		return
	var distance := position.distance_to(_target.position)
	_face(_target.position.x)
	if _steers and Behaviors.steer(self, delta, _target, distance):
		return
	if distance > attack_range:
		# Mit Befehl wird die Stellung gehalten, nur im Automatikmodus wird verfolgt.
		if not has_order:
			_move_towards(_target.position, delta)
	else:
		try_attack(_target, distance)


## Angreifen, wenn das Ziel in Reichweite und die Abklingzeit vorbei ist (auch für Behaviors.steer).
func try_attack(target: Combatant, distance: float) -> bool:
	if distance > attack_range or _cooldown_left > 0.0 or not is_instance_valid(target):
		return false
	_target = target
	_cooldown_left = attack_cooldown / effect_value(&"haste")
	_attack_target()
	Behaviors.after_attack(self)
	return true


func _attack_target() -> void:
	var damage := attack * damage_mult()
	if ability == &"crit" and randf() < minf(0.4, 0.08 * ability_power):
		damage *= 2.0
		_spawn_effect(&"text", position + Vector2(0, -body_size - 4.0), 0.0, Color("#ff8a1f"), tr("Kritisch!"))
	if has_effect(&"charge"):  # Sturmangriff: erster Treffer doppelt und betäubt
		_effects.erase(&"charge")
		damage *= 2.0
		_target.apply_effect(&"stun", 1.0, 1.0)
	_attack_anim_left = ATTACK_ANIM_SECONDS
	Sound.play(AttackKinds.sound(attack_kind))
	if AttackKinds.is_melee(attack_kind):
		_swing_dir = (_target.center() - center()).normalized()
		_swing_left = SWING_SECONDS
		queue_redraw()
		land_hit(self, _target, damage, attack_kind)
		return
	if AttackKinds.is_instant(attack_kind):
		_spawn_effect(&"bolt", center(), 0.0, AttackKinds.INFO[attack_kind]["color"], "", _target.center() - center())
		land_hit(self, _target, damage, attack_kind)
		return
	var shot := Projectile.new()
	shot.setup(center(), _target, attack_kind, color, damage, self)
	get_parent().add_child(shot)


## Ein Treffer von `source` (null, wenn schon gefallen) auf `target`: Merkmale des Angreifers verändern
## den Schaden, danach wirken Angriffsform und Merkmale nach. Nahkampf direkt, Fernkampf beim Einschlag.
static func land_hit(source: Combatant, target: Combatant, damage: float, kind: StringName) -> void:
	if not is_instance_valid(target) or not target.is_alive():
		return
	var by: Combatant = source if is_instance_valid(source) else null
	if by != null:
		damage = by._outgoing_damage(target, damage)
	target.take_damage(damage, by)
	# Zusatzwirkung der Angriffsform nur bei eigenen Einheiten: Gegner bleiben so stark wie bisher.
	if by != null and by.team == Team.PLAYER:
		AttackKinds.after_hit(kind, by, target, damage)
		by._after_hit_traits(target, damage)


## Merkmale, die den eigenen Schaden verändern (vor dem Treffer).
func _outgoing_damage(target: Combatant, damage: float) -> float:
	if fx.is_empty():
		return damage
	if fx.has("opener") and not _opened:
		damage *= float(fx["opener"])
	_opened = true
	if fx.has("crit") and randf() < float(fx["crit"][0]):
		damage *= float(fx["crit"][1])
		_spawn_effect(&"text", position + Vector2(0, -body_size - 4.0), 0.0, Color("#ff8a1f"), tr("Kritisch!"))
	if target.is_boss:
		damage *= float(fx.get("boss", 1.0))
	elif fx.has("execute") and target.health - damage < target.max_health * float(fx["execute"]):
		damage = maxf(damage, target.health + 1.0)
	return damage


## Merkmale, die nach einem Treffer wirken (Brand, Rückstoß, Fläche, Überspringen ...).
func _after_hit_traits(target: Combatant, damage: float) -> void:
	if fx.is_empty():
		return
	if fx.has("burn"):
		target.poison(attack * float(fx["burn"][0]), float(fx["burn"][1]), self)
	if fx.has("slow"):
		target.apply_effect(&"slow", float(fx["slow"][1]), float(fx["slow"][0]))
	if fx.has("stun") and randf() < float(fx["stun"][0]):
		target.apply_effect(&"stun", float(fx["stun"][1]), 1.0)
	if fx.has("weaken"):
		target.apply_effect(&"weak", float(fx["weaken"][1]), float(fx["weaken"][0]))
	if fx.has("mark"):
		target.apply_effect(&"mark", float(fx["mark"][1]), 1.0 + float(fx["mark"][0]))
	if fx.has("knock"):
		AttackKinds._push(target, self, float(fx["knock"]))
	if fx.has("leech"):
		heal(damage * float(fx["leech"]))
	if fx.has("splash"):
		for other in AttackKinds._others_near(target, target.position, float(fx["splash"][1])):
			other.take_damage(damage * float(fx["splash"][0]), self)
	if fx.has("chain"):
		var from := target
		var hit: Array[Combatant] = [target]
		for jump in int(fx["chain"][1]):
			var next: Combatant = null
			for other in AttackKinds._others_near(from, from.position, 50.0):
				if not hit.has(other):
					next = other
					break
			if next == null:
				break
			_spawn_effect(&"bolt", from.center(), 0.0, Color("#bfe6ff"), "", next.center() - from.center())
			next.take_damage(damage * float(fx["chain"][0]), self)
			hit.append(next)
			from = next
	if fx.has("double") and randf() < float(fx["double"]) and target.is_alive():
		target.take_damage(damage * 0.5, self)


## Merkmale beim Sieg über `victim`.
func _on_kill(_victim: Combatant) -> void:
	if fx.is_empty() or not _alive:
		return
	if fx.has("kill_heal"):
		heal(max_health * float(fx["kill_heal"]))
	if fx.has("kill_haste"):
		apply_effect(&"haste", float(fx["kill_haste"]), 1.6)
	if fx.has("kill_gold") and team == Team.PLAYER:
		Game.add_gold(int(fx["kill_gold"]))
		Game.count_stat("gold", int(fx["kill_gold"]))
	if fx.has("kill_rally"):
		for ally in _allies_near(position, 60.0):
			ally.apply_effect(&"buff", float(fx["kill_rally"][1]), 1.0 + float(fx["kill_rally"][0]))


## Auren der Merkmale, jede Sekunde im Umkreis.
func _trait_aura(delta: float) -> void:
	_trait_aura_left -= delta
	if _trait_aura_left > 0.0:
		return
	_trait_aura_left = Traits.AURA_INTERVAL
	var radius := Traits.AURA_RADIUS
	if fx.has("aura_heal") or fx.has("aura_guard") or fx.has("aura_haste"):
		for ally in _allies_near(position, radius):
			if fx.has("aura_heal") and ally.health < ally.max_health:
				ally.heal(ally.max_health * float(fx["aura_heal"]), self)
			if fx.has("aura_guard"):
				ally.apply_effect(&"guard", Traits.AURA_INTERVAL + 0.2, float(fx["aura_guard"]))
			if fx.has("aura_haste"):
				ally.apply_effect(&"haste", Traits.AURA_INTERVAL + 0.2, float(fx["aura_haste"]))
	if fx.has("aura_burn") or fx.has("aura_chill"):
		for foe in _opponents_near(position, radius):
			if fx.has("aura_burn"):
				foe.take_damage(attack * float(fx["aura_burn"]), self, true)
			if fx.has("aura_chill"):
				foe.apply_effect(&"slow", Traits.AURA_INTERVAL + 0.2, float(fx["aura_chill"]))


## Ohne Gegner in der Nähe der Heimatposition herumstreifen: kurz laufen, kurz verschnaufen.
func _wander(delta: float) -> void:
	if _wander_wait > 0.0:
		_wander_wait -= delta
		return
	if _wander_point == Vector2.ZERO or position.distance_to(_wander_point) < 3.0:
		_wander_point = World.clamp_point(home_position + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * WANDER_RADIUS)
		_wander_wait = randf_range(0.2, 1.6)
		return
	_move_towards(_wander_point, delta, WANDER_SPEED_FACTOR)


## Schützen: Gegner in der Nähe des Schützlings bekämpfen, sonst an seiner Seite bleiben.
func _guard(delta: float) -> void:
	if attack_style == &"heal":
		_heal_allies(delta)
		return
	_retarget_left -= delta
	if not is_instance_valid(_target) or not _target._alive or _retarget_left <= 0.0:
		_target = _find_threat()
		_retarget_left = RETARGET_INTERVAL
	var anchor := guard_target.position
	if _target == null:
		if position.distance_to(anchor) > GUARD_FOLLOW_DISTANCE:
			_move_towards(anchor, delta)
		return
	_face(_target.position.x)
	if position.distance_to(_target.position) > attack_range:
		# Nicht weiter vom Schützling weglocken lassen, als die Leine reicht.
		_move_towards(anchor if position.distance_to(anchor) > GUARD_LEASH else _target.position, delta)
	elif _cooldown_left <= 0.0:
		_cooldown_left = attack_cooldown / effect_value(&"haste")
		_attack_target()


## Der Gegner, der dem Schützling am nächsten ist (innerhalb von GUARD_ENGAGE).
func _find_threat() -> Combatant:
	var best: Combatant = null
	var best_dist := GUARD_ENGAGE * GUARD_ENGAGE
	for node in _group(GROUP_ENEMY if team == Team.PLAYER else GROUP_PLAYER):
		var dist := guard_target.position.distance_squared_to((node as Combatant).position)
		if dist <= best_dist:
			best_dist = dist
			best = node as Combatant
	return best


## Heiler: verletzten Verbündeten suchen, hinlaufen und heilen. Ohne Patient bei den Verbündeten bleiben.
func _heal_allies(delta: float) -> void:
	_retarget_left -= delta
	if not is_instance_valid(_target) or not _target._alive or _target.health >= _target.max_health \
			or _retarget_left <= 0.0:
		_target = _find_patient()
		_retarget_left = RETARGET_INTERVAL
	if _target == null:
		_follow_allies(delta)
		return
	_face(_target.position.x)
	if position.distance_to(_target.position) > attack_range:
		if not has_order:
			_move_towards(_target.position, delta)
	elif _cooldown_left <= 0.0:
		_cooldown_left = attack_cooldown / effect_value(&"haste")
		_attack_anim_left = ATTACK_ANIM_SECONDS
		Sound.play(&"heal")
		if AttackKinds.is_instant(attack_kind):  # Segensstrahl: heilt sofort
			_spawn_effect(&"bolt", center(), 0.0, AttackKinds.INFO[attack_kind]["color"], "", _target.center() - center())
			_target.heal(attack, self)
			return
		var spell := Projectile.new()
		spell.setup(center(), _target, attack_kind, color, attack, self)
		get_parent().add_child(spell)


## Verletzter Verbündeter (auch man selbst): schlaue Heiler nehmen den mit dem kleinsten
## Lebensanteil, die anderen den nächsten.
func _find_patient() -> Combatant:
	if is_guarding() and guard_target.health < guard_target.max_health:
		return guard_target
	var group := GROUP_PLAYER if team == Team.PLAYER else GROUP_ENEMY
	var nearest: Combatant = null
	var nearest_dist := INF
	var neediest: Combatant = null
	var lowest := INF
	for node in _group(group):
		var other := node as Combatant
		if other.health >= other.max_health:
			continue
		var dist := position.distance_squared_to(other.position)
		if has_order and dist > attack_range * attack_range:
			continue
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = other
		if other.health / other.max_health < lowest:
			lowest = other.health / other.max_health
			neediest = other
	if randf() * 100.0 < minf(intelligence, MAX_SMART_CHANCE):
		return neediest
	return nearest


func _follow_allies(delta: float) -> void:
	if has_order:
		return
	if is_guarding():
		if position.distance_to(guard_target.position) > GUARD_FOLLOW_DISTANCE:
			_move_towards(guard_target.position, delta)
		return
	var group := GROUP_PLAYER if team == Team.PLAYER else GROUP_ENEMY
	var nearest: Combatant = null
	var nearest_dist := INF
	for node in _group(group):
		var other := node as Combatant
		if other == self or other.attack_style == &"heal":
			continue
		var dist := position.distance_to(other.position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = other
	if nearest != null and nearest_dist > HEALER_FOLLOW_DISTANCE:
		_move_towards(nearest.position, delta)


## Heilen. Ein eigener Heiler (`healer`) bekommt für echte Heilung Erfahrung.
func heal(amount: float, healer: Combatant = null) -> void:
	var healed := minf(max_health, health + amount) - health
	health += healed
	queue_redraw()
	if healed > 0.0 and is_instance_valid(healer) and healer != self and team == Team.PLAYER:
		healer.gain_heal_xp(healed / max_health)


## Heilerfahrung sammeln: bruchstückweise, jeder volle Punkt zählt wie ein Sieg.
func gain_heal_xp(fraction: float) -> void:
	_heal_xp_pool += fraction * XP_HEAL_PER_FULL
	if _heal_xp_pool >= 1.0:
		var whole := int(_heal_xp_pool)
		_heal_xp_pool -= whole
		gain_xp(whole)


## Boss wird wütend (Zeit abgelaufen): mehr Schaden und Tempo.
func enrage() -> void:
	attack *= 1.6
	move_speed *= 1.3
	attack_cooldown *= 0.8
	modulate = Color(1.0, 0.6, 0.55)


func is_alive() -> bool:
	return _alive


func _move_towards(point: Vector2, delta: float, speed_factor := 1.0) -> void:
	_face(point.x)
	# Die Laufrichtung folgt dem Ziel weich, damit ein neues Ziel keinen Ruck auslöst.
	hop_clock += delta
	var distance := position.distance_to(point)
	var speed := current_speed() * speed_factor
	var desired := (point - position).normalized() * minf(speed, distance / maxf(delta, 0.001))
	if _hops:
		desired *= Behaviors.speed_factor(self)
	_velocity = _velocity.move_toward(desired, maxf(speed, 1.0) * TURN_ACCELERATION * delta)
	position = _clamp(position + _velocity * delta)
	_walking = true


## Laufen für Behaviors (Rückzug, Bogen, Wächter).
func move_towards(point: Vector2, delta: float, speed_factor := 1.0) -> void:
	_move_towards(point, delta, speed_factor)


func is_walking() -> bool:
	return _walking


## Alle Gegner bzw. Verbündeten (geteilte Liste, nicht verändern).
func foes() -> Array:
	return _group(GROUP_ENEMY if team == Team.PLAYER else GROUP_PLAYER)


func allies() -> Array:
	return _group(GROUP_PLAYER if team == Team.PLAYER else GROUP_ENEMY)


## Im Kreuz halten; Schweber gleiten über Hindernisse.
func _clamp(point: Vector2) -> Vector2:
	return World.clamp_to_floor(point) if _floats else World.clamp_point(point)


## Merkmal, das das Wiederaufstehen bringt (für die Anzeige).
func _revive_trait() -> StringName:
	if unit_data != null:
		for id in unit_data.traits:
			if Traits.INFO.has(id) and Traits.INFO[id]["fx"].has("revive"):
				return id
	return &""


## Spiegelung und Laufwippen pro Physik-Schritt weiterführen.
func _animate(delta: float) -> void:
	if not _walking:
		_velocity = Vector2.ZERO
	var target := -1.0 if _facing_left else 1.0
	if not is_equal_approx(_flip, target):
		_flip = move_toward(_flip, target, FLIP_SPEED * delta)
		queue_redraw()
	if _walking:
		_walk_phase += delta * current_speed() * WALK_STEP_RATE
		queue_redraw()
	elif _walk_phase != 0.0:
		_walk_phase = 0.0
		queue_redraw()


# --- Fähigkeiten und Wirkungen -------------------------------------------------------

func has_effect(effect_name: StringName) -> bool:
	return _effects.has(effect_name)


func effect_value(effect_name: StringName) -> float:
	return _effects[effect_name][1] if _effects.has(effect_name) else 1.0


## Wirkung (re)starten. Länger gewinnt bei der Zeit, bei Verlangsamung der stärkere (kleinere) Wert,
## sonst der größere.
func apply_effect(effect_name: StringName, seconds: float, value := 1.0) -> void:
	if effect_name == &"stun" and is_boss:
		seconds *= BOSS_STUN_FACTOR
	if _effects.has(effect_name):
		var old: Array = _effects[effect_name]
		var better := minf(old[1], value) if effect_name in [&"slow", &"shield", &"weak", &"guard"] else maxf(old[1], value)
		_effects[effect_name] = [maxf(old[0], seconds), better]
	else:
		_effects[effect_name] = [seconds, value]
	queue_redraw()


## Gegner zwingen, kurz diese Einheit anzugreifen (Spott).
func force_target(unit: Combatant, seconds: float) -> void:
	_forced_target = unit
	_forced_left = seconds


func current_speed() -> float:
	return move_speed * _speed_jitter * effect_value(&"sprint") * effect_value(&"slow") * effect_value(&"charge")


func damage_mult() -> float:
	return (1.0 + (effect_value(&"buff") - 1.0 if has_effect(&"buff") else 0.0)) * effect_value(&"weak")


## Gift oder Brand: `dps` Schaden pro Sekunde für `seconds`, Erfahrung bekommt `source`.
func poison(dps: float, seconds: float, source: Combatant) -> void:
	_poison_source = source
	apply_effect(&"poison", seconds, dps)


func _update_effects(delta: float) -> void:
	var changed := false
	for effect_name: StringName in _effects.keys():
		_effects[effect_name][0] -= delta
		if _effects[effect_name][0] <= 0.0:
			_effects.erase(effect_name)
			changed = true
	if _forced_left > 0.0:
		_forced_left -= delta
	if has_effect(&"poison"):
		take_damage(effect_value(&"poison") * delta, _poison_source if is_instance_valid(_poison_source) else null, true)
		if not _alive:
			return
	if not fx.is_empty():
		_trait_aura(delta)
		if not _alive:
			return
	if ability == &"regen" and health < max_health:
		heal(max_health * 0.012 * ability_power * delta)
	if team == Team.PLAYER and health < max_health and Modifiers.value("regen") > 0.0:
		heal(max_health * Modifiers.value("regen") * delta)
	var tint := Color(1.0, 0.6, 0.55) if is_boss and Game.boss_enraged else (Color(1.0, 0.9, 0.62) if elite else Color.WHITE)
	if has_effect(&"stun"):
		tint = Color(0.7, 0.7, 0.7) if effect_value(&"stun") < 2.0 else Color(1.0, 0.7, 0.95)
	elif has_effect(&"weak"):
		tint = Color(0.8, 0.6, 1.0)
	elif has_effect(&"poison"):
		tint = Color(0.7, 1.0, 0.55)
	elif has_effect(&"slow"):
		tint = Color(0.6, 0.8, 1.0)
	elif has_effect(&"buff"):
		tint = Color(1.0, 0.8, 0.7)
	if modulate != tint:
		modulate = tint
	if changed:
		queue_redraw()


func _opponents_near(point: Vector2, radius: float) -> Array[Combatant]:
	return _units_near(GROUP_ENEMY if team == Team.PLAYER else GROUP_PLAYER, point, radius)


## Verbündete im Umkreis, die Einheit selbst eingeschlossen.
func _allies_near(point: Vector2, radius: float) -> Array[Combatant]:
	return _units_near(GROUP_PLAYER if team == Team.PLAYER else GROUP_ENEMY, point, radius)


func _units_near(group: StringName, point: Vector2, radius: float) -> Array[Combatant]:
	var result: Array[Combatant] = []
	for node in _group(group):
		if (node as Combatant).position.distance_squared_to(point) <= radius * radius:
			result.append(node as Combatant)
	return result


func _update_ability(delta: float) -> void:
	if veteran_ability != &"":
		_veteran_cd -= delta
		if _veteran_cd <= 0.0 and Game.auto_abilities:
			cast_veteran()
	if ability == &"":
		return
	if not Abilities.is_active(ability):
		_aura_left -= delta
		if _aura_left <= 0.0:
			_aura_left = AURA_INTERVAL
			_apply_aura()
		return
	_ability_cd -= delta
	if _ability_cd <= 0.0 and (Game.auto_abilities or team != Team.PLAYER):
		cast_now()


func ability_ready() -> bool:
	return Abilities.is_active(ability) and _ability_cd <= 0.0


## Sekunden bis die aktive Fähigkeit wieder bereit ist.
func ability_cooldown_left() -> float:
	return maxf(_ability_cd, 0.0)


## Aktive Fähigkeit jetzt auslösen (Automatik oder Knopf). false, wenn sie lädt oder ihre Bedingung
## (z.B. ein Gegner in der Nähe) nicht erfüllt ist.
func cast_now() -> bool:
	if not ability_ready() or not AbilityCasts.cast(self, ability):
		return false
	_ability_cd = Abilities.cooldown(ability) * (Modifiers.value("ability_cd") if team == Team.PLAYER else 1.0)
	ability_casts += 1
	_spawn_effect(&"text", position + Vector2(0, -body_size - 10.0), 0.0, Color("#ffe27a"), Abilities.display_name(ability))
	return true


func veteran_ready() -> bool:
	return veteran_ability != &"" and _veteran_cd <= 0.0


func veteran_cooldown_left() -> float:
	return maxf(_veteran_cd, 0.0)


## Veteranenfähigkeit auslösen (Automatik oder Knopf), wie cast_now().
func cast_veteran() -> bool:
	if not veteran_ready() or not AbilityCasts.cast(self, veteran_ability):
		return false
	_veteran_cd = Abilities.cooldown(veteran_ability) * 1.5 * Modifiers.value("ability_cd")
	ability_casts += 1
	_spawn_effect(&"text", position + Vector2(0, -body_size - 10.0), 0.0, Color("#c8f0ff"), Abilities.display_name(veteran_ability))
	return true


func _apply_aura() -> void:
	match ability:
		&"slow_aura":
			for foe in _opponents_near(position, AURA_RADIUS):
				foe.apply_effect(&"slow", AURA_INTERVAL + 0.3, 1.0 - minf(0.6, 0.25 + 0.07 * ability_power))
		&"war_aura":
			for ally in _allies_near(position, AURA_RADIUS):
				if ally != self:
					ally.apply_effect(&"buff", AURA_INTERVAL + 0.3, 1.0 + minf(0.6, 0.1 * ability_power))


func _spawn_bolt(from: Vector2, to: Vector2) -> void:
	_spawn_effect(&"bolt", from, 0.0, Color("#bfe6ff"), "", to - from)


func _spawn_effect(kind: StringName, at: Vector2, radius: float, tint: Color, text := "", direction := Vector2.ZERO) -> void:
	if get_parent() == null:
		return
	var effect := Effect.new()
	effect.setup(kind, at, radius, tint, text)
	effect.direction = direction
	get_parent().add_child(effect)


func _find_target() -> Combatant:
	var group := GROUP_ENEMY if team == Team.PLAYER else GROUP_PLAYER
	var candidates: Array[Combatant] = []
	var nearest: Combatant = null
	var nearest_dist := INF
	for node in _group(group):
		var other := node as Combatant
		var dist := position.distance_squared_to(other.position)
		if has_order and dist > attack_range * attack_range:
			continue
		candidates.append(other)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = other
	if nearest == null or randf() * 100.0 >= minf(intelligence, MAX_SMART_CHANCE):
		return nearest
	# Schlaue Einheiten: schwächster Gegner, der nicht viel weiter weg ist als der nächste.
	var limit := sqrt(nearest_dist) + SMART_RADIUS
	var weakest := nearest
	for other in candidates:
		if position.distance_to(other.position) <= limit and other.health < weakest.health:
			weakest = other
	return weakest


func _separation() -> Vector2:
	var push := Vector2.ZERO
	var group := GROUP_PLAYER if team == Team.PLAYER else GROUP_ENEMY
	var spacing := body_size * 0.5  # Abstand wie vor den größeren Sprites
	for node in (_nearby(group, position) if spacing < GRID_CELL else _group(group)):
		if node == self:
			continue
		var offset := position - (node as Combatant).position
		var dist := offset.length()
		if dist < spacing:
			push += offset / maxf(dist, 0.01) * (spacing - dist) / spacing * SEPARATION_SPEED
	return push


func _draw() -> void:
	var half := body_size / 2.0
	var rect := Rect2(-half, -body_size, body_size, body_size)
	var swing_t := 1.0 - _swing_left / SWING_SECONDS if _swing_left > 0.0 else 0.0
	var body_offset := Vector2.ZERO
	var tilt := 0.0
	if _swing_left > 0.0:  # kleiner Ausfallschritt zum Ziel
		body_offset = _swing_dir * sin(swing_t * PI) * 3.0
	if _hop_t >= 0.0:  # Leerlauf-Hüpfer in der Bauphase
		body_offset.y -= sin(_hop_t * PI) * IDLE_HOP_HEIGHT
	if _hops:
		body_offset.y -= Behaviors.hop_height(self)  # Hüpfer springen beim Laufen
	if _walk_phase != 0.0:  # Laufen: kleine Hüpfer und leichtes Wiegen (mit Laufbildern nur Wiegen)
		if anim == null:
			body_offset.y -= absf(sin(_walk_phase)) * WALK_BOB
		tilt = sin(_walk_phase) * WALK_TILT * (0.5 if anim != null else 1.0)
	# Spiegeln über die Skalierung: Eine negative Breite in draw_texture_rect würde zwar die
	# Textur umdrehen, aber die linke Kante behalten und das Sprite um seine Breite verschieben.
	draw_set_transform(body_offset, tilt, Vector2(_flip, 1.0))
	if anim != null:
		var frame_size := Vector2(anim.get_width() / float(ANIM_FRAMES), anim.get_height())
		draw_texture_rect_region(anim, Rect2(Vector2(-frame_size.x / 2.0, -frame_size.y), frame_size),
				Rect2(Vector2(frame_size.x * _current_frame(), 0.0), frame_size))
	elif sprite != null:
		var size := sprite.get_size()
		draw_texture_rect(sprite, Rect2(Vector2(-size.x / 2.0, -size.y), size), false)
	else:
		draw_rect(rect, color)
		var outline := Color(0.8, 0.15, 0.15) if team == Team.ENEMY else color.darkened(0.55)
		draw_rect(rect, outline, false, 1.0)
	draw_set_transform(Vector2.ZERO)
	if has_effect(&"shield"):
		draw_arc(Vector2(0, -body_size / 2.0), body_size * 0.62, 0.0, TAU, 20, Color(0.55, 0.9, 1.0, 0.85), 1.5)
	if has_effect(&"sprint"):
		for i in 3:
			draw_line(Vector2(-body_size * 0.5 * _flip - _flip * 2, -body_size * (0.3 + 0.2 * i)), Vector2(-body_size * 0.8 * _flip - _flip * 4, -body_size * (0.3 + 0.2 * i)), Color(1, 1, 1, 0.6), 1.0)
	if _swing_left > 0.0:
		_draw_swing(swing_t)
	if elite:  # goldener Ring am Boden
		draw_set_transform(Vector2(0, -1.0), 0.0, Vector2(1.0, 0.4))
		draw_arc(Vector2.ZERO, body_size * 0.65, 0.0, TAU, 20, Color(1.0, 0.85, 0.25, 0.95), 1.5)
		draw_set_transform(Vector2.ZERO)
	if highlighted:
		draw_rect(rect.grow(2.0), Color.WHITE, false, 1.0)
	elif hovered:
		draw_rect(rect.grow(2.0), Color(1, 1, 1, 0.4), false, 1.0)
	if team == Team.PLAYER:
		for i in level:
			draw_rect(Rect2(-half + i * 3, -body_size - 4, 2, 2), Color.GOLD)
		if veteran_level > 1:
			_draw_veteran_badge(Vector2(half - 1, -body_size - 1))
	if health < max_health:
		var width := maxf(body_size, 12.0)
		var top := -body_size - 8.0
		draw_rect(Rect2(-width / 2.0, top, width, 2), Color(0.2, 0.0, 0.0))
		draw_rect(Rect2(-width / 2.0, top, width * health / max_health, 2), Color(0.2, 0.9, 0.2))


## Abzeichen der Veteranenstufe: Bronze (2-4), Silber (5-9), Gold (10), mit Zahl.
func _draw_veteran_badge(at: Vector2) -> void:
	var tint := Color("#c98a4b") if veteran_level < VETERAN_ABILITY_LEVEL else \
			(Color("#dfe6f2") if veteran_level < VETERAN_MAX else Color("#ffd91f"))
	var box := Rect2(at - Vector2(4, 5), Vector2(9, 8))
	draw_rect(box.grow(1.0), Color("#24123a"))
	draw_rect(box, tint)
	var font := ThemeDB.fallback_font
	draw_string(font, at + Vector2(-3.5 if veteran_level < 10 else -4.5, 2), str(veteran_level),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("#24123a"))


## Nahkampf sichtbar machen, je nach Angriffsform (siehe AttackKinds): Schwert, Axt, Keule, Krallen,
## Biss, Totengriff, Zunge oder Speer. Stampfer und Huftritt zeigen nur die Körperbewegung.
func _draw_swing(t: float) -> void:
	var pivot := Vector2(0, -body_size * 0.5) + _swing_dir * 4.0
	var base := _swing_dir.angle()
	var fade := 1.0 - t * 0.5
	match attack_kind:
		&"axe", &"club":
			var arc := SWING_ARC * (1.4 if attack_kind == &"axe" else 1.0)
			var angle := base + lerpf(-arc, arc, t)
			var reach := 8.0 + body_size * 0.25
			draw_arc(pivot, reach, base - arc, angle, 10, Color(1, 1, 1, 0.4 * fade), 3.0 if attack_kind == &"club" else 2.0)
			var dir := Vector2.from_angle(angle)
			draw_line(pivot, pivot + dir * reach, Color("#8a5630"), 2.0)
			if attack_kind == &"axe":
				draw_line(pivot + dir * (reach - 3.0) - dir.orthogonal() * 3.0, pivot + dir * reach + dir.orthogonal() * 1.0, Color("#c8ccd8"), 3.0)
			else:
				draw_circle(pivot + dir * reach, 2.5, Color("#6b4a2a"))
		&"claw":
			for i in 3:
				var offset := _swing_dir.orthogonal() * (i - 1) * 3.0
				var start := pivot + offset - _swing_dir * 2.0 + _swing_dir.rotated(-0.6) * 6.0 * t
				draw_line(start, start + _swing_dir.rotated(0.6) * 6.0, Color(1, 0.95, 0.9, fade), 1.0)
		&"bite":
			var open := (1.0 - t) * 0.9
			var tip := pivot + _swing_dir * 8.0
			draw_arc(tip, 4.0, base - PI / 2.0 - open, base - open * 0.3, 6, Color(1, 1, 1, fade), 1.5)
			draw_arc(tip, 4.0, base + open * 0.3, base + PI / 2.0 + open, 6, Color(1, 1, 1, fade), 1.5)
		&"grasp":
			draw_arc(pivot + _swing_dir * 6.0, 5.0 * (1.0 - t * 0.5), 0.0, TAU, 12, Color(0.55, 0.3, 0.8, fade), 2.0)
		&"tongue":
			var reach := attack_range * sin(t * PI)
			draw_line(pivot, pivot + _swing_dir * reach, Color("#ff7aa8"), 2.0)
			draw_circle(pivot + _swing_dir * reach, 1.5, Color("#ff4a88"))
		&"thrust":
			var reach := (8.0 + body_size * 0.3) * (0.4 + 0.8 * sin(t * PI))
			draw_line(pivot - _swing_dir * 4.0, pivot + _swing_dir * reach, Color("#8a5630"), 1.5)
			draw_line(pivot + _swing_dir * (reach - 3.0), pivot + _swing_dir * reach, Color("#eef3ff"), 2.5)
		&"stomp", &"kick":
			pass
		_:  # Schwert
			var angle := base + lerpf(-SWING_ARC, SWING_ARC, t)
			var blade := 9.0 + body_size * 0.25
			draw_arc(pivot, blade, base - SWING_ARC, angle, 8, Color(1, 1, 1, 0.45 * fade), 2.0)
			var dir := Vector2.from_angle(angle)
			draw_line(pivot, pivot + dir * blade, Color("#eef3ff"), 2.0)
			draw_line(pivot - dir * 1.5, pivot + dir * 2.0, Color("#ffd91f"), 2.0)
