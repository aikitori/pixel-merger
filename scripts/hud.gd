class_name Hud
extends CanvasLayer
## Oberfläche: Statusleiste, Shop, Start-Button, Hinweise und Game-Over-Anzeige.
## Wird komplett im Code aufgebaut (feste Auflösung 640x360).

signal shop_pressed(data: UnitData)
signal start_pressed
signal restart_pressed
signal menu_pressed
signal quick_buy_pressed(bundle: Dictionary)
signal order_pressed
signal ability_pressed

var _round_label: Label
var _gold_label: Label
var _phase_label: Label
var _info: Label
var _toast: Label
var _toast_tween: Tween
var _start_button: Button
var _book_button: Button
var _book: RecipeBook
var _shop_button: Button
var _village: Village
var _shop: Shop
var _speed_button: Button
var _order_button: Button
var _ability_button: Button
var _auto_button: Button
var _sound_button: Button
var _achievements_button: Button
var _achievements: AchievementsPanel
var _banner: Label
var _banner_tween: Tween
var _boss_bar: Control
var _boss_fill: ColorRect
var _boss_name: Label
var _info_warning := false
var _merge_panel: PanelContainer
var _merge_cards: Array[Dictionary] = []
var _merge_cost: Label
var _merge_key := ""
var _card: PanelContainer
var _card_unit: Combatant
var _card_icon: TextureRect
var _card_title: Label
var _card_hp_fill: ColorRect
var _card_hp_text: Label
var _card_stats: Label
var _card_ability: Label
var _card_key := ""
var _last_back_msec := -10000
var _game_over: Control
var _game_over_label: Label
var _time_left := 0.0
var _shown_seconds := -1


func _ready() -> void:
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
	_sound_button.pressed.connect(func() -> void: Sound.muted = not Sound.muted)
	root.add_child(_sound_button)
	Sound.muted_changed.connect(func(_muted: bool) -> void: _refresh())

	# Das Dorf liegt unter den Leisten und über der Arena. Der Kauf passiert in den Häusern.
	_village = Village.new()
	_village.unit_chosen.connect(func(data: UnitData) -> void: shop_pressed.emit(data))
	root.add_child(_village)
	root.move_child(_village, 0)
	_shop = _village.shop
	_build_merge_panel(root)
	_build_unit_card(root)
	_book = RecipeBook.new()
	_book.quick_buy.connect(func(bundle: Dictionary) -> void: quick_buy_pressed.emit(bundle))
	root.add_child(_book)
	_achievements = AchievementsPanel.new()
	root.add_child(_achievements)
	_build_banner_and_boss_bar(root)
	_build_game_over(root)
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
			text = tr("Schützen…")
		else:
			match unit.order_mode():
				&"free": text = tr("Frei")
				&"hold": text = tr("Halten")
				_: text = tr("Schützt")
	_order_button.disabled = unit == null
	if _order_button.text != text:
		_order_button.text = text


func _ability_suffix(ability: StringName) -> String:
	return "  ★ %s" % Abilities.label(ability) if ability != &"" else ""


## Beschriftung des Fähigkeitsknopfs (null = nichts gewählt).
func set_ability_unit(unit: Combatant) -> void:
	var text := tr("Fähigkeit")
	var enabled := false
	if unit != null and unit.ability != &"":
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
			sign.text = "+" if index == 1 else "▼"
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
func show_merge_preview(a: UnitData, b: UnitData, result: UnitData, cost_text: String, warning: bool) -> void:
	var key := "%s|%s|%s|%s|%s" % [a.id, b.id, cost_text, warning, Loc.language]
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
			ability_text = "★ %s: %s" % [Abilities.label(unit.ability), Abilities.description(unit.ability)]
		card["ability"].text = ability_text
		card["ability"].visible = ability_text != ""
	_merge_cost.text = cost_text
	_merge_cost.add_theme_color_override("font_color", Color(1.0, 0.5, 0.45) if warning else UiTheme.GOLD_LIGHT)
	_merge_panel.size = Vector2(162, 10)
	_merge_panel.visible = true


func hide_merge_preview() -> void:
	if _merge_panel.visible:
		_merge_panel.visible = false
		_merge_key = ""


## Porträt mit Werten der gewählten (oder gerade gezogenen) Einheit, links neben dem Feld.
func _build_unit_card(root: Control) -> void:
	_card = PanelContainer.new()
	_card.position = Vector2(4, 28)
	_card.size = Vector2(150, 10)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.visible = false
	var style := UiTheme.sign_style()
	style.modulate_color = Color(1, 1, 1, 0.94)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	_card.add_theme_stylebox_override("panel", style)
	root.add_child(_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(column)
	_card_icon = TextureRect.new()
	_card_icon.custom_minimum_size = Vector2(140, 64)
	_card_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_card_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	column.add_child(_card_icon)
	_card_title = Label.new()
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_title.clip_text = true
	_card_title.add_theme_font_size_override("font_size", 10)
	_card_title.add_theme_color_override("font_color", UiTheme.GOLD_LIGHT)
	column.add_child(_card_title)
	var bar := ColorRect.new()
	bar.color = Color(0.1, 0.04, 0.02, 0.9)
	bar.custom_minimum_size = Vector2(140, 10)
	column.add_child(bar)
	_card_hp_fill = ColorRect.new()
	_card_hp_fill.color = Color("#4fbf4a")
	_card_hp_fill.position = Vector2(1, 1)
	_card_hp_fill.size = Vector2(138, 8)
	bar.add_child(_card_hp_fill)
	_card_hp_text = Label.new()
	_card_hp_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card_hp_text.add_theme_font_size_override("font_size", 8)
	bar.add_child(_card_hp_text)
	_card_stats = Label.new()
	_card_stats.add_theme_font_size_override("font_size", 9)
	column.add_child(_card_stats)
	_card_ability = Label.new()
	_card_ability.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_ability.custom_minimum_size = Vector2(140, 0)
	_card_ability.add_theme_font_size_override("font_size", 8)
	_card_ability.add_theme_constant_override("line_spacing", -2)
	_card_ability.add_theme_color_override("font_color", Color("#d8c8a0"))
	column.add_child(_card_ability)


## `unit` null blendet die Karte aus. Wird jeden Frame aufgerufen, setzt daher nur Änderungen.
func show_unit_card(unit: Combatant) -> void:
	if unit == null or not is_instance_valid(unit) or unit.unit_data == null:
		if _card.visible:
			_card.visible = false
			_card_key = ""
		return
	var data := unit.unit_data
	var ability_text := ""
	if unit.ability != &"":
		ability_text = "★ %s: %s" % [Abilities.label(unit.ability), Abilities.description(unit.ability)]
	var key := "%s|%d|%d|%d|%s|%s" % [data.id, unit.level, ceili(unit.health), ceili(unit.max_health), unit.order_text(), Loc.language]
	if key == _card_key and _card.visible:
		return
	_card_key = key
	_card_icon.texture = data.sprite
	_card_title.text = "%s (%s %d)%s" % [unit.display_name, tr("Stufe"), unit.level, unit.order_text()]
	var share := clampf(unit.health / maxf(unit.max_health, 1.0), 0.0, 1.0)
	_card_hp_fill.size.x = 138.0 * share
	_card_hp_fill.color = Color("#4fbf4a") if share > 0.5 else (Color("#e0b030") if share > 0.25 else Color("#d04a3a"))
	_card_hp_text.text = "%d / %d" % [ceili(unit.health), ceili(unit.max_health)]
	_card_stats.text = tr("Stä %s  Bew %s  Int %s") % [UnitData.format_number(unit.attack),
			UnitData.format_number(unit.move_speed), UnitData.format_number(unit.intelligence)]
	_card_ability.text = ability_text
	_card_ability.visible = ability_text != ""
	_card.size = Vector2(150, 10)
	_card.visible = true


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


func show_game_over(reached_round: int) -> void:
	_game_over_label.text = tr("Verloren!\nRunde %d erreicht") % reached_round
	_game_over.visible = true


func _refresh() -> void:
	_round_label.text = tr("Runde %d") % Game.round_number
	var kind := Game.round_kind()
	_round_label.add_theme_color_override("font_color", Color("#ff8a7a") if kind == Game.RoundKind.BOSS \
			else (UiTheme.GOLD_LIGHT if kind == Game.RoundKind.BONUS else UiTheme.CREAM))
	_gold_label.text = "%d" % Game.gold
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
	_start_button.disabled = not building or (is_instance_valid(_book) and _book.visible)
	_start_button.visible = building
	_ability_button.visible = Game.phase == Game.Phase.BATTLE
	_auto_button.text = tr("Auto-Fähigk.: an") if Game.auto_abilities else tr("Auto-Fähigk.: aus")
	_book_button.disabled = not building
	_shop_button.disabled = not building
	# Im Kampf ersetzt der Tempo-Knopf Shop und Rezeptbuch.
	_shop_button.visible = building
	_book_button.visible = building
	_speed_button.visible = Game.phase == Game.Phase.BATTLE
	_order_button.visible = Game.phase == Game.Phase.BATTLE
	_speed_button.text = tr("Tempo %dx") % roundi(Game.battle_speed)
	_sound_button.text = tr("Ton aus") if Sound.muted else tr("Ton an")
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
	toast(tr("Nochmal zurück: Hauptmenü (die Runde geht verloren)"))


## Zurück-Taste (Android) bzw. Esc: erst offene Fenster schließen, dann die App beenden.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not handle_back():
		_back_to_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and handle_back():
		get_viewport().set_input_as_handled()


## Schließt das oberste offene Fenster. Gibt false zurück, wenn keins offen war.
func handle_back() -> bool:
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
	return false


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


func _build_banner_and_boss_bar(root: Control) -> void:
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
	_banner.text = tr("Erfolg: %s") % achievement_name
	_banner.modulate.a = 1.0
	if _banner_tween != null:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_interval(3.0)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.5)
	Sound.play(&"merge", 0.0)


func _build_game_over(parent: Control) -> void:
	_game_over = ColorRect.new()
	(_game_over as ColorRect).color = Color(0.05, 0.0, 0.08, 0.75)
	_game_over.size = Vector2(640, 360)
	_game_over.visible = false
	parent.add_child(_game_over)
	var board := Panel.new()
	board.position = Vector2(200, 100)
	board.size = Vector2(240, 160)
	_game_over.add_child(board)
	_game_over_label = _add_label(board, Rect2(0, 22, 240, 70), HORIZONTAL_ALIGNMENT_CENTER)
	_game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_game_over_label.add_theme_font_size_override("font_size", 18)
	_game_over_label.add_theme_color_override("font_color", UiTheme.GOLD_LIGHT)
	var again := Button.new()
	again.text = tr("Neustart")
	again.position = Vector2(20, 112)
	again.size = Vector2(95, 30)
	again.pressed.connect(func() -> void: restart_pressed.emit())
	board.add_child(again)
	var to_menu := Button.new()
	to_menu.text = tr("Hauptmenü")
	to_menu.position = Vector2(125, 112)
	to_menu.size = Vector2(95, 30)
	to_menu.pressed.connect(func() -> void: menu_pressed.emit())
	board.add_child(to_menu)
