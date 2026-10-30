extends HBoxContainer
class_name RelicBar

# The relics owned this run, as a row of pixel icons under the health bar. Hover one for
# its name and effect; a completed synergy outlines both of its relics in gold.

const POS := Vector2(16, 78)

func _ready() -> void:
	position = POS
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Progression.relics_changed.connect(_rebuild)
	_rebuild()

func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	for id in Relics.owned():
		var d: Dictionary = Relics.DATA[id]
		var slot := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.06, 0.05, 0.08, 0.85)
		sb.border_color = Color(1.0, 0.82, 0.35) if _in_synergy(id) else Color(d["color"], 0.6)
		sb.set_border_width_all(1)
		sb.content_margin_left = 1
		sb.content_margin_right = 1
		sb.content_margin_top = 1
		sb.content_margin_bottom = 1
		slot.add_theme_stylebox_override("panel", sb)
		slot.tooltip_text = "%s\n%s" % [d["name"], d["text"]]
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		var tr := TextureRect.new()
		tr.texture = Relics.icon(id, 3)
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(tr)
		add_child(slot)

func _in_synergy(id: String) -> bool:
	for s in Relics.SYNERGIES:
		if id in Relics.SYNERGIES[s]["needs"] and Relics.has_synergy(s):
			return true
	return false
