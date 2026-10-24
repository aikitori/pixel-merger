class_name UnitCard
extends PanelContainer
## Karte der gewählten oder gehaltenen Einheit oben links: Porträt, Stufe, Leben, Erfahrung, Werte, Fähigkeiten.

var icon: TextureRect
var title: Label
var hp_fill: ColorRect
var hp_text: Label
var xp_fill: ColorRect
var xp_text: Label
var stats: Label
var ability_label: Label
var _key := ""


func _ready() -> void:
	position = Vector2(4, 28)
	size = Vector2(150, 10)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var style := UiTheme.sign_style()
	style.modulate_color = Color(1, 1, 1, 0.94)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(140, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	column.add_child(icon)
	title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", UiTheme.GOLD_LIGHT)
	column.add_child(title)
	var bar := ColorRect.new()
	bar.color = Color(0.1, 0.04, 0.02, 0.9)
	bar.custom_minimum_size = Vector2(140, 10)
	column.add_child(bar)
	hp_fill = ColorRect.new()
	hp_fill.color = Color("#4fbf4a")
	hp_fill.position = Vector2(1, 1)
	hp_fill.size = Vector2(138, 8)
	bar.add_child(hp_fill)
	hp_text = Label.new()
	hp_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_text.add_theme_font_size_override("font_size", 8)
	bar.add_child(hp_text)
	# Erfahrungsleiste der Veteranenstufe
	var xp_bar := ColorRect.new()
	xp_bar.color = Color(0.1, 0.04, 0.02, 0.9)
	xp_bar.custom_minimum_size = Vector2(140, 8)
	column.add_child(xp_bar)
	xp_fill = ColorRect.new()
	xp_fill.color = Color("#5fb8ff")
	xp_fill.position = Vector2(1, 1)
	xp_fill.size = Vector2(0, 6)
	xp_bar.add_child(xp_fill)
	xp_text = Label.new()
	xp_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	xp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	xp_text.add_theme_font_size_override("font_size", 7)
	xp_bar.add_child(xp_text)
	stats = Label.new()
	stats.add_theme_font_size_override("font_size", 9)
	column.add_child(stats)
	ability_label = Label.new()
	ability_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ability_label.custom_minimum_size = Vector2(140, 0)
	ability_label.add_theme_font_size_override("font_size", 8)
	ability_label.add_theme_constant_override("line_spacing", -2)
	ability_label.add_theme_color_override("font_color", Color("#d8c8a0"))
	column.add_child(ability_label)


## `unit` null blendet die Karte aus. Wird jeden Frame aufgerufen, setzt daher nur Änderungen.
func show_unit(unit: Combatant, extra := 0) -> void:
	if unit == null or not is_instance_valid(unit) or unit.unit_data == null:
		if visible:
			visible = false
			_key = ""
		return
	var data := unit.unit_data
	var ability_text := ""
	if unit.ability != &"":
		ability_text = "* %s: %s" % [Abilities.label(unit.ability), Abilities.description(unit.ability)]
	if unit.veteran_ability != &"":
		ability_text += "\n" + tr("* Veteran: %s: %s") % [Abilities.display_name(unit.veteran_ability), Abilities.description(unit.veteran_ability)]
	var key := "%s|%d|%d|%d|%s|%s|%d|%d" % [data.id, unit.level, ceili(unit.health), ceili(unit.max_health), unit.order_text(), Loc.language, extra, unit.xp]
	if key == _key and visible:
		return
	_key = key
	icon.texture = data.sprite
	title.text = "%s (%s %d)%s" % [unit.display_name, tr("Stufe"), unit.level, unit.order_text()]
	if extra > 0:
		title.text += "  +%d" % extra
	var share := clampf(unit.health / maxf(unit.max_health, 1.0), 0.0, 1.0)
	hp_fill.size.x = 138.0 * share
	hp_fill.color = Color("#4fbf4a") if share > 0.5 else (Color("#e0b030") if share > 0.25 else Color("#d04a3a"))
	hp_text.text = "%d / %d" % [ceili(unit.health), ceili(unit.max_health)]
	var progress := unit.veteran_progress()
	if progress[1] == 0:
		xp_fill.size.x = 138.0
		xp_text.text = tr("Veteran %d (höchste Stufe)") % unit.veteran_level
	else:
		xp_fill.size.x = 138.0 * progress[0] / progress[1]
		xp_text.text = tr("Veteran %d  ·  %d/%d EP") % [unit.veteran_level, progress[0], progress[1]]
	stats.text = tr("Stä %s  Bew %s  Int %s") % [UnitData.format_number(unit.attack),
			UnitData.format_number(unit.move_speed), UnitData.format_number(unit.intelligence)]
	ability_label.text = ability_text
	ability_label.visible = ability_text != ""
	size = Vector2(150, 10)
	visible = true
