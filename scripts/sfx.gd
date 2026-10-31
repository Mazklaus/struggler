extends Node
## Sons de synthèse pour le prototype gris : aucun fichier audio n'est nécessaire.
## Chaque son est généré une fois au démarrage, puis joué par un petit lot de lecteurs.

const RATE := 22050

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	# L'enclume : le signal de la Cadence, clair et court.
	_sounds["enclume"] = _bell([1900.0, 3100.0, 4700.0], [0.5, 0.25, 0.15], 0.18, 0.0)
	_sounds["enclume_doux"] = _bell([1900.0, 3100.0], [0.18, 0.08], 0.10, 0.0)
	_sounds["cadence"] = _bell([1250.0, 2500.0, 3760.0], [0.55, 0.3, 0.2], 0.35, 0.0)
	_sounds["rate"] = _bell([180.0, 233.0], [0.5, 0.4], 0.16, 0.25)
	_sounds["coup"] = _thump(110.0, 0.14, 0.6)
	_sounds["coup_lourd"] = _thump(70.0, 0.28, 0.9)
	_sounds["garde"] = _bell([820.0, 1310.0, 2150.0], [0.45, 0.35, 0.2], 0.14, 0.15)
	_sounds["contre"] = _bell([1560.0, 2340.0, 3900.0], [0.6, 0.4, 0.3], 0.5, 0.05)
	_sounds["glas"] = _bell([220.0, 440.0, 528.0, 660.0, 880.0], [0.7, 0.5, 0.35, 0.3, 0.2], 1.6, 0.1)
	_sounds["trempe"] = _noise(0.5, 0.35, 6000.0)
	_sounds["souffle"] = _noise(0.12, 0.25, 2500.0)
	_sounds["blesse"] = _thump(160.0, 0.2, 0.7, 0.4)
	_sounds["panse"] = _bell([523.0, 659.0, 784.0], [0.3, 0.25, 0.2], 0.45, 0.0)
	_sounds["mort"] = _thump(55.0, 0.6, 0.9, 0.5)
	_sounds["mur"] = _noise(0.4, 0.6, 1200.0)


func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not _sounds.has(sound):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _sounds[sound]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func _make(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav


## Son métallique : somme de partiels qui décroissent, un peu de bruit à l'attaque.
func _bell(freqs: Array, amps: Array, length: float, grit: float) -> AudioStreamWAV:
	var n := int(length * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for k in freqs.size():
			v += sin(TAU * freqs[k] * t) * amps[k] * exp(-t * (6.0 + k * 4.0) / length)
		v += randf_range(-1.0, 1.0) * grit * exp(-t * 60.0)
		s[i] = v * 0.6
	return _make(s)


## Coup sourd : sinus qui chute en fréquence, avec un peu de bruit.
func _thump(freq: float, length: float, noise: float, drop := 0.6) -> AudioStreamWAV:
	var n := int(length * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := freq * (1.0 - drop * t / length)
		phase += TAU * f / RATE
		var env := exp(-t * 7.0 / length)
		s[i] = (sin(phase) + randf_range(-1.0, 1.0) * noise * exp(-t * 40.0)) * env * 0.8
	return _make(s)


## Souffle ou vapeur : bruit filtré grossièrement.
func _noise(length: float, amp: float, cutoff: float) -> AudioStreamWAV:
	var n := int(length * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var a := clampf(cutoff / RATE * TAU, 0.0, 1.0)
	var y := 0.0
	for i in n:
		var t := float(i) / RATE
		y += a * (randf_range(-1.0, 1.0) - y)
		var env := minf(t * 30.0, 1.0) * exp(-t * 4.0 / length)
		s[i] = y * amp * env * 3.0
	return _make(s)
