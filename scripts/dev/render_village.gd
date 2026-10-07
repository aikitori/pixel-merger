extends Node
## Entwickler-Werkzeug: speichert das gezeichnete Dorf als vergrößertes PNG.
## Start: godot --headless res://scenes/dev/render_village.tscn -- /pfad/dorf.png

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "user://village.png"
	Village.ART.get_image().save_png(path)
	print("Dorf gespeichert: ", path)
	get_tree().quit()
