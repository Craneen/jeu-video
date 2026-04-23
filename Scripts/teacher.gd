extends Node3D

@export var speed = 2.4
@export var detection_radius = 3.5

var waypoints = []
var current_point_index = 0
var player = null

# --- VARIABLES POUR LE CERVEAU DE L'IA ---
enum State { PATROL, STARE, FAKE_LEAVE, RUSH_BACK, STARE_AGAIN, CATCHING_PLAYER }
var current_state = State.PATROL
var state_timer = 0.0

var fakeout_stage = 1 
var stare_position = Vector3.ZERO 
@onready var normal_speed = speed 
# -----------------------------------------

func _ready():
	player = get_tree().get_root().find_child("Player", true, false)
	waypoints = get_tree().get_nodes_in_group("prof_path")
	if waypoints.size() == 0:
		print("ATTENTION : Le prof ne trouve pas les marqueurs !")

func _process(delta):
	check_player_cheating()
	
	match current_state:
		State.PATROL:
			if waypoints.size() > 0:
				patrol(delta)
			
			if player and current_point_index == 3 and fakeout_stage <= 2:
				var threshold = 0.5 if fakeout_stage == 1 else 0.80
				
				if player.cheat_progress >= (player.TIME_TO_WIN * threshold):
					var pos_relative = player.to_local(global_position)
					
					if global_position.distance_to(player.global_position) < 3.5 and pos_relative.z >= -0.8 and pos_relative.z <= 0.0:
						stare_position = global_position 
						state_timer = 0.0
						
						if fakeout_stage == 1:
							current_state = State.STARE
						else:
							current_state = State.FAKE_LEAVE
						
						fakeout_stage += 1 
		
		State.STARE:
			var look_pos = player.global_position
			look_pos.y = global_position.y
			if global_position.distance_to(look_pos) > 0.1:
				look_at(look_pos, Vector3.UP)
				rotate_y(deg_to_rad(180))
				
			state_timer += delta
			if state_timer >= 2.0: 
				current_state = State.FAKE_LEAVE
				state_timer = 0.0
				
		State.FAKE_LEAVE:
			if waypoints.size() > 0:
				patrol(delta)
				
			state_timer += delta
			if state_timer >= 3.0: 
				current_state = State.RUSH_BACK
				state_timer = 0.0
				speed = normal_speed * 3.0 
				
		State.RUSH_BACK:
			var target_pos = stare_position
			target_pos.y = global_position.y
			var direction = (target_pos - global_position).normalized()
			global_position += direction * speed * delta
			
			var look_pos = player.global_position
			look_pos.y = global_position.y
			if global_position.distance_to(look_pos) > 0.1:
				look_at(look_pos, Vector3.UP)
				rotate_y(deg_to_rad(180))
				
			state_timer += delta
			if state_timer >= 1.5 or global_position.distance_to(target_pos) < 0.2:
				current_state = State.STARE_AGAIN
				state_timer = 0.0
				speed = normal_speed 
				
		State.STARE_AGAIN:
			var look_pos = player.global_position
			look_pos.y = global_position.y
			if global_position.distance_to(look_pos) > 0.1:
				look_at(look_pos, Vector3.UP)
				rotate_y(deg_to_rad(180))
				
			state_timer += delta
			if state_timer >= 2.0: 
				current_state = State.PATROL 
				state_timer = 0.0
				
		State.CATCHING_PLAYER:
			var pos_relative = player.to_local(global_position)
			var est_arrive = false
			
			if current_point_index == 3 and pos_relative.z <= 0.0:
				est_arrive = true
				
			if not est_arrive:
				speed = normal_speed * 2.5 
				if waypoints.size() > 0:
					patrol(delta)
					
			else:
				speed = 0.0 
				var look_pos = player.camera.global_position
				look_pos.y = global_position.y
				if global_position.distance_to(look_pos) > 0.1:
					look_at(look_pos, Vector3.UP)
					rotate_y(deg_to_rad(180))
				
				if state_timer == 0.0:
					print("PAF ! (Insérer l'animation de la gifle ici)")
				
				state_timer += delta
				if state_timer >= 1.0: 
					player.game_over()

func patrol(delta):
	var target_pos = waypoints[current_point_index].global_position
	target_pos.y = global_position.y 
	
	var direction = (target_pos - global_position).normalized()
	global_position += direction * speed * delta
	
	if global_position.distance_to(target_pos) > 0.1:
		look_at(target_pos, Vector3.UP)
		rotate_y(deg_to_rad(180)) 
		
	if global_position.distance_to(target_pos) < 0.5:
		current_point_index = (current_point_index + 1) % waypoints.size()

func check_player_cheating():
	if player and not player.game_is_over and current_state != State.CATCHING_PLAYER:
		var pos_relative = player.to_local(global_position)
		var est_derriere_moi = pos_relative.z > 0.0
		
		# CHANGEMENT ICI : On a retiré State.RUSH_BACK.
		# Il te crame s'il est arrêté et te fixe (STARE, STARE_AGAIN)
		var le_prof_me_fixe = current_state in [State.STARE, State.STARE_AGAIN]
		
		if player.is_cheating and (est_derriere_moi or le_prof_me_fixe):
			print("CRAMÉ ! Le prof passe en mode attaque !")
			current_state = State.CATCHING_PLAYER
			state_timer = 0.0
			player.get_caught(self)
