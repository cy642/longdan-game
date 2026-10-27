extends Node
## Small precomputed PCM cues keep audio local and work in desktop and Web exports.
var cache: Dictionary = {}
var channels: Array = []
var next_channel = 0
var footstep_channel: AudioStreamPlayer
var variation = RandomNumberGenerator.new()
var muted = false:
	set(value):
		muted = value
		if value:
			for channel in channels: channel.stop()
			if is_instance_valid(footstep_channel): footstep_channel.stop()
var footsteps_enabled = true:
	set(value):
		footsteps_enabled = value
		if not value and is_instance_valid(footstep_channel): footstep_channel.stop()
var last_step = -1000
var last_contact: Dictionary = {}

func _ready() -> void:
	for i in range(10):
		var player = AudioStreamPlayer.new(); player.volume_db = -8; add_child(player); channels.append(player)
	footstep_channel = AudioStreamPlayer.new(); footstep_channel.name = "Footsteps"
	footstep_channel.volume_db = -20; add_child(footstep_channel)
	variation.seed = 4529
	var settings = {"step":[72,.055,.07],"swing":[420,.11,.16],"heavy":[180,.18,.22],"ultimate":[240,.35,.24],"hit":[190,.09,.21],"hurt":[100,.16,.2],"enemy":[270,.13,.13],"enemy_heavy":[130,.23,.15],"ready":[680,.035,.035],"dash":[570,.12,.12],"perfect":[880,.25,.2],"break":[330,.24,.22],"kill":[260,.13,.15],"heal":[660,.4,.13],"ignite":[155,.18,.15],"explosion":[70,.42,.25],"phase":[150,.55,.19],"victory":[520,.7,.16]}
	for key in settings:
		var s = settings[key]; cache[key] = make_cue(s[0],s[1],s[2],key)
	cache["drum"]=make_cue(68,.7,.32,"drum")
	var contacts = {"contact_light":[540,.105,.17],"contact_heavy":[170,.18,.20],"contact_counter":[690,.21,.18],"contact_guard":[810,.14,.13],"contact_break":[235,.26,.20]}
	for key in contacts:
		var s = contacts[key]; cache[key]=make_cue(s[0],s[1],s[2],key)

func make_cue(frequency: float, duration: float, volume: float, type: String) -> AudioStreamWAV:
	var samples = int(duration*22050); var data = PackedByteArray(); data.resize(samples*2)
	var random = RandomNumberGenerator.new(); random.seed = 874
	var low_noise = 0.0; var soft_noise = 0.0
	for i in range(samples):
		var t = float(i)/22050; var progress = t/duration
		var envelope = minf(1,t/.006)*pow(1-progress,2)
		var tone = sin(TAU*frequency*t*(1-.32*progress))*.6+sin(TAU*frequency*2*t)*.15
		if type == "step":
			# Two low-pass stages remove the sharp hiss from the old noise click.
			low_noise += (random.randf_range(-1,1) - low_noise) * .12
			soft_noise += (low_noise - soft_noise) * .12
			tone = sin(TAU*frequency*t*(1-.32*progress)) * .48 + soft_noise * .52
			envelope = minf(1,t/.01) * pow(1-progress,2.5)
		elif type == "drum":
			low_noise += (random.randf_range(-1,1)-low_noise)*.2
			tone=sin(TAU*frequency*t*(1-.4*progress))*.8+low_noise*.2
			envelope=minf(1,t/.004)*pow(1-progress,3)
		elif type.begins_with("contact_"):
			# Damped, slightly inharmonic steel plus a low body transient. Each
			# strike has its own silhouette in sound; no full-volume white hiss.
			low_noise += (random.randf_range(-1,1)-low_noise)*.3
			soft_noise += (low_noise-soft_noise)*.07
			var metal=sin(TAU*frequency*t)*.34+sin(TAU*frequency*1.43*t)*.19+sin(TAU*frequency*2.71*t)*.08
			var body=sin(TAU*(83 if type=="contact_heavy" else 115)*t*(1-.25*progress))
			var grit=(low_noise-soft_noise)*exp(-t*55)
			tone=metal*exp(-t*14)+body*.28*exp(-t*25)+grit*.65
			if type=="contact_guard": tone=metal*exp(-t*23)+grit*.3
			elif type=="contact_counter": tone=metal*.8+sin(TAU*frequency*.5*t)*.17+grit*.45
			elif type=="contact_break":
				var crack=exp(-pow((t-.025)/.009,2))+exp(-pow((t-.065)/.012,2))*.55
				tone=metal*exp(-t*17)+body*.4+low_noise*crack*.9
			envelope=minf(1,t/.0035)*pow(1-progress,1.8)
		elif type in ["swing","heavy"]:
			low_noise += (random.randf_range(-1,1)-low_noise)*.38
			soft_noise += (low_noise-soft_noise)*.055
			tone=(low_noise-soft_noise)*1.4+sin(TAU*frequency*.5*t)*.06
			envelope=pow(sin(PI*progress),1.5)*(1-progress*.55)
		elif type in ["dash","hit","break","explosion","enemy","enemy_heavy"]:
			tone = tone*.35+random.randf_range(-1,1)*.65
		elif type in ["heal","perfect","victory"]:
			tone = sin(TAU*frequency*t)*.45+sin(TAU*frequency*1.25*t)*.25+sin(TAU*frequency*1.5*t)*.2
		data.encode_s16(i*2,int(clampf(tone*envelope*volume,-1,1)*32767))
	var stream = AudioStreamWAV.new(); stream.format = AudioStreamWAV.FORMAT_16_BITS; stream.mix_rate = 22050; stream.data = data
	return stream

func play_contact(key: String) -> bool:
	if muted or not key.begins_with("contact_") or not cache.has(key): return false
	var now = Time.get_ticks_msec()
	# Several simultaneous targets cannot fill all ten voices with the same
	# contact. Different guard-break accents remain eligible in the same frame.
	if now-int(last_contact.get(key,-1000)) < 28: return false
	last_contact[key]=now
	play_cue(key)
	return true

func play_cue(key: String) -> void:
	if muted or not cache.has(key): return
	if key=="step":
		if not footsteps_enabled or Time.get_ticks_msec()-last_step<180: return
		last_step = Time.get_ticks_msec()
		footstep_channel.pitch_scale = variation.randf_range(.94,1.06)
		footstep_channel.stream = cache[key]; footstep_channel.play()
		return
	# Prefer a free combat channel so new cues do not cut off existing feedback.
	var selected = next_channel
	for offset in range(channels.size()):
		var candidate = (next_channel+offset)%channels.size()
		if not channels[candidate].playing: selected = candidate; break
	var channel = channels[selected]; next_channel = (selected+1)%channels.size()
	channel.stream = cache[key]; channel.play()

func _exit_tree() -> void:
	if is_instance_valid(footstep_channel): footstep_channel.stop(); footstep_channel.stream=null
	for channel in channels:
		channel.stop(); channel.stream=null
	cache.clear()
