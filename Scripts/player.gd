extends Node3D

const MOUSE_SENSITIVITY = 0.003
const TIME_TO_WIN = 20.0 # Temps total pour gagner (75 secondes)

# --- RÉGLAGES DU ZOOM ---
const FOV_NORMAL = 75.0  # La vue de base (75 est le standard de Godot)
const FOV_ZOOM = 20.0    # La vue zoomée (plus c'est petit, plus on est près de l'écran)
const ZOOM_SPEED = 10.0  # La vitesse à laquelle la caméra avance/recule

# Angles pour fixer l'écran
const TARGET_ROT_X = deg_to_rad(-14.0) # Angle de la tête (négatif = vers le bas, sur le PC)
const TARGET_ROT_Y = 0.0               # 0.0 = on regarde pile droit devant soi
# ------------------------

var is_cheating = false
var cheat_progress = 0.0
var game_is_over = false

@onready var camera = $Camera3D
@onready var progress_bar = $CanvasLayer/ProgressBar
@onready var win_label = $CanvasLayer/WinLabel
@onready var lose_label = $CanvasLayer/LoseLabel

# Variables pour brancher le PC depuis l'interface Godot
@export var laptop_screen: MeshInstance3D
@export var work_material: Material
@export var cheat_material: Material

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	progress_bar.max_value = TIME_TO_WIN
	progress_bar.value = 0
	progress_bar.hide() 
	win_label.hide()
	lose_label.hide()
	
	# On force l'écran de travail au démarrage
	if laptop_screen and work_material:
		laptop_screen.set_surface_override_material(0, work_material)
		
	# On s'assure que la caméra commence avec le bon FOV
	camera.fov = FOV_NORMAL

func _input(event):
	# Si le jeu est fini OU qu'on triche, on bloque la souris !
	if game_is_over or is_cheating: return
	
	if event is InputEventMouseMotion:
		# On tourne UNIQUEMENT la caméra (la tête), le PC reste à sa place !
		camera.rotation.y -= event.relative.x * MOUSE_SENSITIVITY
		# NOUVEAU : On bloque la rotation de la nuque (Gauche / Droite)
		camera.rotation.y = clamp(camera.rotation.y, deg_to_rad(-80), deg_to_rad(80))
		
		camera.rotation.x -= event.relative.y * MOUSE_SENSITIVITY
		# On bloque la rotation de la nuque (Haut / Bas)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-60), deg_to_rad(60))

func _process(delta):
	if game_is_over: return
	
	# 1. Gestion de la triche (Espace)
	if Input.is_action_pressed("ui_accept"):
		start_cheating(delta)
	else:
		stop_cheating()
		
	# 2. Gestion du Zoom fluide (Effet d'infiltration)
	if is_cheating:
		# La caméra zoome vers l'écran
		camera.fov = lerp(camera.fov, FOV_ZOOM, ZOOM_SPEED * delta)
		# On centre de force la tête sur l'écran
		camera.rotation.x = lerp(camera.rotation.x, TARGET_ROT_X, ZOOM_SPEED * delta)
		camera.rotation.y = lerp(camera.rotation.y, TARGET_ROT_Y, ZOOM_SPEED * delta)
	else:
		# La caméra recule à sa position normale (la tête reste là où on la laisse)
		camera.fov = lerp(camera.fov, FOV_NORMAL, ZOOM_SPEED * delta)

func start_cheating(delta):
	is_cheating = true
	
	# On affiche l'écran de triche (ChatGPT)
	if laptop_screen and cheat_material:
		laptop_screen.set_surface_override_material(0, cheat_material)
	
	# On affiche la barre et on la fait monter
	progress_bar.show()
	cheat_progress += delta
	progress_bar.value = cheat_progress
	
	if cheat_progress >= TIME_TO_WIN:
		win()

func stop_cheating():
	is_cheating = false
	
	# On remet l'écran de travail normal
	if laptop_screen and work_material:
		laptop_screen.set_surface_override_material(0, work_material)
		
	# On cache la barre
	progress_bar.hide()

func win():
	game_is_over = true
	is_cheating = false
	win_label.show()
	get_tree().paused = true # Met le jeu en pause

func game_over():
	game_is_over = true
	is_cheating = false
	lose_label.show()
	get_tree().paused = true # Met le jeu en pause
