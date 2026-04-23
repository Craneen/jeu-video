extends Node3D

const MOUSE_SENSITIVITY = 0.003
const TIME_TO_WIN = 60.0 # Temps pour tester la victoire

# --- RÉGLAGES DU ZOOM ---
const FOV_NORMAL = 75.0
const FOV_ZOOM = 20.0
const ZOOM_SPEED = 10.0

const TARGET_ROT_X = deg_to_rad(-14.0)
const TARGET_ROT_Y = 0.0
# ------------------------

var is_cheating = false
var cheat_progress = 0.0
var game_is_over = false

# Variables pour l'arrestation
var is_caught = false
var attacking_prof = null

@onready var camera = $Camera3D
@onready var progress_bar = $CanvasLayer/ProgressBar

# --- VARIABLES UI ---
@onready var game_over_panel = $CanvasLayer/GameOverPanel
@onready var result_image = $CanvasLayer/GameOverPanel/VBoxContainer/ResultImage

@export var win_texture: Texture2D
@export var lose_texture: Texture2D
# ------------------------------

@export var laptop_screen: MeshInstance3D
@export var work_material: Material
@export var cheat_material: Material

func _ready():
	# On capture la souris pour qu'elle ne sorte pas de la fenêtre
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	progress_bar.max_value = TIME_TO_WIN
	progress_bar.value = 0
	progress_bar.hide() 
	
	# On cache le menu au démarrage
	game_over_panel.hide()
	
	if laptop_screen and work_material:
		laptop_screen.set_surface_override_material(0, work_material)
		
	camera.fov = FOV_NORMAL

func _input(event):
	# Gestion de la rotation de la tête à la souris
	if game_is_over or is_cheating or is_caught: return
	
	if event is InputEventMouseMotion:
		camera.rotation.y -= event.relative.x * MOUSE_SENSITIVITY
		camera.rotation.y = clamp(camera.rotation.y, deg_to_rad(-80), deg_to_rad(80))
		camera.rotation.x -= event.relative.y * MOUSE_SENSITIVITY
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-60), deg_to_rad(60))

func _process(delta):
	if game_is_over: return
	
	# --- LOGIQUE SI ATTRAPÉ ---
	if is_caught:
		camera.fov = lerp(camera.fov, FOV_NORMAL, ZOOM_SPEED * delta)
		if attacking_prof:
			var target_pos = attacking_prof.global_position
			target_pos.y += 1.3 
			var current_transform = camera.global_transform
			var target_transform = current_transform.looking_at(target_pos, Vector3.UP)
			camera.global_transform = current_transform.interpolate_with(target_transform, 5.0 * delta)
		return 
	# ----------------------------------------
	
	# --- CONTRÔLE DE LA TRICHE (TOUCHE ESPACE / ENTREE) ---
	if Input.is_action_pressed("ui_accept"):
		start_cheating(delta)
	else:
		stop_cheating()
		
	# Gestion visuelle du zoom et de l'inclinaison de la tête
	if is_cheating:
		camera.fov = lerp(camera.fov, FOV_ZOOM, ZOOM_SPEED * delta)
		camera.rotation.x = lerp(camera.rotation.x, TARGET_ROT_X, ZOOM_SPEED * delta)
		camera.rotation.y = lerp(camera.rotation.y, TARGET_ROT_Y, ZOOM_SPEED * delta)
	else:
		camera.fov = lerp(camera.fov, FOV_NORMAL, ZOOM_SPEED * delta)

# --- FONCTION APPELÉE PAR LE PROF ---
func get_caught(prof):
	is_caught = true
	is_cheating = false
	progress_bar.hide()
	attacking_prof = prof 
	
	if laptop_screen and work_material:
		laptop_screen.set_surface_override_material(0, work_material)

func start_cheating(delta):
	is_cheating = true
	if laptop_screen and cheat_material:
		laptop_screen.set_surface_override_material(0, cheat_material)
	
	progress_bar.show()
	cheat_progress += delta
	progress_bar.value = cheat_progress
	
	if cheat_progress >= TIME_TO_WIN:
		win()

func stop_cheating():
	is_cheating = false
	if laptop_screen and work_material:
		laptop_screen.set_surface_override_material(0, work_material)
	progress_bar.hide()

func win():
	game_is_over = true
	is_cheating = false
	if win_texture:
		result_image.texture = win_texture
	show_menu()

func game_over():
	game_is_over = true
	is_cheating = false
	if lose_texture:
		result_image.texture = lose_texture
	show_menu()

# --- FONCTIONS POUR LE MENU ---
func show_menu():
	game_over_panel.show() 
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE) 
	get_tree().paused = true 

func _on_restart_button_pressed() -> void:
	get_tree().paused = false 
	get_tree().reload_current_scene()

func _on_quit_button_pressed() -> void:
	get_tree().quit()
