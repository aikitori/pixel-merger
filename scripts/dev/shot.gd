extends Node
## Entwickler-Werkzeug: speichert Screenshots der Oberfläche (braucht ein Fenster, z.B. Xvfb).
## Start: godot res://scenes/dev/shot.tscn -- <Ordner> [ansicht ...]
## Ansichten: bau, dorf, haus, buch, buch2, linien, kampf

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var folder: String = args[0] if args.size() > 0 else "user://"
	var views: Array = args.slice(1, 2) if args.size() > 2 else args.slice(1) if args.size() > 1 else ["bau", "dorf", "haus", "buch", "linien", "kampf"]
	var original_language := Loc.language
	if OS.get_environment("SHOT_LANG") != "":
		Loc.set_language(OS.get_environment("SHOT_LANG"))
	if OS.get_environment("SHOT_STYLE") != "":
		ArtStyle.set_style(StringName(OS.get_environment("SHOT_STYLE")))
		Game.refresh_art_style()
	var arena: Node = load("res://scenes/main.tscn").instantiate()
	add_child(arena)
	await _frames(5)
	var hud: Hud = arena.get("_hud")
	for unit_id in ["crusader", "sharpshooter", "archmage", "doctor", "warhorse", "shadow_wolf"]:
		arena.buy_unit(Registry.units[unit_id])
	await _frames(3)
	for view: String in views:
		match view:
			"bau":
				pass
			"merge":
				var pick: RecipeData = null
				for recipe in Registry.recipes:
					if recipe.ingredient_a != recipe.ingredient_b and recipe.result.ability != &"" and recipe.ingredient_a.ability != &"":
						pick = recipe
						break
				hud.show_merge_preview(pick.ingredient_a, pick.ingredient_b, pick.result, "Kosten: %dg" % pick.merge_cost, false)
			"karte":
				for node in get_tree().get_nodes_in_group("arena"):
					pass
				var found: Array = arena.find_children("*", "Combatant", true, false)
				found[0].set_xp(29)
				found[0].health = found[0].max_health * 0.6
				for i in range(1, found.size()):
					found[i].set_xp([3, 8, 14, 20, 63][i % 5])
				arena._select(found[0])
			"gelaende":
				World.set_stage(0)
				arena._build_obstacles()
			"rezepte":
				var picks: Array = arena.find_children("*", "Combatant", true, false)
				arena._begin_drag(picks[0].position - Vector2(0, 8))
			"gruppe":
				Game.set_phase(Game.Phase.BATTLE)
				arena._spawn_timer = 99999.0
				arena._battle_time_left = 99999.0
				arena._select_in_rect(Rect2(250, 100, 140, 120), false)
				arena._box_active = true
				arena._box_start = Vector2(230, 90)
				arena._pointer = Vector2(420, 230)
			"wetter":
				Game.set_modifier(StringName(OS.get_environment("SHOT_MOD") if OS.get_environment("SHOT_MOD") != "" else "snow"))
				Game.set_phase(Game.Phase.BATTLE)
				arena._spawn_timer = 0.0
				arena._battle_time_left = 99999.0
				await _frames(90)
			"ereignis":
				Game.round_number = 6
				Game.gold = 60
				var picks: Array[Dictionary] = []
				for id: StringName in [&"merchant", &"smith", &"gamble"]:
					picks.append(RoundEvents.build(id, arena))
				hud.show_event(picks)
			"dorf":
				hud._village.visible = true
			"haus":
				hud._village.visible = true
				hud._village.open_category("Fantasy")
			"buch":
				hud._village.visible = false
				hud._shop.close_panel()
				hud._book.open_book()
			"buch2":
				hud._book.open_book()
				hud._book.flip(1)
			"linien":
				hud._book.open_book()
				hud._book.show_chapter(1)
			"boss":
				hud._book.close_book()
				hud._village.visible = false
				Game.round_number = 5
				Game.gold = 0
				arena.start_battle()
				await _frames(int(args[2]) if args.size() > 2 else 240)
			"einheiten":
				# Einheiten-Galerie: Grundeinheiten und Kombinationen vergrößert auf Gras
				var gallery := CanvasLayer.new()
				gallery.layer = 60
				var ground := ColorRect.new()
				ground.color = Color("#4fb04a")
				ground.size = Vector2(640, 360)
				gallery.add_child(ground)
				var ids := ["peasant", "knight", "crusader", "archer", "sharpshooter", "mage", "archmage", "healer",
						"doctor", "horse", "warhorse", "shadow_wolf", "fenrir", "wyrmling", "witch", "dwarf_warrior",
						"skeleton", "lich_king", "phoenix", "thor", "medusa", "kraken", "anubis", "valkyrie"]
				for i in ids.size():
					if not Registry.units.has(ids[i]):
						continue
					var icon := TextureRect.new()
					icon.texture = Registry.units[ids[i]].sprite
					icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
					icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					icon.position = Vector2(14 + (i % 8) * 77, 12 + (i / 8) * 116)
					icon.size = Vector2(72, 96)
					gallery.add_child(icon)
				add_child(gallery)
			"erfolge":
				hud._achievements.open_panel()
			"menue":
				arena.queue_free()
				var menu: Node = load("res://scenes/menu.tscn").instantiate()
				add_child(menu)
				await _frames(10)
			"kampf":
				hud._book.close_book()
				hud._village.visible = false
				Game.gold = 40
				arena.start_battle()
				await _frames(120)
		await _frames(4)
		var image := get_viewport().get_texture().get_image()
		image.save_png("%s/%s.png" % [folder, view])
		print("Screenshot: ", view)
	Loc.set_language(original_language)
	get_tree().quit()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
