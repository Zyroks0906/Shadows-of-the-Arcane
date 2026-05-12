extends CanvasLayer

@onready var health_sprite: AnimatedSprite2D = %HealthSprite
@onready var mana_sprite: AnimatedSprite2D = %ManaSprite
@onready var coin_label: Label = %CoinLabel
@onready var key_label: Label = %KeyLabel
@onready var health_potion_label: Label = %HealthPotionLabel
@onready var mana_potion_label: Label = %ManaPotionLabel
@onready var interaction_prompt: Label = %InteractionPrompt

func _ready() -> void:
	add_to_group("hud")
	
	if GameManager:
		GameManager.coins_changed.connect(_on_coins_changed)
		GameManager.keys_changed.connect(_on_keys_updated)
		GameManager.silver_keys_changed.connect(_on_keys_updated)
		GameManager.golden_keys_changed.connect(_on_keys_updated)
		GameManager.health_potions_changed.connect(_on_health_potions_changed)
		GameManager.mana_potions_changed.connect(_on_mana_potions_changed)
		
		_on_coins_changed(GameManager.total_coins)
		_on_keys_updated(0)
		_on_health_potions_changed(GameManager.health_potions)
		_on_mana_potions_changed(GameManager.mana_potions)

func update_health(current: float, maximum: float) -> void:
	if not health_sprite or not health_sprite.sprite_frames: return
	
	var ratio = clamp(float(current) / float(maximum), 0.0, 1.0)
	
	
	
	var total_frames = 6
	var target_frame = int((1.0 - ratio) * (total_frames - 1))
	
	
	if ratio > 0.01 and target_frame == 5:
		target_frame = 4
		
	health_sprite.frame = clamp(target_frame, 0, 5)
	print("HUD: Salud actualizada -> ", current, "/", maximum, " (Frame: ", health_sprite.frame, ")")

func update_mana(current: float, maximum: float) -> void:
	if not mana_sprite or not mana_sprite.sprite_frames: return
	
	var ratio = clamp(float(current) / float(maximum), 0.0, 1.0)
	var total_frames = 6
	var target_frame = int((1.0 - ratio) * (total_frames - 1))
	
	if ratio > 0.01 and target_frame == 5:
		target_frame = 4
		
	mana_sprite.frame = clamp(target_frame, 0, 5)

func _on_coins_changed(new_amount: int) -> void:
	coin_label.text = str(new_amount)

func _on_keys_updated(_val: int) -> void:
	var total = GameManager.total_keys + GameManager.silver_keys + GameManager.golden_keys
	key_label.text = str(total) + "/3"

func _on_health_potions_changed(new_amount: int) -> void:
	health_potion_label.text = str(new_amount)

func _on_mana_potions_changed(new_amount: int) -> void:
	mana_potion_label.text = str(new_amount)

func show_interaction_prompt(show: bool, text: String = "[F] INTERACT") -> void:
	if interaction_prompt:
		interaction_prompt.text = text
		interaction_prompt.visible = show
