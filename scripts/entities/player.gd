extends BaseCharacter
class_name Player

## Velocidad de movimiento del jugador en píxeles por segundo.
@export var speed: float = 200.0

# Nodos requeridos (según lo pedido)
@onready var element_icon: Sprite2D = $ElementIcon
@onready var element_timer: Timer = $ElementTimer

# Precargar la escena de texto flotante
const FLOATING_TEXT_SCENE: PackedScene = preload("res://scenes/ui/floating_text.tscn")

func _ready() -> void:
	super._ready()
	# Configurar el temporizador si no está configurado en el editor
	if element_timer:
		element_timer.one_shot = true
		element_timer.timeout.connect(_on_element_timer_timeout)
	
	if element_icon:
		element_icon.visible = false

func _physics_process(_delta: float) -> void:
	if not is_alive:
		return
	
	_handle_movement()

## Gestiona la entrada de usuario y el movimiento físico del CharacterBody2D.
func _handle_movement() -> void:
	# Input.get_vector maneja automáticamente la normalización para movimiento diagonal.
	var direction: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	velocity = direction * speed
	move_and_slide()

# El jugador recibe un golpe de un enemigo con un elemento
func aplicar_elemento(nuevo_elemento: ElementalSystem.Element) -> void:
	if nuevo_elemento == ElementalSystem.Element.NONE:
		return
	
	if current_imbued_element == ElementalSystem.Element.NONE:
		# Primera imbuición
		current_imbued_element = nuevo_elemento
		actualizar_icono_elemento()
		element_timer.start(3.0) # Dura 3 segundos
	else:
		# Segunda imbuición -> Procesar Reacción
		procesar_reaccion(nuevo_elemento)

func procesar_reaccion(segundo_elemento: ElementalSystem.Element) -> void:
	var reaction_info: Dictionary = ElementalSystem.get_reaction(current_imbued_element, segundo_elemento)
	var reaction_name: String = reaction_info["name"]
	var data: Dictionary = reaction_info["data"]
	
	if reaction_name != "None":
		# Aplicar multiplicador de daño (aquí podrías recibir el daño base como parámetro)
		# Por ahora mostramos el feedback
		mostrar_texto_flotante(reaction_name, data["color"])
		
		# Consumir el estado elemental
		limpiar_elemento()
	else:
		# Si no hay reacción (mismo elemento), refrescamos el timer
		if current_imbued_element == segundo_elemento:
			element_timer.start(3.0)

func mostrar_texto_flotante(texto: String, color: Color) -> void:
	if FLOATING_TEXT_SCENE:
		var ft: Node2D = FLOATING_TEXT_SCENE.instantiate()
		get_parent().add_child(ft) # Añadir a la escena raíz del nivel
		ft.global_position = global_position + Vector2(0, -50) # Sobre la cabeza
		if ft.has_method("set_text"):
			ft.set_text(texto, color)

func actualizar_icono_elemento() -> void:
	if element_icon:
		element_icon.visible = true
		# Aquí cargarías la textura correspondiente (opcional por ahora)
		pass

func limpiar_elemento() -> void:
	current_imbued_element = ElementalSystem.Element.NONE
	if element_icon:
		element_icon.visible = false
	if element_timer:
		element_timer.stop()

func _on_element_timer_timeout() -> void:
	limpiar_elemento()

## Sobrescribe la recepción de daño para incluir lógica elemental.
func take_elemental_hit(damage: int, element: ElementalSystem.Element) -> void:
	receive_damage(damage)
	aplicar_elemento(element)
