extends SceneTree
## Exercise production audio routes without producing sound on the user's speakers.
const Sound = preload("res://scripts/sound.gd")
var failures: Array = []
var checks = 0

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message); push_error("FAIL: " + message)

func statistics(stream: AudioStreamWAV) -> Dictionary:
	var samples = stream.data.size()/2
	var energy = 0.0; var delta_energy = 0.0; var previous = 0.0
	for i in range(samples):
		var sample = stream.data.decode_s16(i*2)/32768.0
		energy += sample*sample; delta_energy += (sample-previous)*(sample-previous)
		previous = sample
	return {"rms": sqrt(energy/samples), "roughness": sqrt(delta_energy/maxf(energy,.000001))}

func run() -> void:
	AudioServer.add_bus()
	var bus = AudioServer.bus_count-1
	AudioServer.set_bus_name(bus,"SilentAudioQA"); AudioServer.set_bus_mute(bus,true)
	var sound = Sound.new(); root.add_child(sound)
	for channel in sound.channels: channel.bus = "SilentAudioQA"
	sound.footstep_channel.bus = "SilentAudioQA"
	await process_frame
	var step = statistics(sound.cache.step)
	var swing = statistics(sound.cache.swing)
	var audible_step = step.rms*db_to_linear(sound.footstep_channel.volume_db)
	var audible_swing = swing.rms*db_to_linear(sound.channels[0].volume_db)
	expect(audible_step < audible_swing*.3,"footsteps remain well below weapon feedback")
	expect(step.roughness < .2,"footsteps do not contain the old sharp broadband noise")
	expect(sound.cache.step.data.decode_s16(0)==0,"footstep starts without an abrupt click")
	sound.play_cue("step")
	expect(sound.footstep_channel.playing and sound.next_channel==0,"footsteps use their own route without consuming combat channels")
	var pitch = sound.footstep_channel.pitch_scale
	sound.play_cue("step")
	expect(sound.footstep_channel.pitch_scale==pitch,"rapid duplicate footfalls are suppressed")
	sound.play_cue("heavy")
	var combat_channel = sound.channels[0]
	sound.footsteps_enabled=false
	expect(not sound.footstep_channel.playing and combat_channel.playing,"disabling footsteps preserves combat sound")
	sound.last_step=-1000; sound.play_cue("step")
	expect(not sound.footstep_channel.playing,"disabled footsteps stay silent")
	sound.footsteps_enabled=true; sound.play_cue("step")
	sound.muted=true
	expect(not sound.footstep_channel.playing and not combat_channel.playing,"mute stops already-playing steps and combat cues immediately")
	sound.muted=false; sound.play_cue("swing")
	expect(sound.channels[1].playing,"combat audio resumes after unmute")
	print("AUDIO_VERIFY ",checks," checks; ",failures.size()," failures; footstep-to-swing RMS ratio ",snappedf(audible_step/audible_swing,.001))
	sound.queue_free(); await process_frame; await process_frame
	# Let the audio mixing thread release stopped playback resources before exit.
	await create_timer(.12).timeout; AudioServer.remove_bus(bus)
	quit(0 if failures.is_empty() else 1)
