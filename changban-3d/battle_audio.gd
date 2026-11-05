extends Node

# Short, locally synthesized layers. A soft noisy tail keeps the spear distinct
# from the high, two-note sound of striking a shield.
const RATE := 22050
const CUES := {
	"swish": [0.16, 175.0, -22.0], "impact": [0.19, 104.0, -15.0],
	"steel": [0.28, 689.0, -20.0], "break": [0.37, 208.0, -16.0],
	"hurt": [0.25, 79.0, -19.0], "dodge": [0.18, 130.0, -25.0],
	"warn": [0.22, 237.0, -23.0], "rescue": [0.56, 392.0, -20.0],
	"clear": [0.83, 293.66, -18.0],
	"coil": [0.23, 146.83, -23.0], "sweep": [0.27, 246.94, -21.0],
	"point": [0.19, 440.0, -22.0], "parry": [0.28, 698.46, -22.0],
}
var sounds: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var cursor := 0

func _ready() -> void:
	for cue in CUES:
		sounds[cue] = _render(cue, CUES[cue][0], CUES[cue][1])
	for i in 8:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)

func play(cue: String) -> void:
	if not sounds.has(cue) or DisplayServer.get_name() == "headless":
		return
	var voice := voices[cursor]
	cursor = (cursor + 1) % voices.size()
	voice.stream = sounds[cue]
	voice.volume_db = CUES[cue][2]
	voice.play()

func silence() -> void:
	for voice in voices:
		voice.stop()

func _render(cue: String, duration: float, freq: float) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11237
	var samples := int(duration * RATE)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var smooth_noise := 0.0
	for i in samples:
		var t := float(i) / RATE
		var u := t / duration
		var noise := rng.randf_range(-1.0, 1.0)
		smooth_noise = lerpf(smooth_noise, noise, 0.19)
		var env := minf(1.0, t * 620.0) * pow(1.0 - u, 2.3)
		var tone := sin(TAU * freq * t)
		var sample := 0.0
		match cue:
			"swish", "dodge":
				sample = (smooth_noise * 1.7 + noise * 0.12) * sin(PI * pow(u, 0.66))
			"coil", "sweep":
				var slide := 0.55 + u * (1.04 if cue == "coil" else 0.42)
				sample = (smooth_noise * 1.3 + sin(TAU * freq * t * slide) * 0.28) * sin(PI * u)
			"point":
				sample = (sin(TAU*freq*t*(1.65-0.57*u))*0.40 + smooth_noise*1.7) * sin(PI*pow(u,0.65))
			"parry":
				sample = tone*0.34 + sin(TAU*freq*2.50*t)*0.18 + smooth_noise*exp(-28.0*t)*0.35
			"impact", "hurt":
				sample = (sin(TAU * freq * t * (1.8 - u * 0.7)) * 0.7 + smooth_noise * 0.9)
			"steel":
				sample = tone * 0.33 + sin(TAU * freq * 2.69 * t) * 0.25 + noise * exp(-55.0 * t) * 0.45
			"break":
				sample = tone * 0.34 + sin(TAU * freq * 3.12 * t) * 0.18 + noise * exp(-18.0 * t) * 0.56
			"warn":
				sample = tone * 0.44 + sin(TAU * freq * 1.5 * t) * 0.12
			"rescue", "clear":
				var step := [1.0, 1.25, 1.5] if cue == "clear" else [1.0, 1.5]
				var n := mini(int(u * step.size()), step.size() - 1)
				var local := fmod(t, duration / step.size())
				sample = sin(TAU * freq * step[n] * local) * minf(local * 200.0, 1.0) * exp(-6.0 * local) * 0.66
		data.encode_s16(i * 2, int(clampf(sample * env, -1.0, 1.0) * 26500))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream
