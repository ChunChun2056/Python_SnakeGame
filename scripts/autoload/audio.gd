extends Node
## Music and sound effect playback with user volume settings.

const SFX_VOICES := 10

var _music: AudioStreamPlayer
var _music_name := ""
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = AudioStreamPlayer.new()
	add_child(_music)
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	apply_volumes()


func _vol(key: String) -> float:
	var v: float = Game.setting(key)
	return linear_to_db(max(v, 0.0001)) if v > 0.001 else -80.0


func apply_volumes() -> void:
	_music.volume_db = _vol("music") - 4.0
	for p in _voices:
		p.volume_db = _vol("sfx")


func play_music(track: String) -> void:
	if track == _music_name and _music.playing:
		return
	_music_name = track
	var path := "res://assets/audio/music_%s.ogg" % track
	if not ResourceLoader.exists(path):
		_music.stop()
		return
	var stream: AudioStreamOggVorbis = load(path)
	stream.loop = true
	_music.stream = stream
	_music.play()


func stop_music() -> void:
	_music_name = ""
	_music.stop()


func duck_music(on: bool) -> void:
	_music.volume_db = _vol("music") - (16.0 if on else 4.0)


func sfx(sound: String, pitch: float = 1.0) -> void:
	var stream: AudioStream = _cache.get(sound)
	if stream == null:
		var path := "res://assets/audio/sfx_%s.wav" % sound
		if not ResourceLoader.exists(path):
			return
		stream = load(path)
		_cache[sound] = stream
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % SFX_VOICES
	p.stream = stream
	p.pitch_scale = pitch
	p.play()
