extends Node
## Soundeffekte und Musik (Autoload "Sound"). Die WAV-Dateien erzeugt tools/generate_audio.py.
## Die Musik wechselt mit der Spielphase, Effekte haben ein Limit pro Sekunde, damit viele
## gleichzeitige Angriffe nicht zu Lärm werden.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const SETTINGS_PATH := "user://settings.cfg"
const VOICES := 12
const MUSIC_DB := -9.0
const SILENT_DB := -60.0
const FADE_SECONDS := 0.8
## Lautstärke (dB) und Mindestabstand (Sekunden) pro Effekt.
const SFX_SETTINGS := {
	&"swing": [-8.0, 0.07], &"hit": [-6.0, 0.05], &"arrow": [-9.0, 0.07], &"fireball": [-8.0, 0.12], &"heal": [-9.0, 0.12], &"page": [-9.0, 0.05],
	&"explode": [-6.0, 0.08], &"death": [-7.0, 0.06], &"coin": [-9.0, 0.08], &"buy": [-6.0, 0.0],
	&"merge": [-4.0, 0.0], &"click": [-10.0, 0.03], &"error": [-6.0, 0.1],
	&"battle_start": [-5.0, 0.0], &"round_win": [-4.0, 0.0], &"game_over": [-3.0, 0.0],
}

var muted := false:
	set(value):
		muted = value
		AudioServer.set_bus_mute(0, muted)
		_save_settings()
		muted_changed.emit(muted)

signal muted_changed(is_muted: bool)

var _sfx: Dictionary = {}
var _music: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _last_played: Dictionary = {}
var _music_player: AudioStreamPlayer
var _music_name: StringName = &""
var _fade: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for id in SFX_SETTINGS:
		var stream := _load("%s%s.wav" % [SFX_DIR, id])
		if stream != null:
			_sfx[id] = stream
	for id in [&"build", &"battle"]:
		var stream := _load("%s%s.wav" % [MUSIC_DIR, id]) as AudioStreamWAV
		if stream != null:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = stream.data.size() / 2  # 16 Bit mono: Samples = Bytes / 2
			_music[id] = stream
	for i in VOICES:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		_voices.append(voice)
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = SILENT_DB
	add_child(_music_player)
	_load_settings()
	AudioServer.set_bus_mute(0, muted)
	# Jeder Knopf im Spiel klickt, ohne dass die Oberfläche etwas davon wissen muss.
	get_tree().node_added.connect(_on_node_added)
	Game.phase_changed.connect(_on_phase_changed)
	Game.gold_changed.connect(_on_gold_changed)
	_last_gold = Game.gold
	_on_phase_changed(Game.phase)


var _last_gold := 0
## Tests ohne Audiogerät spielen nichts ab, sonst meldet Godot beim Beenden noch genutzte Streams.
var _headless := DisplayServer.get_name() == "headless"


func has_sound(id: StringName) -> bool:
	return _sfx.has(id)


func has_music(id: StringName) -> bool:
	return _music.has(id)


func play(id: StringName, pitch_jitter := 0.06) -> void:
	var stream: AudioStream = _sfx.get(id)
	if stream == null or _headless:
		return
	var settings: Array = SFX_SETTINGS[id]
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(id, -10.0)) < float(settings[1]):
		return
	for voice in _voices:
		if not voice.playing:
			_last_played[id] = now
			voice.stream = stream
			voice.volume_db = settings[0]
			voice.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
			voice.play()
			return


## Wechselt die Musik mit Überblendung. &"" = Stille.
func set_music(id: StringName) -> void:
	if id == _music_name:
		return
	_music_name = id
	if _headless:
		return
	if _fade != null:
		_fade.kill()
	_fade = create_tween()
	if _music_player.playing:
		_fade.tween_property(_music_player, "volume_db", SILENT_DB, FADE_SECONDS * 0.5)
	_fade.tween_callback(func() -> void:
		_music_player.stop()
		var stream: AudioStream = _music.get(id)
		if stream != null:
			_music_player.stream = stream
			_music_player.volume_db = SILENT_DB
			_music_player.play()
			create_tween().tween_property(_music_player, "volume_db", MUSIC_DB, FADE_SECONDS))


func _on_phase_changed(phase: int) -> void:
	match phase:
		Game.Phase.BUILD:
			set_music(&"build")
		Game.Phase.BATTLE:
			set_music(&"battle")
			play(&"battle_start", 0.0)
		Game.Phase.GAME_OVER:
			set_music(&"")
			play(&"game_over", 0.0)


func _on_gold_changed(gold: int) -> void:
	if gold > _last_gold and Game.phase == Game.Phase.BATTLE:
		play(&"coin", 0.1)
	_last_gold = gold


func _on_node_added(node: Node) -> void:
	if node is Button:
		(node as Button).pressed.connect(func() -> void: play(&"click", 0.03))


func _load(path: String) -> AudioStream:
	return load(path) as AudioStream if ResourceLoader.exists(path) else null


func _notification(what: int) -> void:
	# Android/iOS: im Hintergrund still sein.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		AudioServer.set_bus_mute(0, true)
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		AudioServer.set_bus_mute(0, muted)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		muted = bool(config.get_value("audio", "muted", false))


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("audio", "muted", muted)
	config.save(SETTINGS_PATH)


func _exit_tree() -> void:
	# Beim Beenden Streams loslassen, sonst meldet Godot Ressourcen "still in use".
	for voice in _voices:
		voice.stop()
		voice.stream = null
	if _fade != null:
		_fade.kill()
	_music_player.stop()
	_music_player.stream = null
	_music_player.free()
	for voice in _voices:
		voice.free()
	_sfx.clear()
	_music.clear()
