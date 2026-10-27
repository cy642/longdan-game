extends RefCounted
## Contact presentation only. Attack definitions and damage stay authoritative.

static func contact(key: String, blocked: bool, broke_shield: bool, broke_poise: bool) -> Dictionary:
	if broke_shield or broke_poise:
		return {"style":"break","cue":"contact_break","rank":4,"radius":29.0,"life":.26}
	if blocked:
		return {"style":"guard","cue":"contact_guard","rank":2,"radius":17.0,"life":.18}
	if key == "counter":
		return {"style":"counter","cue":"contact_counter","rank":3,"radius":26.0,"life":.23}
	if key in ["thrust3","sweep","huilan","sword"]:
		return {"style":"heavy","cue":"contact_heavy","rank":2,"radius":24.0,"life":.22}
	return {"style":"light","cue":"contact_light","rank":1,"radius":16.0,"life":.15}
