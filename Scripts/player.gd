extends Node3D

# --- CONNEXION AU MANAGER DU PROF ---
# Assure-toi d'avoir mis "arduino_manager.gd" en Autoload sous le nom "ArduinoManager"
@onready var arduino = ArduinoManager 

const MOUSE_SENSITIVITY = 0.003
const TIME_TO_WIN = 60.0 

const FOV_NORMAL = 75.0
const FOV_ZOOM = 20.0
const ZOOM_SPEED = 10.0

const TARGET_ROT_X = deg_to_rad(-14.0)
const TARGET_ROT_Y = 0.0

var is_cheating = false
var cheat_progress = 0.0
var game_is_over = false
var is_caught = false
var attacking_prof = null
var derniere_led = ""

@onready var camera = $Camera3D
@onready var progress_bar = $CanvasLayer/ProgressBar
@onready var game_over_panel = $CanvasLayer/GameOverPanel
@onready var result_image = $CanvasLayer/GameOverPanel/VBoxContainer/ResultImage

@export var win_texture: Texture2D
@export var lose_texture: Texture2D
@export var laptop_screen: MeshInstance3D
@export var work_material: Material
@export var cheat_material: Material

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	progress_bar.max_value = TIME_TO_WIN
	game_over_panel.hide()
	if laptop_screen and work_material:
		laptop_screen.set_surface_override_material(0, work_material)

func _input(event):
	if game_is_over or is_cheating or is_caught: return
	if event is InputEventMouseMotion:
		camera.rotation.y -= event.relative.x * MOUSE_SENSITIVITY
		camera.rotation.x -= event.relative.y * MOUSE_SENSITIVITY
		camera.rotation.y = clamp(camera.rotation.y, deg_to_rad(-80), deg_to_rad(80))
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-60), deg_to_rad(60))

func _process(delta):
	if game_is_over: return
	
	# Gestion de la caméra si on est arrêté
	if is_caught:
		_handle_caught_camera(delta)
		return 

	# --- TRICHE : CLAVIER (ESPACE) OU MANETTE (BOUTON) ---
	var veut_tricher = Input.is_action_pressed("ui_accept") or arduino.is_triche_pressed
	
	if veut_tricher:
		start_cheating(delta)
	else:
		stop_cheating()
		# Contrôle joystick si on ne triche pas
		_handle_joystick_movement(delta)
		
	_update_visuals(delta)

# --- FONCTION MANQUANTE (POUR LE PROF) ---
func get_caught(prof):
	if is_caught: return # Évite les bugs si deux profs nous voient
	is_caught = true
	is_cheating = false
	attacking_prof = prof 
	progress_bar.hide()
	
	if laptop_screen and work_material:
		laptop_screen.set_surface_override_material(0, work_material)
	
	# Optionnel : faire vibrer la manette quand on perd
	arduino.envoyer_commande("VIBRER") 
	
	# On attend un peu avant d'afficher l'écran de défaite
	await get_tree().create_timer(2.0).timeout
	game_over()

func _handle_joystick_movement(delta):
	# On utilise les variables joy_x et joy_y du manager
	camera.rotation.y -= arduino.joy_x * 3.0 * delta
	camera.rotation.x -= arduino.joy_y * 3.0 * delta
	camera.rotation.y = clamp(camera.rotation.y, deg_to_rad(-80), deg_to_rad(80))
	camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-60), deg_to_rad(60))

func start_cheating(delta):
	is_cheating = true
	if laptop_screen and cheat_material:
		laptop_screen.set_surface_override_material(0, cheat_material)
	
	progress_bar.show()
	cheat_progress += delta
	progress_bar.value = cheat_progress
	
	_update_arduino_leds()
	
	if cheat_progress >= TIME_TO_WIN:
		win()

func _update_arduino_leds():
	var ratio = cheat_progress / TIME_TO_WIN
	var nouvelle_led = "LED:VERTE"
	if ratio > 0.75: nouvelle_led = "LED:ROUGE"
	elif ratio > 0.5: nouvelle_led = "LED:ORANGE"
	elif ratio > 0.25: nouvelle_led = "LED:JAUNE"
	
	if nouvelle_led != derniere_led:
		arduino.envoyer_commande(nouvelle_led)
		derniere_led = nouvelle_led

func _handle_caught_camera(delta):
	camera.fov = lerp(camera.fov, FOV_NORMAL, ZOOM_SPEED * delta)
	if attacking_prof:
		var target_pos = attacking_prof.global_position
		target_pos.y += 1.3 
		var target_transform = camera.global_transform.looking_at(target_pos, Vector3.UP)
		camera.global_transform = camera.global_transform.interpolate_with(target_transform, 5.0 * delta)

func _update_visuals(delta):
	if is_cheating:
		camera.fov = lerp(camera.fov, FOV_ZOOM, ZOOM_SPEED * delta)
		camera.rotation.x = lerp(camera.rotation.x, TARGET_ROT_X, ZOOM_SPEED * delta)
		camera.rotation.y = lerp(camera.rotation.y, TARGET_ROT_Y, ZOOM_SPEED * delta)
	else:
		camera.fov = lerp(camera.fov, FOV_NORMAL, ZOOM_SPEED * delta)

func stop_cheating():
	is_cheating = false
	if laptop_screen and work_material:
		laptop_screen.set_surface_override_material(0, work_material)
	progress_bar.hide()

func win():
	game_is_over = true
	if win_texture: result_image.texture = win_texture
	show_menu()

func game_over():
	game_is_over = true
	if lose_texture: result_image.texture = lose_texture
	show_menu()

func show_menu():
	game_over_panel.show() 
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE) 
	get_tree().paused = true 

func _on_restart_button_pressed():
	get_tree().paused = false 
	get_tree().reload_current_scene()

func _on_quit_button_pressed():
	get_tree().quit()
