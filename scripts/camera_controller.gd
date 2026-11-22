extends Node3D

@onready var cam_arm = $WorldArm/Camera3D
@onready var cam_hand = $WorldHand/Camera3D

var arm_node: Node
var hand_node: Node
var vista_actual = "arm"

func _ready() -> void:
	# Buscar los nodos con paciencia
	arm_node = $WorldArm/PlayerArm
	hand_node = $WorldHand/PlayerHand
	
	print("🔍 arm_node = ", arm_node)
	print("🔍 hand_node = ", hand_node)
	
	if arm_node == null:
		push_error("No se encontró PlayerArm en WorldArm")
	if hand_node == null:
		push_error("No se encontró PlayerHand en WorldHand")
	
	_activar_arm()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_UP:
			print("🔑 KEY_UP presionado")
			_cambiar_vista()

func _cambiar_vista() -> void:
	if vista_actual == "arm":
		_activar_hand()
	else:
		_activar_arm()

func _activar_arm() -> void:
	print("➡️ _activar_arm() llamado")
	if hand_node != null:
		print("   → Llamando hand_node.set_active(false)")
		hand_node.set_active(false)
	if arm_node != null:
		print("   → Llamando arm_node.set_active(true)")
		arm_node.set_active(true)
	
	$WorldArm.visible = true
	$WorldHand.visible = false
	
	cam_arm.current = true
	cam_hand.current = false
	
	vista_actual = "arm"
	print("🦾 BRAZO")

func _activar_hand() -> void:
	print("➡️ _activar_hand() llamado")
	if arm_node != null:
		print("   → Llamando arm_node.set_active(false)")
		arm_node.set_active(false)
	if hand_node != null:
		print("   → Llamando hand_node.set_active(true)")
		hand_node.set_active(true)
	else:
		print("   ⚠️ hand_node es NULL!")
	
	$WorldArm.visible = false
	$WorldHand.visible = true
	
	cam_arm.current = false
	cam_hand.current = true
	
	vista_actual = "hand"
	print("👋 MANO")
