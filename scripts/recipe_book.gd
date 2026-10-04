class_name RecipeBook
extends Control
## Rezeptbuch als aufgeschlagenes Buch: Ledereinband, zwei Pergamentseiten, Buchrücken und
## Lesezeichen. Zwei Kapitel (Reiter oben): alle Kombinationen und alle Entwicklungslinien mit
## den vier Hauptwerten und der Fähigkeit. Geblättert wird mit den Knöpfen unten oder per Wischen.
## Noch nicht freigeschaltete Rezepte erscheinen abgedunkelt.

signal closed
## Schnellkauf: Bündel aus Grundeinheiten {UnitData: Anzahl}, die ein Rezept bzw. eine Stufe braucht.
signal quick_buy(bundle: Dictionary)

const COVER := Rect2(16, 20, 608, 334)
const PAGE_SIZE := Vector2(284, 310)
const LEFT_POS := Vector2(30, 32)
const RIGHT_POS := Vector2(322, 32)
const HEADER_HEIGHT := 34.0
const FOOTER_HEIGHT := 24.0
## Inhaltsfläche einer Seite: x-Start außen/innen (zum Buchrücken hin mehr Rand) und Größe.
const CONTENT_X_LEFT := 16.0
const CONTENT_X_RIGHT := 28.0
const CONTENT_SIZE := Vector2(240, 252)
## Pro Seite passen vier Rezepte oder eine Linie (Gewicht 4).
const PAGE_CAPACITY := 4
const ICON_SIZE := Vector2(32, 32)
const SWIPE_DISTANCE := 40.0
const CHAPTERS := ["Kombinationen", "Linien"]
const LEATHER := Color("#5a2f16")
const PAGE_EDGE := Color("#c9aa6c")
const TITLE_COLOR := Color("#6a3d12")

var _chapter := 0
var _spread := 0
var _query := ""
## Pro Kapitel: Einträge als {node, text, weight, marks: [[Control, freischalt_runde], ...]}.
var _entries: Array = [[], []]
var _pages: Array = []  # aktuelle Seiten: Array von Array von Einträgen
var _left_box: VBoxContainer
var _right_box: VBoxContainer
var _left_number: Label
var _right_number: Label
var _prev: Button
var _next: Button
var _search: LineEdit
var _empty_notice: Label
var _chapter_buttons: Array[Button] = []
var _quick_buttons: Array[Dictionary] = []  # {button, price}
var _swipe_from := -1.0
var _flip_tween: Tween
## Anzahl entdeckter Geheimrezepte beim letzten Aufbau der Rezepte (neu entdeckte erscheinen beim Öffnen).
var _secrets_shown := -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	theme = UiTheme.make_parchment()

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.1, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ignore(dim)
	add_child(dim)

	_build_cover()
	var left := _build_page(LEFT_POS, true)
	var right := _build_page(RIGHT_POS, false)
	_left_box = left["box"]
	_right_box = right["box"]
	_left_number = left["number"]
	_right_number = right["number"]
	_prev = left["button"]
	_next = right["button"]
	_prev.text = tr("< Zurück")
	_next.text = tr("Weiter >")
	_prev.pressed.connect(func() -> void: flip(-1))
	_next.pressed.connect(func() -> void: flip(1))
	_build_header()
	_build_ribbon()
	_build_chapter_tabs()
	_build_entries()
	Game.gold_changed.connect(func(_gold: int) -> void: _refresh_quick_buttons())
	Game.phase_changed.connect(func(_phase: int) -> void: _refresh_quick_buttons())

	_empty_notice = Label.new()
	_empty_notice.text = tr("Nichts gefunden.")
	_empty_notice.add_theme_font_size_override("font_size", 11)
	_ignore(_empty_notice)


func _exit_tree() -> void:
	# Einträge, die gerade nicht auf einer Seite liegen, hängen an keinem Knoten und würden sonst leaken.
	for chapter in _entries:
		for entry: Dictionary in chapter:
			if is_instance_valid(entry.node) and entry.node.get_parent() == null:
				entry.node.free()
	if is_instance_valid(_empty_notice) and _empty_notice.get_parent() == null:
		_empty_notice.free()


func open_book() -> void:
	if Progress.discovered.size() != _secrets_shown:
		_build_recipe_entries()
	_refresh_locks()
	_refresh_quick_buttons()
	_spread = 0
	_rebuild()
	visible = true


func close_book() -> void:
	visible = false
	_search.release_focus()
	closed.emit()


## Kapitel wechseln (0 = Kombinationen, 1 = Linien).
func show_chapter(index: int) -> void:
	_chapter = clampi(index, 0, CHAPTERS.size() - 1)
	_spread = 0
	_rebuild()


## Eine Doppelseite vor (+1) oder zurück (-1).
func flip(direction: int) -> void:
	var target := clampi(_spread + direction, 0, _spread_count() - 1)
	if target == _spread:
		return
	_spread = target
	Sound.play(&"page")
	_rebuild()
	if _flip_tween != null:
		_flip_tween.kill()
	_flip_tween = create_tween().set_parallel(true)
	for box in [_left_box, _right_box]:
		box.modulate.a = 0.1
		_flip_tween.tween_property(box, "modulate:a", 1.0, 0.2)


func set_query(text: String) -> void:
	_search.text = text
	_apply_query()


func entry_count(chapter: int) -> int:
	return _entries[chapter].size()


## Einträge des Kapitels, die zur Suche passen.
func match_count(chapter: int) -> int:
	return _entries[chapter].filter(func(entry: Dictionary) -> bool: return _matches(entry)).size()


func page_count() -> int:
	return _pages.size()


# --- Aufbau: Einband und Seiten --------------------------------------------------

func _ignore(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _panel(rect: Rect2, style: StyleBox) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", style)
	_ignore(panel)
	add_child(panel)
	return panel


func _flat(fill: Color, border := Color.TRANSPARENT, width := 0, radius := 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	return box


func _build_cover() -> void:
	_panel(COVER, _flat(LEATHER, Color("#1d0e06"), 3, 5))
	var leather := TextureRect.new()
	leather.texture = _leather_texture()
	leather.position = COVER.position + Vector2(3, 3)
	leather.size = COVER.size - Vector2(6, 6)
	leather.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	leather.stretch_mode = TextureRect.STRETCH_SCALE
	_ignore(leather)
	add_child(leather)
	_panel(COVER.grow(-6), _flat(Color.TRANSPARENT, UiTheme.GOLD, 1, 3))
	var corners := [COVER.position, Vector2(COVER.end.x, COVER.position.y), Vector2(COVER.position.x, COVER.end.y), COVER.end]
	for corner: Vector2 in corners:
		var inward := Vector2(1.0 if corner.x == COVER.position.x else -1.0, 1.0 if corner.y == COVER.position.y else -1.0)
		_panel(Rect2(corner + inward * 9.0 - Vector2(4, 4), Vector2(9, 9)), _flat(UiTheme.GOLD, UiTheme.INK, 1, 1))
	# Papierkanten hinter den beiden Seiten
	var width := RIGHT_POS.x + PAGE_SIZE.x - LEFT_POS.x
	_panel(Rect2(LEFT_POS + Vector2(-3, 4), Vector2(width + 6, PAGE_SIZE.y)), _flat(Color("#b89a62"), Color("#7a5a2a"), 1, 4))
	_panel(Rect2(LEFT_POS + Vector2(-2, 2), Vector2(width + 4, PAGE_SIZE.y)), _flat(Color("#d8c08a"), Color("#9a7a42"), 1, 4))


func _leather_texture() -> ImageTexture:
	var size := Vector2i(int(COVER.size.x / 4), int(COVER.size.y / 4))
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for y in size.y:
		for x in size.x:
			var shade := rng.randf_range(-0.05, 0.05)
			img.set_pixel(x, y, LEATHER.lightened(shade) if shade > 0.0 else LEATHER.darkened(-shade))
	return ImageTexture.create_from_image(img)


## Eine Pergamentseite samt Inhaltsfläche, Seitenzahl und Blätterknopf. `left`: linke Seite.
func _build_page(pos: Vector2, left: bool) -> Dictionary:
	var style := _flat(UiTheme.PARCHMENT, PAGE_EDGE, 1, 0)
	if left:
		style.corner_radius_top_left = 6
		style.corner_radius_bottom_left = 6
	else:
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_right = 6
	var page := _panel(Rect2(pos, PAGE_SIZE), style)

	# Schatten zum Buchrücken hin
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.31, 0.17, 0.06, 0.0))
	gradient.set_color(1, Color(0.31, 0.17, 0.06, 0.42))
	var shade_texture := GradientTexture2D.new()
	shade_texture.gradient = gradient
	shade_texture.fill_from = Vector2(0, 0)
	shade_texture.fill_to = Vector2(1, 0)
	shade_texture.width = 32
	shade_texture.height = 4
	var shade := TextureRect.new()
	shade.texture = shade_texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.size = Vector2(34, PAGE_SIZE.y - 2)
	shade.position = Vector2(PAGE_SIZE.x - 35, 1) if left else Vector2(1, 1)
	shade.flip_h = not left
	_ignore(shade)
	page.add_child(shade)

	var x := CONTENT_X_LEFT if left else CONTENT_X_RIGHT
	var box := VBoxContainer.new()
	box.position = Vector2(x, HEADER_HEIGHT)
	box.size = CONTENT_SIZE
	box.add_theme_constant_override("separation", 2)
	_ignore(box)
	page.add_child(box)

	var rule := ColorRect.new()
	rule.color = PAGE_EDGE
	rule.position = Vector2(x, HEADER_HEIGHT - 4.0)
	rule.size = Vector2(CONTENT_SIZE.x, 1)
	_ignore(rule)
	page.add_child(rule)

	var footer_y := PAGE_SIZE.y - FOOTER_HEIGHT
	var number := Label.new()
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number.position = Vector2(0, footer_y)
	number.size = Vector2(PAGE_SIZE.x, FOOTER_HEIGHT - 4.0)
	_ignore(number)
	page.add_child(number)

	var button := Button.new()
	button.size = Vector2(76, 20)
	button.position = Vector2(x, footer_y) if left else Vector2(x + CONTENT_SIZE.x - button.size.x, footer_y)
	button.add_theme_font_size_override("font_size", 10)
	button.focus_mode = Control.FOCUS_NONE
	_parchment_button(button)
	page.add_child(button)
	return {"box": box, "number": number, "button": button}


func _parchment_button(button: Button) -> void:
	var normal := _flat(Color("#e6d1a0"), Color("#b99a5e"), 1, 3)
	var hover := _flat(Color("#f3e3b8"), UiTheme.GOLD, 1, 3)
	var off := _flat(Color(0.87, 0.79, 0.58, 0.5), Color(0.79, 0.67, 0.42, 0.5), 1, 3)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", off)
	button.add_theme_color_override("font_color", UiTheme.BROWN_TEXT)
	button.add_theme_color_override("font_hover_color", Color("#7a4a10"))
	button.add_theme_color_override("font_pressed_color", Color("#7a4a10"))
	button.add_theme_color_override("font_disabled_color", Color(0.35, 0.22, 0.1, 0.4))
	button.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)


func _build_header() -> void:
	var title := Label.new()
	title.text = tr("Rezeptbuch")
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	title.position = LEFT_POS + Vector2(CONTENT_X_LEFT, 8)
	title.size = Vector2(200, 24)
	_ignore(title)
	add_child(title)

	_search = LineEdit.new()
	_search.placeholder_text = tr("Suchen ...")
	_search.position = RIGHT_POS + Vector2(CONTENT_X_RIGHT, 7)
	_search.size = Vector2(CONTENT_SIZE.x, 22)
	_search.add_theme_font_size_override("font_size", 11)
	_search.text_changed.connect(func(_text: String) -> void: _apply_query())
	add_child(_search)

	var close := Button.new()
	close.text = "X"
	close.position = Vector2(COVER.end.x - 32, COVER.position.y + 3)
	close.size = Vector2(28, 19)
	close.add_theme_font_size_override("font_size", 11)
	close.pressed.connect(close_book)
	add_child(close)


## Rotes Lesezeichenband, das aus dem Buchrücken hängt.
func _build_ribbon() -> void:
	var spine := ColorRect.new()
	spine.color = Color("#4a2812")
	spine.position = Vector2(LEFT_POS.x + PAGE_SIZE.x, LEFT_POS.y)
	spine.size = Vector2(RIGHT_POS.x - LEFT_POS.x - PAGE_SIZE.x, PAGE_SIZE.y)
	_ignore(spine)
	add_child(spine)
	var x := LEFT_POS.x + PAGE_SIZE.x - 3.0
	var top := LEFT_POS.y - 10.0
	var band := Polygon2D.new()
	band.polygon = PackedVector2Array([Vector2(x, top), Vector2(x + 14, top), Vector2(x + 14, top + 66),
			Vector2(x + 7, top + 57), Vector2(x, top + 66)])
	band.color = Color("#b3202a")
	add_child(band)
	var fold := Polygon2D.new()
	fold.polygon = PackedVector2Array([Vector2(x, top), Vector2(x + 7, top), Vector2(x + 7, top + 57), Vector2(x, top + 66)])
	fold.color = Color("#8a1620")
	add_child(fold)


## Kapitelreiter oben am Einband.
func _build_chapter_tabs() -> void:
	for i in CHAPTERS.size():
		var tab := Button.new()
		tab.text = CHAPTERS[i]
		tab.position = Vector2(COVER.position.x + 24 + i * 112, 2)
		tab.size = Vector2(108, 19)
		tab.add_theme_font_size_override("font_size", 10)
		tab.focus_mode = Control.FOCUS_NONE
		var index := i
		tab.pressed.connect(func() -> void: show_chapter(index))
		add_child(tab)
		_chapter_buttons.append(tab)
	_style_chapter_tabs()


func _style_chapter_tabs() -> void:
	for i in _chapter_buttons.size():
		var tab := _chapter_buttons[i]
		var active := i == _chapter
		var style := _flat(UiTheme.PARCHMENT if active else Color("#7a4a26"), UiTheme.INK, 2, 4)
		style.corner_radius_bottom_left = 0
		style.corner_radius_bottom_right = 0
		for state in ["normal", "hover", "pressed", "disabled"]:
			tab.add_theme_stylebox_override(state, style)
		tab.add_theme_color_override("font_color", UiTheme.BROWN_TEXT if active else UiTheme.CREAM)
		tab.add_theme_color_override("font_hover_color", UiTheme.BROWN_TEXT if active else Color.WHITE)
		tab.add_theme_color_override("font_pressed_color", UiTheme.BROWN_TEXT)
		tab.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)


## Kleiner Schnellkauf-Knopf für ein Bündel (nur in der Bauphase und mit genug Gold bedienbar).
func _quick_button(bundle: Dictionary) -> Button:
	var price := Registry.bundle_price(bundle)
	var button := Button.new()
	button.text = tr("Schnellkauf %dg") % price
	button.add_theme_font_size_override("font_size", 9)
	button.focus_mode = Control.FOCUS_NONE
	_parchment_button(button)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := button.get_theme_stylebox(state) as StyleBoxFlat
		style.content_margin_left = 5
		style.content_margin_right = 5
		style.content_margin_top = 1
		style.content_margin_bottom = 1
	var parts: Array[String] = []
	for unit: UnitData in bundle:
		parts.append("%dx %s" % [bundle[unit], unit.display_name])
	button.tooltip_text = tr("Kauft alle Grundeinheiten: %s\n%d Einheiten, %dg. Verbinden machst du selbst.") % [
		", ".join(parts), Registry.bundle_size(bundle), price]
	button.pressed.connect(func() -> void: quick_buy.emit(bundle))
	_quick_buttons.append({"button": button, "price": price})
	return button


func _refresh_quick_buttons() -> void:
	for entry in _quick_buttons:
		var button: Button = entry["button"]
		if is_instance_valid(button):
			button.disabled = Game.phase != Game.Phase.BUILD or Game.gold < entry["price"]


# --- Einträge ---------------------------------------------------------------------

func _build_entries() -> void:
	_build_recipe_entries()
	for start in Registry.shop_units():
		_entries[1].append(_line_entry(start))


## Kapitel "Kombinationen". Unentdeckte Geheimrezepte stehen als "???" am Ende.
func _build_recipe_entries() -> void:
	for entry: Dictionary in _entries[0]:
		var node: Control = entry.node
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.queue_free()
	_entries[0].clear()
	_quick_buttons.assign(_quick_buttons.filter(func(item: Dictionary) -> bool:
		return is_instance_valid(item.button) and not (item.button as Node).is_queued_for_deletion()))
	var recipes: Array[RecipeData] = []
	for recipe in Registry.recipes:
		if recipe.ingredient_a != recipe.ingredient_b:
			recipes.append(recipe)
	recipes.sort_custom(func(a: RecipeData, b: RecipeData) -> bool:
		if Progress.is_hidden(a) != Progress.is_hidden(b):
			return Progress.is_hidden(b)
		if a.unlock_round != b.unlock_round:
			return a.unlock_round < b.unlock_round
		return a.result.display_name < b.result.display_name)
	for recipe in recipes:
		_entries[0].append(_secret_entry(recipe) if Progress.is_hidden(recipe) else _recipe_entry(recipe))
	_secrets_shown = Progress.discovered.size()
	if is_instance_valid(_left_box):
		_refresh_quick_buttons()


func _secret_entry(recipe: RecipeData) -> Dictionary:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	for part in ["?", "+", "?", "="]:
		row.add_child(_label(part, 16 if part == "?" else 12, false))
	var icon := _icon(recipe.result)
	icon.texture = UiTheme.silhouette(recipe.result.sprite)
	icon.tooltip_text = tr("Ein Geheimrezept!")
	row.add_child(icon)
	var title := _label(tr("Geheimrezept"), 11, false)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	column.add_child(row)
	column.add_child(_label(tr("Noch nicht entdeckt. Probiere ungewöhnliche Paare aus!"), 9))
	return {"node": column, "weight": 1, "marks": [], "text": (tr("Geheimrezept") + " ???").to_lower()}


func _recipe_entry(recipe: RecipeData) -> Dictionary:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.add_child(_icon(recipe.ingredient_a))
	row.add_child(_label("+", 12, false))
	row.add_child(_icon(recipe.ingredient_b))
	row.add_child(_label("=", 12, false))
	row.add_child(_icon(recipe.result))
	var title := _label(recipe.result.display_name, 11, false)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	column.add_child(row)
	var ability := "" if recipe.result.ability == &"" else "  ·  " + Abilities.label(recipe.result.ability)
	column.add_child(_label(tr("%dg  ·  ab Runde %d%s") % [recipe.merge_cost, recipe.unlock_round, ability], 9))
	var stats_row := HBoxContainer.new()
	var stats := _label(recipe.result.stats_text(), 9)
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_row.add_child(stats)
	var bundle := Registry.merge_counts(Registry.base_units(recipe.ingredient_a), Registry.base_units(recipe.ingredient_b))
	if not bundle.is_empty():
		stats_row.add_child(_quick_button(bundle))
	column.add_child(stats_row)
	column.tooltip_text = _recipe_tooltip(recipe)
	return {
		"node": column, "weight": 1, "marks": [[column, recipe.unlock_round]],
		"text": ("%s %s %s %s %s" % [recipe.ingredient_a.display_name, recipe.ingredient_b.display_name,
				_stage_names(recipe.result), Abilities.display_name(recipe.result.ability), recipe.result.line_name]).to_lower(),
	}


func _recipe_tooltip(recipe: RecipeData) -> String:
	var text := tr("%s + %s = %s\nStufen: %s") % [recipe.ingredient_a.display_name, recipe.ingredient_b.display_name,
			recipe.result.display_name, _stage_names(recipe.result).replace(" ", " > ")]
	if recipe.result.ability != &"":
		text += "\n%s: %s" % [Abilities.label(recipe.result.ability), Abilities.description(recipe.result.ability)]
	return text


func _line_entry(start: UnitData) -> Dictionary:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 1)
	var header := _label("%s: %s (%dg)" % [tr(start.category), start.line_name, start.price], 12)
	header.add_theme_color_override("font_color", TITLE_COLOR)
	column.add_child(header)
	var marks: Array = []
	var names: Array[String] = [start.line_name, start.category]
	var unit := start
	while unit != null:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.add_child(_icon(unit))
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 0)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ability := "" if unit.ability == &"" else "  ·  " + Abilities.label(unit.ability)
		info.add_child(_label(tr("Stufe %d: %s%s") % [unit.level, unit.display_name, ability], 10))
		info.add_child(_label(unit.stats_text(), 9))
		var last_row := HBoxContainer.new()
		if unit.upgrade != null:
			var upgrade := _label(tr("2x = %s (%dg, ab Rd. %d)") % [
				unit.upgrade.display_name, unit.upgrade_cost, unit.upgrade.unlock_round], 9)
			upgrade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			last_row.add_child(upgrade)
		else:
			var filler := Control.new()
			filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			last_row.add_child(filler)
		if unit.level > 1:  # Schnellkauf: alle Grundeinheiten, aus denen sich diese Stufe verbinden lässt
			last_row.add_child(_quick_button(Registry.base_units(unit)))
		if last_row.get_child_count() > 1 or unit.upgrade != null:
			info.add_child(last_row)
		else:
			last_row.queue_free()
		row.add_child(info)
		row.tooltip_text = "%s\n%s" % [Abilities.label(unit.ability), Abilities.description(unit.ability)]
		column.add_child(row)
		marks.append([row, unit.unlock_round if unit.level > 1 else 0])
		names.append(unit.display_name)
		unit = unit.upgrade
	return {"node": column, "weight": PAGE_CAPACITY, "marks": marks, "text": " ".join(names).to_lower()}


func _icon(unit: UnitData) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = unit.sprite
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.tooltip_text = "%s (%s)\n%s" % [unit.display_name, unit.line_name, unit.stats_text()]
	return icon


## `trim`: zu langer Text wird mit "..." gekürzt, statt die Seite zu verbreitern.
func _label(text: String, size: int, trim := true) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	if trim:
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.custom_minimum_size.x = 10.0
	return label


func _stage_names(result: UnitData) -> String:
	var names: Array[String] = []
	var unit := result
	while unit != null:
		names.append(unit.display_name)
		unit = unit.upgrade
	return " ".join(names)


# --- Seiten ---------------------------------------------------------------------

func _matches(entry: Dictionary) -> bool:
	return _query.is_empty() or (entry.text as String).contains(_query)


func _apply_query() -> void:
	_query = _search.text.strip_edges().to_lower()
	_spread = 0
	_rebuild()


## Noch gesperrte Rezepte (Runde nicht erreicht) abdunkeln.
func _refresh_locks() -> void:
	for chapter in _entries:
		for entry: Dictionary in chapter:
			for mark: Array in entry.marks:
				(mark[0] as Control).modulate.a = 0.5 if mark[1] > Game.round_number else 1.0


func _spread_count() -> int:
	return maxi(1, ceili(_pages.size() / 2.0))


## Seiten neu einteilen (Kapitel und Suche) und die aktuelle Doppelseite zeigen.
func _rebuild() -> void:
	_pages.clear()
	var current: Array = []
	var used := 0
	for entry: Dictionary in _entries[_chapter]:
		if not _matches(entry):
			continue
		if used + entry.weight > PAGE_CAPACITY and not current.is_empty():
			_pages.append(current)
			current = []
			used = 0
		current.append(entry)
		used += entry.weight
	if not current.is_empty():
		_pages.append(current)
	_spread = clampi(_spread, 0, _spread_count() - 1)
	for box in [_left_box, _right_box]:
		for child in box.get_children():
			box.remove_child(child)
	if _pages.is_empty():
		_left_box.add_child(_empty_notice)
	_fill(_left_box, _spread * 2)
	_fill(_right_box, _spread * 2 + 1)
	_left_number.text = "- %d -" % (_spread * 2 + 1)
	_right_number.text = "- %d -" % (_spread * 2 + 2) if _spread * 2 + 1 < _pages.size() else ""
	_prev.disabled = _spread == 0
	_next.disabled = _spread >= _spread_count() - 1
	_style_chapter_tabs()


func _fill(box: VBoxContainer, page_index: int) -> void:
	if page_index >= _pages.size():
		return
	for entry: Dictionary in _pages[page_index]:
		box.add_child(entry.node)


# --- Wischen zum Blättern ---------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if event.pressed:
		_swipe_from = event.position.x
	elif _swipe_from >= 0.0:
		var distance: float = event.position.x - _swipe_from
		_swipe_from = -1.0
		if distance <= -SWIPE_DISTANCE:
			flip(1)
		elif distance >= SWIPE_DISTANCE:
			flip(-1)
