class_name Hud
extends CanvasLayer
## Oberfläche: Statusleiste, Shop, Start-Button, Hinweise und Game-Over-Anzeige.
## Wird komplett im Code aufgebaut (feste Auflösung 640x360).

signal shop_pressed(data: UnitData)
signal start_pressed
signal restart_pressed
signal select_all_pressed
signal return_pressed
signal event_chosen(offer: Dictionary)
signal multi_toggled(on: bool)
signal menu_pressed
signal quick_buy_pressed(bundle: Dictionary)
signal order_pressed
signal ability_pressed
signal merge_all_pressed

var _round_label: Label
var _gold_label: Label
var _phase_label: Label
var _info: Label
var _toast: Label
var _toast_tween: Tween
var _start_button: Button
var _book_button: Button
var _book: RecipeBook
var _events: EventPanel
var _shop_button: Button
var _village: Village
var _shop: Shop
var _speed_button: Button
var _pause_button: Button
var _pause: PausePanel
var _order_button: Button
var _ability_button: Button
var _auto_button: Button
var _sound_button: Button
var _achievements_button: Button
var _fullscreen_button: Button
var _group_box: HBoxContainer
var _multi_button: Button
var _all_button: Button
## Von der Arena gesetzt: hebt die Auswahl im Kampf auf, false wenn nichts gewählt war (Zurück/Esc).
var clear_selection: Callable
var _return_button: Button
var _merge_all_button: Button
var _achievements: AchievementsPanel
var _banner: Label
var _modifier_sign: PanelContainer
var _modifier_title: Label
var _modifier_text: Label
var _banner_tween: Tween
var _boss_bar: Control
var _boss_fill: ColorRect
var _boss_name: Label
var _info_warning := false
var _merge_panel: PanelContainer
var _merge_cards: Array[Dictionary] = []
var _merge_cost: Label
var _merge_key := ""
var _card: UnitCard
var _hint_panel: PanelContainer
var _hint_title: Label
var _hint_rows: Array[Dictionary] = []
var _hint_more: Label
const HINT_ROWS := 4
var _last_back_msec := -10000
var _game_over: GameOverPanel
var _time_left := 0.0
var _shown_seconds := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # bleibt bedienbar, während der Kampf pausiert
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.make()
	add_child(root)

	_add_bar(root, Rect2(0, 0, 640, 24), false)
	_add_bar(root, Rect2(0, 320, 640, 40), true)
	_round_label = _add_label(root, Rect2(8, 3, 80, 18), HORIZONTAL_ALIGNMENT_LEFT)
	var coin := TextureRect.new()
	coin.texture = UiTheme.coin()
	coin.position = Vector2(88, 6)
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(coin)
	_gold_label = _add_label(root, Rect2(102, 3, 60, 18), HORIZONTAL_ALIGNMENT_LEFT)
	_gold_label.add_theme_color_override("font_color", UiTheme.GOLD_LIGHT)
	_phase_label = _add_label(root, Rect2(166, 3, 200, 18), HORIZONTAL_ALIGNMENT_LEFT)
	# Info zur Einheit unter dem Finger: zweizeilig in der unteren Leiste zwischen den Knöpfen.
	_info = _add_label(root, Rect2(178, 322, 336, 36), HORIZONTAL_ALIGNMENT_CENTER)
	_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_info.add_theme_font_size_override("font_size", 10)
	_info.add_theme_constant_override("line_spacing", -2)
	_toast = _add_label(root, Rect2(120, 292, 400, 22), HORIZONTAL_ALIGNMENT_CENTER)
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.add_theme_stylebox_override("normal", UiTheme.sign_style())
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_shop_button = Button.new()
	_shop_button.text = tr("Dorf")
	_shop_button.position = Vector2(6, 326)
	_shop_button.size = Vector2(80, 28)
	_shop_button.pressed.connect(func() -> void:
		_village.visible = not _village.visible
		_shop.close_panel()
		_refresh())
	root.add_child(_shop_button)

	_book_button = Button.new()
	_book_button.text = tr("Rezepte")
	_book_button.position = Vector2(92, 326)
	_book_button.size = Vector2(80, 28)
	_book_button.pressed.connect(func() -> void: _book.open_book())
	root.add_child(_book_button)

	_speed_button = Button.new()
	_speed_button.position = Vector2(6, 326)
	_speed_button.size = Vector2(80, 28)
	_speed_button.pressed.connect(func() -> void: Game.cycle_battle_speed())
	root.add_child(_speed_button)

	# Befehl der gewählten Einheit (nur im Kampf): Frei -> Halten -> Schützen.
	_order_button = Button.new()
	_order_button.text = tr("Befehl")
	_order_button.disabled = true
	_order_button.position = Vector2(92, 326)
	_order_button.size = Vector2(80, 28)
	_order_button.pressed.connect(func() -> void: order_pressed.emit())
	root.add_child(_order_button)

	# Fähigkeit der gewählten Einheit (nur im Kampf, an der Stelle des Start-Knopfs).
	_ability_button = Button.new()
	_ability_button.text = tr("Fähigkeit")
	_ability_button.disabled = true
	_ability_button.position = Vector2(520, 326)
	_ability_button.size = Vector2(114, 28)
	_ability_button.add_theme_font_size_override("font_size", 11)
	_ability_button.pressed.connect(func() -> void: ability_pressed.emit())
	root.add_child(_ability_button)

	_start_button = Button.new()
	_start_button.text = tr("Kampf starten")
	_start_button.position = Vector2(520, 326)
	_start_button.size = Vector2(114, 28)
	_start_button.pressed.connect(func() -> void: start_pressed.emit())
	root.add_child(_start_button)

	_pause_button = Button.new()
	_pause_button.text = tr("Pause")
	_pause_button.position = Vector2(236, 2)
	_pause_button.size = Vector2(52, 20)
	_pause_button.add_theme_font_size_override("font_size", 10)
	_pause_button.pressed.connect(func() -> void: set_paused(true))
	root.add_child(_pause_button)

	if Fullscreen.available():
		_fullscreen_button = Button.new()
		_fullscreen_button.text = Fullscreen.label()
		_fullscreen_button.position = Vector2(292, 2)
		_fullscreen_button.size = Vector2(56, 20)
		_fullscreen_button.add_theme_font_size_override("font_size", 10)
		_fullscreen_button.pressed.connect(func() -> void:
			Fullscreen.toggle()
			# Der Browser meldet den neuen Modus erst einen Moment später
			for delay in [0.2, 0.7, 1.5]:
				await get_tree().create_timer(delay, true, false, true).timeout
				_refresh())
		get_viewport().size_changed.connect(_refresh)
		root.add_child(_fullscreen_button)
	_achievements_button = Button.new()
	_achievements_button.text = tr("Erfolge")
	_achievements_button.position = Vector2(354, 2)
	_achievements_button.size = Vector2(98, 20)
	_achievements_button.add_theme_font_size_override("font_size", 10)
	_achievements_button.pressed.connect(func() -> void:
		if _achievements.visible:
			_achievements.close_panel()
		else:
			_achievements.open_panel())
	root.add_child(_achievements_button)

	_auto_button = Button.new()
	_auto_button.position = Vector2(458, 2)
	_auto_button.size = Vector2(112, 20)
	_auto_button.add_theme_font_size_override("font_size", 10)
	_auto_button.pressed.connect(func() -> void:
		Game.auto_abilities = not Game.auto_abilities
		_refresh())
	root.add_child(_auto_button)

	_sound_button = Button.new()
	_sound_button.position = Vector2(574, 2)
	_sound_button.size = Vector2(62, 20)
	_sound_button.add_theme_font_size_override("font_size", 10)
	_sound_button.pressed.connect(Sound.cycle_mode)
	root.add_child(_sound_button)
	Sound.muted_changed.connect(func(_muted: bool) -> void: _refresh())

	# Das Dorf liegt unter den Leisten und über der Arena. Der Kauf passiert in den Häusern.
	_village = Village.new()
	_village.unit_chosen.connect(func(data: UnitData) -> void: shop_pressed.emit(data))
	root.add_child(_village)
	root.move_child(_village, 0)
	_shop = _village.shop
	_build_merge_panel(root)
	_card = UnitCard.new()
	root.add_child(_card)
	_build_hint_panel(root)
	_build_group_buttons(root)
	# Bauphase: alle gleichen Paare auf einmal verbinden, über "Kampf starten" (nur wenn etwas geht).
	_merge_all_button = Button.new()
	_merge_all_button.position = Vector2(520, 294)
	_merge_all_button.size = Vector2(114, 26)
	_merge_all_button.visible = false
	_merge_all_button.add_theme_font_size_override("font_size", 10)
	_merge_all_button.tooltip_text = tr("Verbindet je zwei gleiche Einheiten zur nächsten Stufe, niedrigste Stufe zuerst")
	_merge_all_button.pressed.connect(func() -> void: merge_all_pressed.emit())
	root.add_child(_merge_all_button)
	_book = RecipeBook.new()
	_book.quick_buy.connect(func(bundle: Dictionary) -> void: quick_buy_pressed.emit(bundle))
	root.add_child(_book)
	_events = EventPanel.new()
	_events.chosen.connect(func(offer: Dictionary) -> void:
		_refresh()
		event_chosen.emit(offer))
	_events.skipped.connect(_refresh)
	root.add_child(_events)
	_achievements = AchievementsPanel.new()
	root.add_child(_achievements)
	_build_banner_and_boss_bar(root)
	_game_over = GameOverPanel.new()
	_game_over.restart_pressed.connect(func() -> void: restart_pressed.emit())
	_game_over.menu_pressed.connect(func() -> void: menu_pressed.emit())
	root.add_child(_game_over)
	_pause = PausePanel.new()
	root.add_child(_pause)
	_book.visibility_changed.connect(_refresh)
	Game.gold_changed.connect(func(_gold: int) -> void: _refresh())
	Game.round_changed.connect(func(_round: int) -> void: _refresh())
	Achievements.unlocked.connect(_on_achievement_unlocked)
	Game.phase_changed.connect(func(_phase: int) -> void: _refresh())
	Game.speed_changed.connect(func(_speed: float) -> void: _refresh())
	_refresh()


func set_time(seconds: float) -> void:
	_time_left = seconds
	var shown := ceili(seconds)
	if shown != _shown_seconds:
		_shown_seconds = shown
		_refresh()


func show_info(unit: Combatant) -> void:
	if unit == null or not is_instance_valid(unit):
		_set_info("", false)
		return
	var text := tr("%s (Stufe %d)%s\nLP %d/%d  Stä %s  Bew %s  Int %s") % [
		unit.display_name, unit.level, unit.order_text() + _ability_suffix(unit.ability),
		ceili(unit.health), ceili(unit.max_health), UnitData.format_number(unit.attack),
		UnitData.format_number(unit.move_speed), UnitData.format_number(unit.intelligence)]
	_set_info(text, false)


## Beschriftung des Befehlsknopfs nach Befehl der gewählten Einheit (null = nichts gewählt).
func set_order_unit(unit: Combatant, picking_guard: bool) -> void:
	var text := tr("Befehl")
	if unit != null:
		if picking_guard:
			text = tr("Schützen...")
		else:
			match unit.order_mode():
				&"free": text = tr("Frei")
				&"hold": text = tr("Halten")
				_: text = tr("Schützt")
	_order_button.disabled = unit == null
	if _order_button.text != text:
		_order_button.text = text


func _ability_suffix(ability: StringName) -> String:
	return "  * %s" % Abilities.label(ability) if ability != &"" else ""


## Beschriftung des Fähigkeitsknopfs (null = nichts gewählt).
func set_ability_unit(unit: Combatant, selection: Array[Combatant] = []) -> void:
	var text := tr("Fähigkeit")
	var enabled := false
	if selection.size() > 1:
		var with_active := 0
		var ready := 0
		for member in selection:
			if Abilities.is_active(member.ability):
				with_active += 1
				if member.ability_cooldown_left() <= 0.0:
					ready += 1
			if member.veteran_ability != &"":
				with_active += 1
				if member.veteran_ready():
					ready += 1
		text = tr("Fähigkeiten %d/%d") % [ready, with_active] if with_active > 0 else tr("Fähigkeit")
		enabled = ready > 0
	elif unit != null and unit.veteran_ready() and not (Abilities.is_active(unit.ability) and unit.ability_cooldown_left() <= 0.0):
		text = Abilities.display_name(unit.veteran_ability) + "!"
		enabled = true
	elif unit != null and unit.ability != &"":
		text = Abilities.display_name(unit.ability)
		if not Abilities.is_active(unit.ability):
			text += tr(" (passiv)")
		elif unit.ability_cooldown_left() > 0.0:
			text += " %ds" % ceili(unit.ability_cooldown_left())
		else:
			text += "!"
		enabled = Abilities.is_active(unit.ability) and unit.ability_cooldown_left() <= 0.0
	_ability_button.disabled = not enabled
	if _ability_button.text != text:
		_ability_button.text = text


## Rechts neben dem Feld: die beiden Zutaten und das Ergebnis mit Bild, Werten und Fähigkeit.
func _build_merge_panel(root: Control) -> void:
	_merge_panel = PanelContainer.new()
	_merge_panel.position = Vector2(474, 28)
	_merge_panel.size = Vector2(162, 10)
	_merge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_merge_panel.visible = false
	var style := UiTheme.sign_style()
	style.modulate_color = Color(1, 1, 1, 0.94)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	_merge_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_merge_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 1)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_merge_panel.add_child(column)
	for index in 3:
		if index > 0:
			var sign := Label.new()
			sign.text = "+" if index == 1 else "="
			sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sign.add_theme_font_size_override("font_size", 10)
			sign.add_theme_color_override("font_color", UiTheme.GOLD_LIGHT)
			column.add_child(sign)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 4)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		head.add_child(icon)
		var names := VBoxContainer.new()
		names.add_theme_constant_override("separation", -2)
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := Label.new()
		title.clip_text = true
		title.add_theme_font_size_override("font_size", 10)
		title.add_theme_color_override("font_color", UiTheme.GOLD_LIGHT if index == 2 else UiTheme.CREAM)
		var stats := Label.new()
		stats.clip_text = true
		stats.add_theme_font_size_override("font_size", 8)
		names.add_child(title)
		names.add_child(stats)
		head.add_child(names)
		column.add_child(head)
		var ability := Label.new()
		ability.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ability.custom_minimum_size = Vector2(150, 0)
		ability.add_theme_font_size_override("font_size", 8)
		ability.add_theme_constant_override("line_spacing", -2)
		ability.add_theme_color_override("font_color", Color("#d8c8a0"))
		column.add_child(ability)
		_merge_cards.append({"icon": icon, "title": title, "stats": stats, "ability": ability})
	_merge_cost = Label.new()
	_merge_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_merge_cost.add_theme_font_size_override("font_size", 10)
	column.add_child(_merge_cost)


## Zeigt beim Ziehen, was aus `a` und `b` wird. `warning`: Verbinden gerade nicht möglich (Gold/Runde).
## `hidden`: unentdecktes Geheimrezept, das Ergebnis bleibt ein Schatten mit "???".
func show_merge_preview(a: UnitData, b: UnitData, result: UnitData, cost_text: String, warning: bool, hidden := false) -> void:
	var key := "%s|%s|%s|%s|%s|%s" % [a.id, b.id, cost_text, warning, Loc.language, hidden]
	if key == _merge_key and _merge_panel.visible:
		return
	_merge_key = key
	var units := [a, b, result]
	for index in 3:
		var unit: UnitData = units[index]
		var card: Dictionary = _merge_cards[index]
		card["icon"].texture = unit.sprite
		card["title"].text = unit.display_name
		card["stats"].text = unit.stats_text()
		var ability_text := ""
		if unit.ability != &"":
			ability_text = "* %s: %s" % [Abilities.label(unit.ability), Abilities.description(unit.ability)]
		if unit.traits_text() != "":
			ability_text += ("\n" if ability_text != "" else "") + unit.traits_text()
		card["ability"].text = ability_text
		card["ability"].visible = ability_text != ""
		if hidden and index == 2:
			card["icon"].texture = UiTheme.silhouette(unit.sprite)
			card["title"].text = "???"
			card["stats"].text = tr("Ein Geheimrezept!")
			card["ability"].visible = false
	_merge_cost.text = cost_text
	_merge_cost.add_theme_color_override("font_color", Color(1.0, 0.5, 0.45) if warning else UiTheme.GOLD_LIGHT)
	_merge_panel.size = Vector2(162, 10)
	_merge_panel.visible = true


func hide_merge_preview() -> void:
	if _merge_panel.visible:
		_merge_panel.visible = false
		_merge_key = ""


## Porträt mit Werten der gewählten (oder gerade gezogenen) Einheit, links neben dem Feld.
## `unit` null blendet die Karte aus. Wird jeden Frame aufgerufen, die Karte setzt nur Änderungen.
func show_unit_card(unit: Combatant, extra := 0) -> void:
	_card.show_unit(unit, extra)


## Mögliche Rezepte der gehaltenen Einheit, links unter der Karte.
## Kampfphase, untere Leiste: "Alle" wählt jede Einheit (mit Auswahl heißt er "Keine" und hebt sie auf), "Mehrfach" lässt Antippen Einheiten hinzufügen oder abwählen.
func _build_group_buttons(root: Control) -> void:
	_group_box = HBoxContainer.new()
	_group_box.position = Vector2(176, 326)
	_group_box.size = Vector2(116, 28)
	_group_box.add_theme_constant_override("separation", 4)
	_group_box.visible = false
	root.add_child(_group_box)
	_all_button = Button.new()
	_all_button.text = tr("Alle")
	_all_button.custom_minimum_size = Vector2(40, 28)
	_all_button.add_theme_font_size_override("font_size", 10)
	_all_button.pressed.connect(func() -> void: select_all_pressed.emit())
	_group_box.add_child(_all_button)
	_multi_button = Button.new()
	_multi_button.text = tr("Mehrfach")
	_multi_button.toggle_mode = true
	_multi_button.custom_minimum_size = Vector2(72, 28)
	_multi_button.add_theme_font_size_override("font_size", 10)
	_multi_button.toggled.connect(func(on: bool) -> void:
		_multi_button.text = tr("Mehrfach: an") if on else tr("Mehrfach")
		multi_toggled.emit(on))
	_group_box.add_child(_multi_button)
	# Bauphase: gewählte Einheiten zurückschicken (halber Kaufpreis).
	_return_button = Button.new()
	_return_button.text = tr("Zurückschicken")
	_return_button.position = Vector2(176, 326)
	_return_button.size = Vector2(116, 28)
	_return_button.disabled = true
	_return_button.add_theme_font_size_override("font_size", 10)
	_return_button.pressed.connect(func() -> void: return_pressed.emit())
	root.add_child(_return_button)


## `plan`: Vector2i(Anzahl Merges, Gesamtkosten) von "Alles verbinden", (0, 0) blendet den Knopf aus.
func set_merge_all(plan: Vector2i) -> void:
	var show := plan.x > 0 and Game.phase == Game.Phase.BUILD and not _village.visible \
			and not _book.visible and not _events.visible
	_merge_all_button.visible = show
	var text := tr("Verbinden %dx: %dg") % [plan.x, plan.y]
	if show and _merge_all_button.text != text:
		_merge_all_button.text = text


func set_return_selection(count: int, refund: int) -> void:
	_return_button.disabled = count == 0
	var text := tr("Zurück: +%dg") % refund if count > 0 else tr("Zurückschicken")
	if _return_button.text != text:
		_return_button.text = text
	var all_text := tr("Keine") if count > 0 else tr("Alle")
	if _all_button.text != all_text:
		_all_button.text = all_text


func _build_hint_panel(root: Control) -> void:
	_hint_panel = PanelContainer.new()
	_hint_panel.position = Vector2(4, 184)
	_hint_panel.size = Vector2(150, 10)
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.visible = false
	var style := UiTheme.sign_style()
	style.modulate_color = Color(1, 1, 1, 0.94)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	_hint_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_hint_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 1)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.add_child(column)
	_hint_title = Label.new()
	_hint_title.add_theme_font_size_override("font_size", 9)
	_hint_title.add_theme_color_override("font_color", UiTheme.GOLD_LIGHT)
	column.add_child(_hint_title)
	for index in HINT_ROWS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var partner := TextureRect.new()
		var result := TextureRect.new()
		for icon in [partner, result]:
			icon.custom_minimum_size = Vector2(22, 22)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var plus := Label.new()
		plus.text = "+"
		plus.add_theme_font_size_override("font_size", 9)
		var equals := Label.new()
		equals.text = "="
		equals.add_theme_font_size_override("font_size", 9)
		var texts := VBoxContainer.new()
		texts.add_theme_constant_override("separation", -3)
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := Label.new()
		title.clip_text = true
		title.add_theme_font_size_override("font_size", 9)
		var info := Label.new()
		info.clip_text = true
		info.add_theme_font_size_override("font_size", 8)
		texts.add_child(title)
		texts.add_child(info)
		for node in [plus, partner, equals, result, texts]:
			row.add_child(node)
		column.add_child(row)
		_hint_rows.append({"row": row, "partner": partner, "result": result, "title": title, "info": info})
	_hint_more = Label.new()
	_hint_more.add_theme_font_size_override("font_size", 8)
	_hint_more.add_theme_color_override("font_color", Color("#d8c8a0"))
	column.add_child(_hint_more)


## `hints`: Einträge {partner: UnitData, result: UnitData, cost: int, state: &"now"/&"gold"/&"locked"/&"missing", round: int},
## vorsortiert (sofort möglich zuerst). `total`: Anzahl aller Rezepte der Einheit. Leere Liste blendet aus.
func show_recipe_hints(unit_name: String, hints: Array, total: int) -> void:
	if hints.is_empty():
		hide_recipe_hints()
		return
	_hint_title.text = tr("%s verbinden mit:") % unit_name
	for index in HINT_ROWS:
		var slot: Dictionary = _hint_rows[index]
		slot["row"].visible = index < hints.size()
		if index >= hints.size():
			continue
		var hint: Dictionary = hints[index]
		slot["partner"].texture = hint["partner"].sprite
		slot["result"].texture = hint["result"].sprite
		slot["title"].text = hint["result"].display_name
		var usable: bool = hint["state"] == &"now"
		slot["title"].add_theme_color_override("font_color", UiTheme.GOLD_LIGHT if usable else Color("#b8a888"))
		match hint["state"]:
			&"now": slot["info"].text = tr("%dg, jetzt möglich") % hint["cost"]
			&"gold": slot["info"].text = tr("%dg, zu wenig Gold") % hint["cost"]
			&"locked": slot["info"].text = tr("ab Runde %d") % hint["round"]
			_: slot["info"].text = tr("%dg, Partner fehlt") % hint["cost"]
	_hint_more.visible = total > hints.size()
	_hint_more.text = tr("+ %d weitere im Rezeptbuch") % (total - hints.size())
	_hint_panel.size = Vector2(150, 10)
	_hint_panel.visible = true


func hide_recipe_hints() -> void:
	_hint_panel.visible = false


func merge_preview_visible() -> bool:
	return _merge_panel.visible


func show_text(text: String, warning := false) -> void:
	_set_info(text, warning)


## Nur bei Änderungen neu setzen: wird jeden Frame aufgerufen.
func _set_info(text: String, warning: bool) -> void:
	if warning != _info_warning:
		_info_warning = warning
		_info.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4) if warning else Color.WHITE)
	if _info.text != text:
		_info.text = text


func toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)


## Bereich, den der geöffnete Shop verdeckt (für das Platzieren neuer Einheiten).
func shop_blocked_rect() -> Rect2:
	return _village.blocked_rect()


## Verloren-Bildschirm mit Auswertung des Laufs (`stats` aus Game.stats) und Rekord.
func show_game_over(reached_round: int, stats: Dictionary = {}, best_round := 0, new_record := false) -> void:
	_game_over.show_result(reached_round, stats, best_round, new_record)


func _refresh() -> void:
	_round_label.text = tr("Runde %d") % Game.round_number
	var kind := Game.round_kind()
	_round_label.add_theme_color_override("font_color", Color("#ff8a7a") if kind == Game.RoundKind.BOSS \
			else (UiTheme.GOLD_LIGHT if kind == Game.RoundKind.BONUS else UiTheme.CREAM))
	_gold_label.text = "%d" % Game.gold
	if _modifier_sign != null:
		_refresh_modifier_sign()
	match Game.phase:
		Game.Phase.BUILD:
			_phase_label.text = tr("Bauphase") + (tr(" – Bossrunde!") if kind == Game.RoundKind.BOSS \
					else (tr(" – Bonusrunde!") if kind == Game.RoundKind.BONUS else ""))
			_phase_label.add_theme_color_override("font_color", Color("#9be66e"))
		Game.Phase.BATTLE:
			match kind:
				Game.RoundKind.BOSS:
					_phase_label.text = tr("Boss tobt!") if Game.boss_enraged else tr("Bosskampf")
				Game.RoundKind.BONUS:
					_phase_label.text = tr("Bonus %ds") % maxi(_shown_seconds, 0)
				_:
					_phase_label.text = tr("Kampf %ds") % maxi(_shown_seconds, 0)
			_phase_label.add_theme_color_override("font_color", Color("#ff8a7a"))
		_:
			_phase_label.text = ""
	var building := Game.phase == Game.Phase.BUILD
	_start_button.disabled = not building or (is_instance_valid(_book) and _book.visible) \
			or (is_instance_valid(_events) and _events.visible)
	_start_button.visible = building
	_ability_button.visible = Game.phase == Game.Phase.BATTLE
	_pause_button.visible = Game.phase == Game.Phase.BATTLE
	if Game.phase != Game.Phase.BATTLE and _pause != null and _pause.is_paused():
		set_paused(false)
	_auto_button.text = tr("Auto-Fähigk.: an") if Game.auto_abilities else tr("Auto-Fähigk.: aus")
	if _fullscreen_button != null:
		_fullscreen_button.text = Fullscreen.label()
	_book_button.disabled = not building
	_shop_button.disabled = not building
	# Im Kampf ersetzt der Tempo-Knopf Shop und Rezeptbuch.
	_shop_button.visible = building
	_book_button.visible = building
	_speed_button.visible = Game.phase == Game.Phase.BATTLE
	_group_box.visible = Game.phase == Game.Phase.BATTLE
	_return_button.visible = building
	# Im Kampf teilen sich Gruppenknöpfe und Info die Mitte der unteren Leiste.
	_info.position = Vector2(296, 322)
	_info.size = Vector2(218, 36)
	_order_button.visible = Game.phase == Game.Phase.BATTLE
	_speed_button.text = tr("Tempo %dx") % roundi(Game.battle_speed)
	_sound_button.text = Sound.mode_label()
	if not building:
		_village.visible = false
		_shop.close_panel()
	_shop_button.text = tr("Arena") if _village.visible else tr("Dorf")
	_shop.refresh()


## Ist nichts mehr offen, führt Zurück ins Hauptmenü: erst warnen, beim zweiten Druck gehen.
func _back_to_menu() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_back_msec < 2500:
		menu_pressed.emit()
		return
	_last_back_msec = now
	if Game.phase == Game.Phase.BATTLE:
		toast(tr("Nochmal zurück: Hauptmenü (später geht es vor diesem Kampf weiter)"))
	else:
		toast(tr("Nochmal zurück: Hauptmenü (der Lauf wird gespeichert)"))


## Zurück-Taste (Android) bzw. Esc: erst offene Fenster schließen, dann die App beenden.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not handle_back():
		_back_to_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and handle_back():
		get_viewport().set_input_as_handled()


## Schließt das oberste offene Fenster. Gibt false zurück, wenn keins offen war.
## Ereignis zwischen den Runden anbieten (siehe RoundEvents).
func show_event(offers: Array[Dictionary]) -> void:
	_events.open_panel(offers)
	_refresh()


func event_open() -> bool:
	return _events.visible


## Ein Fenster über der Arena ist offen (Kaufliste, Rezeptbuch, Ereignis, Erfolge, Verloren).
func panel_open() -> bool:
	return _shop.visible or _book.visible or _events.visible or _achievements.visible or _game_over.visible \
			or _pause.is_paused()


## Kampf anhalten oder fortsetzen (Knopf, Zurück-Taste, App im Hintergrund).
func set_paused(on: bool) -> void:
	if on and Game.phase != Game.Phase.BATTLE:
		return
	_pause.set_paused(on)


func is_paused() -> bool:
	return _pause.is_paused()


## Angebote des offenen Ereignisses, leer wenn keins offen ist.
func event_offers() -> Array[Dictionary]:
	return _events.offers if _events.visible else ([] as Array[Dictionary])


func handle_back() -> bool:
	if _pause.is_paused():
		set_paused(false)
		return true
	if _events.visible:
		_events.close_panel()
		_refresh()
		return true
	if _achievements.visible:
		_achievements.close_panel()
		return true
	if _book.visible:
		_book.close_book()
		return true
	if _shop.visible:
		_shop.close_panel()
		return true
	if _village.visible:
		_village.visible = false
		_refresh()
		return true
	return clear_selection.is_valid() and clear_selection.call()


func _add_bar(parent: Control, rect: Rect2, edge_top: bool) -> void:
	var bar := TextureRect.new()
	bar.texture = UiTheme.plank_bar(int(rect.size.x), int(rect.size.y), edge_top)
	bar.position = rect.position
	bar.size = rect.size
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)


func _add_label(parent: Control, rect: Rect2, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = align
	parent.add_child(label)
	return label


## Schild oben in der Mitte: Sonderregel der Runde (siehe Modifiers), in Bau- und Kampfphase.
func _build_modifier_sign(root: Control) -> void:
	_modifier_sign = PanelContainer.new()
	_modifier_sign.position = Vector2(178, 27)
	_modifier_sign.size = Vector2(284, 10)
	_modifier_sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modifier_sign.visible = false
	var style := UiTheme.sign_style()
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	_modifier_sign.add_theme_stylebox_override("panel", style)
	root.add_child(_modifier_sign)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", -3)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modifier_sign.add_child(column)
	_modifier_title = Label.new()
	_modifier_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modifier_title.add_theme_font_size_override("font_size", 11)
	_modifier_title.add_theme_color_override("font_color", UiTheme.GOLD_LIGHT)
	column.add_child(_modifier_title)
	_modifier_text = Label.new()
	_modifier_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modifier_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_modifier_text.custom_minimum_size = Vector2(270, 0)
	_modifier_text.add_theme_font_size_override("font_size", 9)
	column.add_child(_modifier_text)
	Game.modifier_changed.connect(func(_id: StringName) -> void: _refresh_modifier_sign())
	_refresh_modifier_sign()


func _refresh_modifier_sign() -> void:
	var id := Game.modifier
	_modifier_sign.visible = id != &"" and Game.phase != Game.Phase.GAME_OVER
	if not _modifier_sign.visible:
		return
	var prefix := tr("Nächste Runde: ") if Game.phase == Game.Phase.BUILD else ""
	_modifier_title.text = prefix + Modifiers.display_name(id)
	_modifier_text.text = Modifiers.description(id)
	_modifier_sign.size = Vector2(284, 10)
	_modifier_sign.modulate.a = 1.0 if Game.phase == Game.Phase.BUILD else 0.8


func _build_banner_and_boss_bar(root: Control) -> void:
	_build_modifier_sign(root)
	# Erfolgs-Meldung oben in der Mitte
	_banner = _add_label(root, Rect2(150, 30, 340, 22), HORIZONTAL_ALIGNMENT_CENTER)
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_theme_stylebox_override("normal", UiTheme.sign_style())
	_banner.add_theme_color_override("font_color", UiTheme.GOLD_LIGHT)
	_banner.modulate.a = 0.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Lebensleiste des Bosses
	_boss_bar = Control.new()
	_boss_bar.position = Vector2(170, 27)
	_boss_bar.size = Vector2(300, 14)
	_boss_bar.visible = false
	_boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_boss_bar)
	var frame := ColorRect.new()
	frame.color = UiTheme.INK
	frame.size = Vector2(300, 14)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_bar.add_child(frame)
	var back := ColorRect.new()
	back.color = Color("#4a1018")
	back.position = Vector2(2, 2)
	back.size = Vector2(296, 10)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_bar.add_child(back)
	_boss_fill = ColorRect.new()
	_boss_fill.color = Color("#e0382a")
	_boss_fill.position = Vector2(2, 2)
	_boss_fill.size = Vector2(296, 10)
	_boss_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_bar.add_child(_boss_fill)
	_boss_name = _add_label(_boss_bar, Rect2(0, -1, 300, 14), HORIZONTAL_ALIGNMENT_CENTER)
	_boss_name.add_theme_font_size_override("font_size", 9)


## Leiste für den Boss der Runde (null = ausblenden).
func set_boss(boss: Combatant) -> void:
	var show := boss != null and is_instance_valid(boss) and boss.is_alive()
	_boss_bar.visible = show
	if show:
		_boss_fill.size.x = 296.0 * clampf(boss.health / boss.max_health, 0.0, 1.0)
		_boss_name.text = boss.display_name


func _on_achievement_unlocked(id: StringName) -> void:
	announce_achievement(Achievements.display_name(id))


func announce_achievement(achievement_name: String) -> void:
	announce(tr("Erfolg: %s") % achievement_name)


## Goldene Meldung oben in der Mitte (Erfolge, entdeckte Geheimrezepte).
func announce(text: String) -> void:
	_banner.text = text
	_banner.position.y = 62.0 if _modifier_sign.visible else 30.0
	_banner.modulate.a = 1.0
	if _banner_tween != null:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_interval(3.0)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.5)
	Sound.play(&"merge", 0.0)
