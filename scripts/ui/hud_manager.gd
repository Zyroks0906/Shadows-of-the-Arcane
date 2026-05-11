extends CanvasLayer

@onready var health_sprite: AnimatedSprite2D = %HealthSprite
@onready var mana_sprite: AnimatedSprite2D = %ManaSprite
@onready var coin_label: Label = %CoinLabel
@onready var key_label: Label = %KeyLabel

func _ready() -> void:
	if GameManager:
		GameManager.coins_changed.connect(_on_coins_changed)
		GameManager.keys_changed.connect(_on_keys_changed)
		
		# Inicializar contadores
		_on_coins_changed(GameManager.total_coins)
		_on_keys_changed(GameManager.total_keys)

# Lógica para la vida (6 frames: life1 a life6)
func update_health(current: float, maximum: float) -> void:
	if not health_sprite.sprite_frames: return
	
	var ratio = current / maximum
	# Calculamos el frame (de 0 a 5). 
	# life1 (lleno) sería frame 0, life6 (vacío) sería frame 5
	var frame_count = health_sprite.sprite_frames.get_frame_count("default")
	var target_frame = clampi(int((1.0 - ratio) * frame_count), 0, frame_count - 1)
	
	health_sprite.frame = target_frame

# Lógica para el mana (Poción azul)
func update_mana(current: float, maximum: float) -> void:
	if not mana_sprite.sprite_frames: return
	
	var ratio = current / maximum
	var frame_count = mana_sprite.sprite_frames.get_frame_count("default")
	var target_frame = clampi(int((1.0 - ratio) * frame_count), 0, frame_count - 1)
	
	mana_sprite.frame = target_frame

func _on_coins_changed(new_amount: int) -> void:
	coin_label.text = str(new_amount)

func _on_keys_changed(new_amount: int) -> void:
	key_label.text = str(new_amount) + "/3"
