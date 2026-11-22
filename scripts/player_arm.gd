extends CharacterBody3D

@onready var skeleton: Skeleton3D = $brazo/Skeleton3D

const PORT: int = 12345
const CHANNEL_COUNT: int = 24

var bone_shoulder: int = -1
var bone_elbow: int = -1

var shoulder_rest: Quaternion = Quaternion.IDENTITY
var elbow_rest: Quaternion = Quaternion.IDENTITY
var shoulder_current: Quaternion = Quaternion.IDENTITY
var elbow_current: Quaternion = Quaternion.IDENTITY

var udp: PacketPeerUDP = PacketPeerUDP.new()
var is_active_receiver: bool = false

var shoulder_smooth: float = 18.0
var elbow_smooth: float = 24.0
var packets_ok: int = 0

func _ready() -> void:
	bone_shoulder = skeleton.find_bone("Humero")
	bone_elbow = skeleton.find_bone("Cubito")

	if bone_shoulder != -1:
		shoulder_rest = skeleton.get_bone_pose_rotation(bone_shoulder)
		shoulder_current = shoulder_rest
		print("✅ Humero encontrado")
	else:
		push_warning("❌ No se encontro Humero")

	if bone_elbow != -1:
		elbow_rest = skeleton.get_bone_pose_rotation(bone_elbow)
		elbow_current = elbow_rest
		print("✅ Cubito encontrado")
	else:
		push_warning("❌ No se encontro Cubito")

	print("✅ Arm listo. Esperando activación para bindear puerto ", PORT)


func set_active(v: bool) -> void:
	print("🔔 Arm.set_active() llamado con v=", v)
	if v == is_active_receiver:
		print("   Ignorado: ya estaba en estado ", v)
		return
	is_active_receiver = v
	if v:
		var err: int = udp.bind(PORT)
		print("📡 Arm bind en puerto ", PORT, " resultado: ", err)
		if err != OK:
			push_error("❌ BIND FALLÓ con error: ", err)
		packets_ok = 0
	else:
		udp.close()
		print("📴 Arm socket cerrado")

func _process(delta: float) -> void:
	if not is_active_receiver:
		return

	var packet_count: int = udp.get_available_packet_count()
	if packet_count > 0:
		while udp.get_available_packet_count() > 0:
			var data: PackedByteArray = udp.get_packet()
			var a: PackedFloat32Array = data.to_float32_array()

			if a.size() < CHANNEL_COUNT:
				print("⚠️ Array muy pequeño: ", a.size())
				continue	

			packets_ok += 1
			if packets_ok % 60 == 0:
				print("📦 arm paquetes=", packets_ok, " shoulder=", a[22], " elbow=", a[23])

			_apply_shoulder(float(a[22]), delta)
			_apply_elbow(float(a[23]), delta)

func _apply_shoulder(deg: float, delta: float) -> void:
	if bone_shoulder == -1:
		return
	var g: float = clampf(deg, -80.0, 110.0)
	var target: Quaternion = shoulder_rest * Quaternion(Vector3.RIGHT, deg_to_rad(g))
	var t: float = clampf(shoulder_smooth * delta, 0.0, 1.0)
	shoulder_current = shoulder_current.slerp(target, t)
	skeleton.set_bone_pose_rotation(bone_shoulder, shoulder_current)

func _apply_elbow(deg: float, delta: float) -> void:
	if bone_elbow == -1:
		return
	var g: float = clampf(deg, 0.0, 140.0)
	var target: Quaternion = elbow_rest * Quaternion(Vector3.RIGHT, deg_to_rad(g))
	var t: float = clampf(elbow_smooth * delta, 0.0, 1.0)
	elbow_current = elbow_current.slerp(target, t)
	skeleton.set_bone_pose_rotation(bone_elbow, elbow_current)

func _exit_tree() -> void:
	udp.close()
