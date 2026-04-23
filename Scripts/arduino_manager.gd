extends Node2D

signal joyXUpdated()
signal arduino_disconnected()
signal arduino_connected()

# Variables accessibles par le joueur
var joy_x : float = 0.0
var joy_y : float = 0.0
var is_triche_pressed : bool = false

# Configuration du prof [cite: 18, 20]
const DISCOVER_MSG  := "DISCOVER"
const ACK_PREFIX    := "GDSERIAL_ACK"
const BAUD_RATE     := 115200
const PORT_NAME_HINTS: PackedStringArray = ["usbmodem", "usbserial", "ttyACM", "ttyUSB", "COM"]

var serial: GdSerial
var _paired: bool = false
var _buffer: String = ""
var _is_pairing: bool = false
var _pairing_cooldown: float = 0.0

func _ready() -> void:
	serial = GdSerial.new()
	serial.set_baud_rate(BAUD_RATE)
	start_pairing()

func start_pairing() -> void:
	print("Starting pairing process")
	if _is_pairing: return
	_is_pairing = true
	var ports = serial.list_ports()
	var candidates = []
	for p in ports.values():
		for hint in PORT_NAME_HINTS:
			if hint in p["port_name"]:
				candidates.append(p)
				break
	_scan_ports(candidates)

func _scan_ports(port_list: Array) -> void:
	for p in port_list:
		print("Scanning")
		serial.set_port(p["port_name"])
		if not serial.open(): continue
		serial.clear_buffer()
		await get_tree().create_timer(.5).timeout
		serial.writeline(DISCOVER_MSG)
		await get_tree().create_timer(0.2).timeout
		if ACK_PREFIX in _read_all_available():
			_paired = true
			_is_pairing = false
			emit_signal("arduino_connected")
			print("Arduino Connected")
			return
		serial.close()
	_is_pairing = false
	_pairing_cooldown = 2.0

func _read_all_available() -> String:
	return serial.read_string(serial.bytes_available()) if serial.bytes_available() > 0 else ""

func _process(delta: float) -> void:
	if not _paired:
		_pairing_cooldown -= delta
		if not _is_pairing and _pairing_cooldown <= 0: start_pairing()
		return

	if serial.bytes_available() > 0:
		_buffer += serial.read_string(serial.bytes_available())

	while "\n" in _buffer:
		var idx = _buffer.find("\n")
		var line = _buffer.substr(0, idx).strip_edges()
		_buffer = _buffer.substr(idx + 1)
		_parse_message(line)

func _parse_message(msg: String) -> void:
	var parts = msg.split(":", false, 1)
	if parts.size() < 2: return

	match parts[0]:
		"JOYX":
		# On transforme 0-1023 en -1.0 à 1.0
			joy_x = (float(parts[1]  - 512.0 ))/ 512.0
		"TRICHE":
			is_triche_pressed = (parts[1] == "1")

func envoyer_commande(cmd: String) -> void:
	if _paired: serial.writeline(cmd)
