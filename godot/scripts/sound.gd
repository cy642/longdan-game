extends Node
## Small precomputed PCM cues keep audio local and work in desktop and Web exports.
var cache: Dictionary = {}
var channels: Array = []
var next_channel = 0
var muted = false
var last_step = 0

func _ready() -> void:
	for i in range(10):
		var player = AudioStreamPlayer.new(); player.volume_db = -8; add_child(player); channels.append(player)
	var settings = {"step":[110,.035,.07],"swing":[420,.11,.16],"heavy":[180,.18,.22],"ultimate":[240,.35,.24],"hit":[190,.09,.21],"hurt":[100,.16,.2],"enemy":[270,.13,.13],"enemy_heavy":[130,.23,.15],"ready":[680,.035,.035],"dash":[570,.12,.12],"perfect":[880,.25,.2],"break":[330,.24,.22],"kill":[260,.13,.15],"heal":[660,.4,.13],"ignite":[155,.18,.15],"explosion":[70,.42,.25],"phase":[150,.55,.19],"victory":[520,.7,.16]}
	for key in settings:
		var s = settings[key]; cache[key] = make_cue(s[0],s[1],s[2],key)

func make_cue(frequency: float, duration: float, volume: float, type: String) -> AudioStreamWAV:
	var samples = int(duration*22050); var data = PackedByteArray(); data.resize(samples*2)
	var random = RandomNumberGenerator.new(); random.seed = 874
	for i in range(samples):
		var t = float(i)/22050; var progress = t/duration
		var envelope = minf(1,t/.006)*pow(1-progress,2)
		var tone = sin(TAU*frequency*t*(1-.32*progress))*.6+sin(TAU*frequency*2*t)*.15
		if type in ["step","swing","dash","hit","break","explosion","enemy","heavy","enemy_heavy"]:
			tone = tone*.35+random.randf_range(-1,1)*.65
		elif type in ["heal","perfect","victory"]:
			tone = sin(TAU*frequency*t)*.45+sin(TAU*frequency*1.25*t)*.25+sin(TAU*frequency*1.5*t)*.2
		data.encode_s16(i*2,int(clampf(tone*envelope*volume,-1,1)*32767))
	var stream = AudioStreamWAV.new(); stream.format = AudioStreamWAV.FORMAT_16_BITS; stream.mix_rate = 22050; stream.data = data
	return stream

func play_cue(key: String) -> void:
	if muted or not cache.has(key): return
	if key=="step":
		if Time.get_ticks_msec()-last_step<100: return
		last_step = Time.get_ticks_msec()
	var channel = channels[next_channel]; next_channel = (next_channel+1)%channels.size()
	channel.stream = cache[key]; channel.play()

func _exit_tree() -> void:
	for channel in channels:
		channel.stop(); channel.stream=null
	cache.clear()
