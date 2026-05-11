extends Node


enum Element { NONE, PYRO, HYDRO, ELECTRO, CRYO, ANEMO }

const REACTION_DATA = {
	"Vaporize": {"multiplier": 2.0, "color": Color.ORANGE_RED},
	"Melt": {"multiplier": 2.0, "color": Color.CORAL},
	"Electro-Charged": {"multiplier": 1.5, "color": Color.MEDIUM_PURPLE},
	"Overloaded": {"multiplier": 1.5, "color": Color.CRIMSON},
	"Superconduct": {"multiplier": 1.2, "color": Color.CYAN},
	"Frozen": {"multiplier": 1.0, "color": Color.LIGHT_BLUE},
	"Swirl": {"multiplier": 1.2, "color": Color.AQUAMARINE},
	"None": {"multiplier": 1.0, "color": Color.WHITE}
}

func get_element_name(element: Element) -> String:
	match element:
		Element.PYRO: return "Pyro"
		Element.HYDRO: return "Hydro"
		Element.ELECTRO: return "Electro"
		Element.CRYO: return "Cryo"
		Element.ANEMO: return "Anemo"
		_: return "None"

func get_reaction(element_1: Element, element_2: Element) -> Dictionary:
	if element_1 == Element.NONE or element_2 == Element.NONE:
		return {"name": "None", "data": REACTION_DATA["None"]}
	
	if element_1 == element_2:
		return {"name": "None", "data": REACTION_DATA["None"]}

	
	if (element_1 == Element.PYRO and element_2 == Element.HYDRO) or (element_1 == Element.HYDRO and element_2 == Element.PYRO):
		var mult = 2.0 if element_1 == Element.HYDRO else 1.5
		var data = REACTION_DATA["Vaporize"].duplicate()
		data["multiplier"] = mult
		return {"name": "Vaporize", "data": data}
		
	if (element_1 == Element.PYRO and element_2 == Element.CRYO) or (element_1 == Element.CRYO and element_2 == Element.PYRO):
		var mult = 2.0 if element_1 == Element.PYRO else 1.5
		var data = REACTION_DATA["Melt"].duplicate()
		data["multiplier"] = mult
		return {"name": "Melt", "data": data}

	if (element_1 == Element.HYDRO and element_2 == Element.ELECTRO) or (element_1 == Element.ELECTRO and element_2 == Element.HYDRO):
		return {"name": "Electro-Charged", "data": REACTION_DATA["Electro-Charged"]}

	if (element_1 == Element.PYRO and element_2 == Element.ELECTRO) or (element_1 == Element.ELECTRO and element_2 == Element.PYRO):
		return {"name": "Overloaded", "data": REACTION_DATA["Overloaded"]}

	if (element_1 == Element.CRYO and element_2 == Element.ELECTRO) or (element_1 == Element.ELECTRO and element_2 == Element.CRYO):
		return {"name": "Superconduct", "data": REACTION_DATA["Superconduct"]}

	if (element_1 == Element.HYDRO and element_2 == Element.CRYO) or (element_1 == Element.CRYO and element_2 == Element.HYDRO):
		return {"name": "Frozen", "data": REACTION_DATA["Frozen"]}

	if element_1 == Element.ANEMO or element_2 == Element.ANEMO:
		return {"name": "Swirl", "data": REACTION_DATA["Swirl"]}

	return {"name": "None", "data": REACTION_DATA["None"]}
