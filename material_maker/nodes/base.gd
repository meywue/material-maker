extends MMGraphNodeMinimal
class_name MMGraphNodeBase


var show_inputs : bool = false
var show_outputs : bool = false

var rendering_time : int = -1


const MINIMIZE_ICON : Texture = preload("res://material_maker/icons/minimize.tres")
const RANDOMNESS_ICON : Texture = preload("res://material_maker/icons/randomness_unlocked.tres")
const RANDOMNESS_LOCKED_ICON : Texture = preload("res://material_maker/icons/randomness_locked.tres")
const CUSTOM_ICON : Texture = preload("res://material_maker/icons/custom.png")
const PREVIEW_ICON : Texture = preload("res://material_maker/icons/preview.png")
const PREVIEW_LOCKED_ICON : Texture = preload("res://material_maker/icons/preview_locked.png")

const MENU_PROPAGATE_CHANGES : int = 1000


static func wrap_string(s : String, l : int = 50) -> String:
	var length = s.length()
	var p = 0
	while p + l < length:
		var next_cr = s.find("\n", p)
		var next_sp = s.find(" ", p+l)
		if next_cr >= 0 and next_cr < next_sp:
			p = next_cr+1
		elif next_sp >= 0:
			s[next_sp] = "\n"
			p = next_sp+1
		else:
			break
	return s

func _ready() -> void:
	connect("gui_input", self, "_on_gui_input")

func _exit_tree() -> void:
	#get_parent().call_deferred("check_last_selected")
	pass

func on_generator_changed(g):
	if generator == g:
		update()

func _draw() -> void:
	var color : Color = get_color("title_color")
	var icon = MINIMIZE_ICON
	draw_texture_rect(icon, Rect2(rect_size.x-40, 4, 16, 16), false, color)
	if generator != null and generator.has_randomness():
		icon = RANDOMNESS_LOCKED_ICON if generator.is_seed_locked() else RANDOMNESS_ICON
		draw_texture_rect(icon, Rect2(rect_size.x-56, 4, 16, 16), false)
	var inputs = generator.get_input_defs()
	var font : Font = get_font("default_font")
	var scale = get_global_transform().get_scale()
	if generator != null and generator.model == null and (generator is MMGenShader or generator is MMGenGraph):
		draw_texture_rect(CUSTOM_ICON, Rect2(3, 8, 7, 7), false, color)
	for i in range(inputs.size()):
		if inputs[i].has("group_size") and inputs[i].group_size > 1:
			var conn_pos1 = get_connection_input_position(i)
# warning-ignore:narrowing_conversion
			var conn_pos2 = get_connection_input_position(min(i+inputs[i].group_size-1, inputs.size()-1))
			conn_pos1 /= scale
			conn_pos2 /= scale
			draw_line(conn_pos1, conn_pos2, color)
		if show_inputs:
			var string : String = TranslationServer.translate(inputs[i].shortdesc) if inputs[i].has("shortdesc") else TranslationServer.translate(inputs[i].name)
			var string_size : Vector2 = font.get_string_size(string)
			draw_string(font, get_connection_input_position(i)/scale-Vector2(string_size.x+12, -string_size.y*0.3), string, color)
	var outputs = generator.get_output_defs()
	var preview_port : Array = [ -1, -1 ]
	var preview_locked : Array = [ false, false ]
	for i in range(2):
		if get_parent().locked_preview[i] != null and get_parent().locked_preview[i].generator == generator:
			preview_port[i] = get_parent().locked_preview[i].output_index
			preview_locked[i] = true
		elif get_parent().current_preview[i] != null and get_parent().current_preview[i].generator == generator:
			preview_port[i] = get_parent().current_preview[i].output_index
	if preview_port[0] == preview_port[1]:
		preview_port[1] = -1
		preview_locked[0] = preview_locked[0] || preview_locked[1]
	for i in range(outputs.size()):
		if outputs[i].has("group_size") and outputs[i].group_size > 1:
# warning-ignore:narrowing_conversion
			var conn_pos1 = get_connection_output_position(i)
			var conn_pos2 = get_connection_output_position(min(i+outputs[i].group_size-1, outputs.size()-1))
			conn_pos1 /= scale
			conn_pos2 /= scale
			draw_line(conn_pos1, conn_pos2, color)
		var j = -1
		if i == preview_port[0]:
			j = 0
		elif i == preview_port[1]:
			j = 1
		if j != -1:
			var conn_pos = get_connection_output_position(i)
			conn_pos /= scale
			draw_texture_rect(PREVIEW_LOCKED_ICON if preview_locked[j] else PREVIEW_ICON, Rect2(conn_pos.x-14, conn_pos.y-4, 7, 7), false, color)
		if show_outputs:
			var string : String = TranslationServer.translate(outputs[i].shortdesc) if outputs[i].has("shortdesc") else (tr("Output")+" "+str(i))
			var string_size : Vector2 = font.get_string_size(string)
			draw_string(font, get_connection_output_position(i)/scale+Vector2(12, string_size.y*0.3), string, color)
	if (selected):
		draw_style_box(get_stylebox("node_highlight"), Rect2(Vector2.ZERO, rect_size))

func set_generator(g) -> void:
	.set_generator(g)
	g.connect("rendering_time", self, "update_rendering_time")

func update_rendering_time(t : int) -> void:
	rendering_time = t

func set_generator_seed(s : float):
	if generator.is_seed_locked():
		return
	var old_seed : float = generator.get_seed()
	generator.set_seed(s)
	var hier_name = generator.get_hier_name()
	get_parent().undoredo.add("Set seed", [{ type="setseed", node=hier_name, seed=old_seed }], [{ type="setseed", node=hier_name, seed=s }], false)

func reroll_generator_seed() -> void:
	set_generator_seed(randf())

func _on_seed_menu(id):
	match id:
		0:
			var old_seed_locked : bool = generator.is_seed_locked()
			generator.toggle_lock_seed()
			update()
			get_parent().send_changed_signal()
			var hier_name = generator.get_hier_name()
			get_parent().undoredo.add("Lock/unlock seed", [{ type="setseedlocked", node=hier_name, seedlocked=old_seed_locked }], [{ type="setseedlocked", node=hier_name, seedlocked=!old_seed_locked }], false)
		1:
			OS.clipboard = "seed=%.9f" % generator.seed_value
		2:
			if OS.clipboard.left(5) == "seed=":
				set_generator_seed(OS.clipboard.right(5).to_float())

var doubleclicked : bool = false

func _on_gui_input(event) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			if Rect2(rect_size.x-40, 4, 16, 16).has_point(event.position):
				if event.button_index == BUTTON_LEFT:
					generator.minimized = !generator.minimized
					var hier_name = generator.get_hier_name()
					get_parent().undoredo.add("Minimize node", [{ type="setminimized", node=hier_name, minimized=!generator.minimized }], [{ type="setminimized", node=hier_name, minimized=generator.minimized }], false)
					update_node()
					accept_event();
			elif Rect2(rect_size.x-56, 4, 16, 16).has_point(event.position):
				match event.button_index:
					BUTTON_LEFT:
						reroll_generator_seed()
					BUTTON_RIGHT:
						var menu : PopupMenu = PopupMenu.new()
						menu.add_item(tr("Unlock seed") if generator.is_seed_locked() else tr("Lock seed"), 0)
						menu.add_separator()
						menu.add_item(tr("Copy seed"), 1)
						if ! generator.is_seed_locked() and OS.clipboard.left(5) == "seed=":
							menu.add_item(tr("Paste seed"), 2)
						add_child(menu)
						menu.popup(Rect2(get_global_mouse_position(), menu.get_minimum_size()))
						menu.connect("popup_hide", menu, "queue_free")
						menu.connect("id_pressed", self, "_on_seed_menu")
						accept_event()
			elif event.doubleclick:
				doubleclicked = true
			if event.button_index == BUTTON_RIGHT:
				if generator is MMGenGraph:
					accept_event()
					var menu : PopupMenu = PopupMenu.new()
					if !get_parent().get_propagation_targets(generator).empty():
						menu.add_item(tr("Propagate changes"), MENU_PROPAGATE_CHANGES)
					if menu.get_item_count() != 0:
						add_child(menu)
						menu.connect("modal_closed", menu, "queue_free")
						menu.connect("id_pressed", self, "_on_menu_id_pressed")
						menu.popup(Rect2(get_global_mouse_position(), menu.get_minimum_size()))
					else:
						menu.free()
		elif doubleclicked:
			doubleclicked = false
			if generator is MMGenGraph:
				get_parent().call_deferred("update_view", generator)
				accept_event()
			elif generator is MMGenSDF:
				edit_generator()
	elif event is InputEventMouseMotion:
		var epos = event.position
		if Rect2(0, 0, rect_size.x-56, 16).has_point(epos):
			var description = generator.get_description()
			if description != "":
				hint_tooltip = wrap_string(description)
			elif generator.model != null:
				hint_tooltip = TranslationServer.translate(generator.model)
			return
		elif Rect2(rect_size.x-56, 4, 16, 16).has_point(epos) and generator.has_randomness():
			hint_tooltip = tr("Change seed (left mouse button) / Show seed menu (right mouse button)")
			return
		hint_tooltip = ""

func get_input_slot(pos : Vector2) -> int:
	var return_value = .get_input_slot(pos)
	var new_show_inputs : bool = (return_value != -2)
	if new_show_inputs != show_inputs:
		show_inputs = new_show_inputs
		update()
	return return_value

func get_output_slot(pos : Vector2) -> int:
	var return_value = .get_output_slot(pos)
	var new_show_outputs : bool = (return_value != -2)
	if new_show_outputs != show_outputs:
		show_outputs = new_show_outputs
		update()
	return return_value

func get_slot_tooltip(pos : Vector2) -> String:
	var scale = get_global_transform().get_scale()
	if get_connection_input_count() > 0:
		var input_1 : Vector2 = get_connection_input_position(0)-5*scale
		var input_2 : Vector2 = get_connection_input_position(get_connection_input_count()-1)+5*scale
		var new_show_inputs : bool = Rect2(input_1, input_2-input_1).has_point(pos)
		if new_show_inputs != show_inputs:
			show_inputs = new_show_inputs
			update()
		if new_show_inputs:
			for i in range(get_connection_input_count()):
				if (get_connection_input_position(i)-pos).length() < 5*scale.x:
					var input_def = generator.get_input_defs()[i]
					if input_def.has("longdesc"):
						return wrap_string(TranslationServer.translate(input_def.longdesc))
			return ""
	if get_connection_output_count() > 0:
		var output_1 : Vector2 = get_connection_output_position(0)-5*scale
		var output_2 : Vector2 = get_connection_output_position(get_connection_output_count()-1)+5*scale
		var new_show_outputs : bool = Rect2(output_1, output_2-output_1).has_point(pos)
		if new_show_outputs != show_outputs:
			show_outputs = new_show_outputs
			update()
		if new_show_outputs:
			for i in range(get_connection_output_count()):
				if (get_connection_output_position(i)-pos).length() < 5*scale.x:
					var output_def = generator.get_output_defs()[i]
					if output_def.has("longdesc"):
						return wrap_string(TranslationServer.translate(output_def.longdesc))
	return ""

func clear_connection_labels() -> void:
	if show_inputs or show_outputs:
		show_inputs = false
		show_outputs = false
		update()

func _on_menu_id_pressed(id : int) -> void:
	match id:
		MENU_PROPAGATE_CHANGES:
			var dialog = load("res://material_maker/windows/accept_dialog/accept_dialog.tscn").instance()
			dialog.dialog_text = "Propagate changes from %s to %d nodes?" % [ generator.get_type_name(), get_parent().get_propagation_targets(generator).size() ]
			dialog.add_cancel("Cancel");
			add_child(dialog)
			var result = dialog.ask()
			while result is GDScriptFunctionState:
				result = yield(result, "completed")
			if result == "ok":
				get_parent().call_deferred("propagate_node_changes", generator)

var edit_generator_prev_state : Dictionary
var edit_generator_next_state : Dictionary

func edit_generator() -> void:
	if generator.has_method("edit"):
		edit_generator_prev_state = generator.get_parent().serialize().duplicate(true)
		edit_generator_next_state = {}
		generator.edit(self)

func update_shader_generator(shader_model) -> void:
	generator.set_shader_model(shader_model)
	update_node()
	get_parent().set_need_save()
	edit_generator_next_state = generator.get_parent().serialize().duplicate(true)

func update_sdf_generator(sdf_scene) -> void:
	generator.set_sdf_scene(sdf_scene)
	update_node()
	get_parent().set_need_save()
	edit_generator_next_state = generator.get_parent().serialize().duplicate(true)

func finalize_generator_update() -> void:
	if ! edit_generator_next_state.empty():
		get_parent().undoredo_create_step("Edit node", generator.get_parent().get_hier_name(), edit_generator_prev_state, edit_generator_next_state)
		edit_generator_prev_state = {}
		edit_generator_next_state = {}
