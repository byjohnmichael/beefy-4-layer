extends Node
## Procedurally synthesized sound effects (autoloaded as `Sfx`).
## Everything is generated at startup into AudioStreamWAV buffers - no audio
## assets, no licenses, restyle by regenerating. Flat, soft, card-table-y.

const MIX_RATE := 44100
const POOL_SIZE := 8

var _streams: Dictionary = {}
var _players: Array = []
var _next_player := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 0xBEEF  # deterministic noise -> identical sounds every launch
	_streams = {
		"tap": _make_tap(),
		"slide": _make_slide(),
		"place": _make_place(),
		"flip": _make_flip(),
		"fail": _make_fail(),
		"win": _make_win(),
		"lose": _make_lose(),
		"shuffle": _make_shuffle(),
		"coin": _make_coin(),
	}
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)


## Play a named sound. `pitch` lets repeated sounds (deals, chains) vary a
## little so they don't feel machine-gunned.
func play(sound_name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var stream: AudioStreamWAV = _streams.get(sound_name)
	if stream == null:
		return
	var player: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.play()


# ---------------------------------------------------------------- synthesis

func _make_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	return wav


func _buffer(seconds: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(seconds * MIX_RATE))
	return samples


## Filtered noise burst: the basis of most card sounds. `brightness` is the
## one-pole lowpass coefficient (0..1, higher = brighter).
func _add_noise(
	samples: PackedFloat32Array, start: float, length: float,
	gain: float, brightness: float, attack := 0.004
) -> void:
	var begin := int(start * MIX_RATE)
	var count := int(length * MIX_RATE)
	var lp := 0.0
	for i in count:
		var idx := begin + i
		if idx >= samples.size():
			break
		var t := float(i) / count
		var env := minf(t * length / attack, 1.0) * pow(1.0 - t, 2.2)
		lp += brightness * (_rng.randf_range(-1.0, 1.0) - lp)
		samples[idx] += lp * env * gain


## Decaying sine partial.
func _add_tone(
	samples: PackedFloat32Array, start: float, length: float,
	freq: float, gain: float, attack := 0.003
) -> void:
	var begin := int(start * MIX_RATE)
	var count := int(length * MIX_RATE)
	for i in count:
		var idx := begin + i
		if idx >= samples.size():
			break
		var t := float(i) / count
		var env := minf((t * length) / attack, 1.0) * pow(1.0 - t, 3.0)
		samples[idx] += sin(TAU * freq * i / MIX_RATE) * env * gain


func _make_tap() -> AudioStreamWAV:
	var s := _buffer(0.06)
	_add_tone(s, 0.0, 0.05, 1500.0, 0.18, 0.001)
	_add_noise(s, 0.0, 0.025, 0.10, 0.5, 0.001)
	return _make_stream(s)


func _make_slide() -> AudioStreamWAV:
	var s := _buffer(0.14)
	_add_noise(s, 0.0, 0.13, 0.22, 0.18, 0.02)
	return _make_stream(s)


func _make_place() -> AudioStreamWAV:
	var s := _buffer(0.12)
	_add_noise(s, 0.0, 0.05, 0.25, 0.35, 0.002)
	_add_tone(s, 0.0, 0.09, 170.0, 0.30, 0.002)
	return _make_stream(s)


func _make_flip() -> AudioStreamWAV:
	var s := _buffer(0.22)
	_add_noise(s, 0.0, 0.09, 0.16, 0.30, 0.015)
	_add_noise(s, 0.10, 0.09, 0.22, 0.45, 0.008)
	return _make_stream(s)


func _make_fail() -> AudioStreamWAV:
	var s := _buffer(0.35)
	_add_tone(s, 0.0, 0.16, 392.0, 0.16)
	_add_tone(s, 0.14, 0.20, 311.1, 0.18)
	return _make_stream(s)


func _make_win() -> AudioStreamWAV:
	var s := _buffer(0.9)
	var notes: Array = [523.25, 659.25, 783.99, 1046.5]  # C5 E5 G5 C6
	for k in notes.size():
		_add_tone(s, k * 0.11, 0.5, notes[k], 0.16)
		_add_tone(s, k * 0.11, 0.4, notes[k] * 2.0, 0.05)
	return _make_stream(s)


func _make_lose() -> AudioStreamWAV:
	var s := _buffer(0.8)
	var notes: Array = [523.25, 415.3, 349.23]  # C5 Ab4 F4
	for k in notes.size():
		_add_tone(s, k * 0.16, 0.45, notes[k], 0.16)
	return _make_stream(s)


func _make_shuffle() -> AudioStreamWAV:
	var s := _buffer(0.5)
	for k in 6:
		_add_noise(s, k * 0.07, 0.06, 0.16 + 0.02 * (k % 3), 0.25, 0.006)
	return _make_stream(s)


func _make_coin() -> AudioStreamWAV:
	var s := _buffer(0.6)
	for k in 5:
		_add_tone(s, k * 0.09, 0.10, 1200.0 + 150.0 * (k % 2), 0.10, 0.002)
	_add_tone(s, 0.45, 0.14, 880.0, 0.14)
	return _make_stream(s)
