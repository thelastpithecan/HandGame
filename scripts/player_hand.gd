extends CharacterBody3D

@onready var skeleton: Skeleton3D = $mano/Skeleton3D

const CHANNEL_COUNT: int = 24
const PORT: int = 12345

var bone_order: Array[String] = [
	"Metacarpo1", "FalangesProximales1", "FalangesDistales1",
	"Metacarpo2", "FalangesProximales2", "FalangesMedias2", "FalangesDistales2",
	"Metacarpo3", "FalangesProximales3", "FalangesMedias3", "FalangesDistales3",
	"Metacarpo4", "FalangesProximales4", "FalangesMedias4", "FalangesDistales4",
	"Metacarpo5", "FalangesProximales5", "FalangesMedias5", "FalangesDistales5"
]

var finger_bones: Dictionary = {}
var finger_rest: Dictionary = {}
var finger_current: Dictionary = {}

var bone_wrist: int = -1
var wrist_rest: Quaternion = Quaternion.IDENTITY
var wrist_current: Quaternion = Quaternion.IDENTITY

var udp: PacketPeerUDP = PacketPeerUDP.new()
var is_active_receiver := false

var wrist_smooth_speed: float = 38.0
var finger_smooth_speed: float = 45.0
var grip_assist_scale: float = 0.25

var cfg: Dictionary = {}

func _ready() -> void:
	_init_config()
	_init_skeleton()
	set_active(true)

func _init_skeleton() -> void:
	bone_wrist = skeleton.find_bone("Carpo")
	if bone_wrist != -1:
		wrist_rest = skeleton.get_bone_pose_rotation(bone_wrist)
		wrist_current = wrist_rest
		print("✅ Muñeca encontrada")
	
	for n: String in bone_order:
		var idx: int = skeleton.find_bone(n)
		if idx == -1:
			print("❌ Hueso no encontrado:", n)
			continue
		finger_bones[n] = idx
		var rq: Quaternion = skeleton.get_bone_pose_rotation(idx)
		finger_rest[n] = rq
		finger_current[n] = rq
	print("✅ Huesos cargados:", finger_bones.size())

func set_active(v: bool) -> void:
	if v == is_active_receiver:
		return
	is_active_receiver = v
	if v:
		var err := udp.bind(PORT, "0.0.0.0")
		print("📡 UDP bind:", err)
	else:
		udp.close()

func _process(delta: float) -> void:
	if not is_active_receiver:
		return
	
	if udp.get_available_packet_count() == 0:
		return
	
	var latest: PackedFloat32Array = udp.get_packet().to_float32_array()
	
	while udp.get_available_packet_count() > 0:
		latest = udp.get_packet().to_float32_array()
	
	if latest.size() < CHANNEL_COUNT:
		return
	
	_apply_wrist(float(latest[0]), float(latest[1]), delta)
	
	var grip: float = float(latest[21]) / 100.0
	
	var finger_idx: int = 0
	for i in range(2, 21):
		if finger_idx >= bone_order.size():
			break
		var bone_name: String = bone_order[finger_idx]
		if finger_bones.has(bone_name):
			_apply_finger(bone_name, float(latest[i]), grip, delta)
		finger_idx += 1

func _apply_wrist(x: float, y: float, delta: float) -> void:
	if bone_wrist == -1:
		return
	var rx: Quaternion = Quaternion(Vector3.RIGHT, deg_to_rad(clampf(x, -45.0, 45.0)))
	var ry: Quaternion = Quaternion(Vector3.UP, deg_to_rad(clampf(y, -55.0, 55.0)))
	var t: float = clampf(wrist_smooth_speed * delta, 0.0, 0.85)
	var target: Quaternion = wrist_rest * ry * rx
	wrist_current = wrist_current.slerp(target, t)
	skeleton.set_bone_pose_rotation(bone_wrist, wrist_current)

func _apply_finger(bone_name: String, raw_angle: float, grip: float, delta: float) -> void:
	var c: Dictionary = cfg[bone_name]
	var idx: int = finger_bones[bone_name]
	var rest_q: Quaternion = finger_rest[bone_name]
	
	var axis: Vector3 = c["axis"]
	var sign: float = c["sign"]
	var min_angle: float = c["min"]
	var max_angle: float = c["max"]
	
	var angle: float = raw_angle
	
	# Asistencia de grip SOLO para dedos normales
	if not bone_name.begins_with("Metacarpo") and not bone_name == "FalangesProximales1":
		angle += grip * grip_assist_scale * max_angle * 0.7
	
	angle = clampf(angle, min_angle, max_angle)
	
	var target: Quaternion = rest_q * Quaternion(axis, deg_to_rad(sign * angle))
	var t: float = clampf(finger_smooth_speed * delta, 0.0, 0.85)
	var q: Quaternion = finger_current[bone_name].slerp(target, t)
	
	finger_current[bone_name] = q
	skeleton.set_bone_pose_rotation(idx, q)

func _init_config() -> void:
	# ============================================================
	# 🟢 PULGAR - CORREGIDO (falanges doblan hacia ADELANTE)
	# ============================================================
	# Metacarpo1: OPOSICIÓN (movimiento lateral)
	cfg["Metacarpo1"] = {"axis": Vector3.FORWARD, "sign": -1.0, "min": -45.0, "max": 45.0}
	
	# FalangesProximales1: CAMBIADO sign = -1.0 para que doble hacia ADELANTE
	cfg["FalangesProximales1"] = {"axis": Vector3.RIGHT, "sign": -1.0, "min": 0.0, "max": 110.0}
	
	# FalangesDistales1: CAMBIADO sign = -1.0
	cfg["FalangesDistales1"] = {"axis": Vector3.RIGHT, "sign": -1.0, "min": 0.0, "max": 95.0}
	
	# ============================================================
	# 🔵 DEDO ÍNDICE (2)
	# ============================================================
	cfg["Metacarpo2"] = {"axis": Vector3.UP, "sign": -1.0, "min": -30.0, "max": 30.0}
	cfg["FalangesProximales2"] = {"axis": Vector3.RIGHT, "sign": -1.0, "min": 0.0, "max": 110.0}
	cfg["FalangesMedias2"] = {"axis": Vector3.RIGHT, "sign": -1.0, "min": 0.0, "max": 110.0}
	cfg["FalangesDistales2"] = {"axis": Vector3.RIGHT, "sign": -1.0, "min": 0.0, "max": 95.0}
	
	# ============================================================
	# 🟢 DEDO MEDIO (3)
	# ============================================================
	cfg["Metacarpo3"] = {"axis": Vector3.UP, "sign": -1.0, "min": -30.0, "max": 30.0}
	cfg["FalangesProximales3"] = {"axis": Vector3.RIGHT, "sign": -1.0, "min": 0.0, "max": 110.0}
	cfg["FalangesMedias3"] = {"axis": Vector3.RIGHT, "sign": -1.0, "min": 0.0, "max": 110.0}
	cfg["FalangesDistales3"] = {"axis": Vector3.RIGHT, "sign": -1.0, "min": 0.0, "max": 95.0}
	
	# ============================================================
	# 🟡 DEDO ANULAR (4)
	# ============================================================
	cfg["Metacarpo4"] = {"axis": Vector3.UP, "sign": -1.0, "min": -30.0, "max": 30.0}
	cfg["FalangesProximales4"] = {"axis": Vector3.RIGHT, "sign": -1.0, "min": 0.0, "max": 110.0}
	cfg["FalangesMedias4"] = {"axis": Vector3.RIGHT, "sign": -1.0, "min": 0.0, "max": 110.0}
	cfg["FalangesDistales4"] = {"axis": Vector3.RIGHT, "sign": -1.0, "min": 0.0, "max": 95.0}
	
	# ============================================================
	# 🔴 DEDO MEÑIQUE (5)
	# ============================================================
	cfg["Metacarpo5"] = {"axis": Vector3.UP, "sign": -1.0, "min": -30.0, "max": 30.0}
	cfg["FalangesProximales5"] = {"axis": Vector3.RIGHT, "sign": -1.0, "min": 0.0, "max": 110.0}
	cfg["FalangesMedias5"] = {"axis": Vector3.RIGHT, "sign": -1.0, "min": 0.0, "max": 110.0}
	cfg["FalangesDistales5"] = {"axis": Vector3.RIGHT, "sign": -1.0, "min": 0.0, "max": 95.0}

func _exit_tree() -> void:
	udp.close()
