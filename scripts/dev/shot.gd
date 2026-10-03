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
