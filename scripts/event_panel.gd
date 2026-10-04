class_name EventPanel
extends Control
## Ereignis zwischen den Runden: drei Karten zur Auswahl und "Weiterziehen" (siehe RoundEvents).

signal chosen(offer: Dictionary)
signal skipped

const CARD_SIZE := Vector2(176, 186)

var _cards: HBoxContainer
var _title: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.1, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_title = Label.new()
	_title.position = Vector2(120, 30)
	_title.size = Vector2(400, 24)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 14)
	_title.add_theme_color_override("font_color", UiTheme.GOLD_LIGHT)
	_title.add_theme_stylebox_override("normal", UiTheme.sign_style())
	add_child(_title)
	_cards = HBoxContainer.new()
	_cards.position = Vector2(30, 64)
	_cards.size = Vector2(580, CARD_SIZE.y)
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.add_theme_constant_override("separation", 8)
	add_child(_cards)
	var skip := Button.new()
	skip.text = tr("Weiterziehen")
	skip.position = Vector2(260, 258)
	skip.size = Vector2(120, 28)
	skip.pressed.connect(func() -> void:
		close_panel()
		skipped.emit())
	add_child(skip)


func open_panel(offers: Array[Dictionary]) -> void:
	for child in _cards.get_children():
		child.queue_free()
	_title.text = tr("Ein Fremder kreuzt deinen Weg")
	for offer in offers:
		_cards.add_child(_card(offer))
	visible = true


func close_panel() -> void:
	visible = false


func _card(offer: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	card.add_child(column)
	var title := Label.new()
	title.text = offer["title"]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", UiTheme.GOLD_LIGHT)
	column.add_child(title)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(0, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = offer["icon"]
	column.add_child(icon)
	var text := Label.new()
	text.text = offer["text"]
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(CARD_SIZE.x - 14, 0)
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("font_size", 10)
	column.add_child(text)
	var button := Button.new()
	var cost: int = offer["cost"]
	button.text = tr("Wählen (%dg)") % cost if cost > 0 else tr("Wählen")
	button.disabled = not offer["enabled"]
	if button.disabled:
		button.tooltip_text = tr("Zu wenig Gold")
	button.pressed.connect(func() -> void:
		close_panel()
		chosen.emit(offer))
	column.add_child(button)
	return card
