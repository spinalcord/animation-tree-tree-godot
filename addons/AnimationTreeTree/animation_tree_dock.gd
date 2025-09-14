# animation_tree_dock.gd
@tool
extends Control

# UI Constants
const TITLE_FONT_SIZE: int = 14
const INSTRUCTION_FONT_SIZE: int = 10

# Debug settings
const DEBUG_MODE: bool = false

signal copy_requested(animation_tree: AnimationTree, node_path: String)
signal paste_requested(animation_tree: AnimationTree, target_path: String)
signal delete_requested(animation_tree: AnimationTree, node_path: String)

var tree_view: Tree
var selected_animation_tree: AnimationTree
var path_label: Label
var status_label: Label
var clipboard_status_label: Label
var copy_button: Button
var paste_button: Button
var delete_button: Button
var markdown_button: Button

# For automatic detection
var editor_selection: EditorSelection

func _init() -> void:
	name = "AnimationTree-Tree"
	_create_ui()
	_setup_auto_detection()
	
	
func _setup_auto_detection() -> void:
	# Connect to editor selection changes for automatic detection
	editor_selection = EditorInterface.get_selection()
	if editor_selection:
		# we need to refresh the TreeView properly if editor selection changes
		editor_selection.selection_changed.connect(_on_editor_selection_changed)
	
	# Might be a aggressiv way but in that way can refresh our Tree Structure if something
	# in the AnimationTreeEditor changes
	EditorInterface.get_editor_undo_redo().history_changed.connect(_on_editor_selection_changed)
	
	_detect_selected_animation_tree()

func _detect_selected_animation_tree() -> void:
	if editor_selection == null:
		return
		
	var selected_nodes: Array[Node] = editor_selection.get_selected_nodes()
	
	for node in selected_nodes:
		if node is AnimationTree:
			debug_print("Auto-detected AnimationTree: %s" % node.name)
			_set_animation_tree(node as AnimationTree)
			return
	
	debug_print("No AnimationTree in current selection")
	
func _on_editor_selection_changed() -> void:
	var selection = EditorInterface.get_selection()
	var selected_nodes = selection.get_selected_nodes()

	for node in selected_nodes:
		if node is AnimationTree:
			_detect_selected_animation_tree()
			

func debug_print(message: String) -> void:
	if DEBUG_MODE:
		print(message)

func _create_ui() -> void:
	var vbox := VBoxContainer.new()
	add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	_add_tree_selection_section(vbox)
	_add_separator(vbox)
	_add_clipboard_status_section(vbox)
	_add_separator(vbox)
	_add_path_section(vbox)
	_add_buttons_section(vbox)
	_add_separator(vbox)
	_add_tree_view_section(vbox)

func _add_tree_selection_section(container: VBoxContainer) -> void:

	status_label = Label.new()
	status_label.text = "No AnimationTree selected"
	status_label.modulate = Color.YELLOW
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	container.add_child(status_label)

func _add_clipboard_status_section(container: VBoxContainer) -> void:
	var clipboard_label := Label.new()
	clipboard_label.text = "Clipboard Status:"
	clipboard_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	container.add_child(clipboard_label)
	
	clipboard_status_label = Label.new()
	clipboard_status_label.text = "Empty clipboard"
	clipboard_status_label.modulate = Color.GRAY
	clipboard_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	clipboard_status_label.add_theme_font_size_override("font_size", 11)
	container.add_child(clipboard_status_label)

func _add_separator(container: VBoxContainer) -> void:
	container.add_child(HSeparator.new())

func _add_path_section(container: VBoxContainer) -> void:
	var path_display_label := Label.new()
	path_display_label.text = "Selected Node Path:"
	container.add_child(path_display_label)
	
	path_label = Label.new()
	path_label.text = "No selection"
	path_label.modulate = Color.GRAY
	path_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	container.add_child(path_label)

func _add_buttons_section(container: VBoxContainer) -> void:
	var button_container := HBoxContainer.new()
	container.add_child(button_container)
	
	# Get editor theme for icons
	var editor_theme = EditorInterface.get_editor_theme()
	
	copy_button = _create_action_button("", _on_copy_pressed)
	copy_button.icon = editor_theme.get_icon("ActionCopy", "EditorIcons")
	copy_button.tooltip_text = "Copy selected node"
	
	paste_button = _create_action_button("", _on_paste_pressed)
	paste_button.icon = editor_theme.get_icon("ActionPaste", "EditorIcons")
	paste_button.tooltip_text = "Paste node to selected location"
	
	delete_button = _create_action_button("", _on_delete_pressed)
	delete_button.icon = editor_theme.get_icon("Remove", "EditorIcons")
	delete_button.tooltip_text = "Delete selected node"
	
	markdown_button = _create_action_button("", _on_markdown_pressed)
	markdown_button.icon = editor_theme.get_icon("FileList", "EditorIcons")
	markdown_button.tooltip_text = "Print tree structure \"briefly\" as markdown (Check out your Output Window)"
	markdown_button.disabled = false
	
	var boilerplate_button = _create_action_button("", _on_boilerplate_pressed)
	boilerplate_button.icon = editor_theme.get_icon("Script", "EditorIcons")
	boilerplate_button.tooltip_text = "Generate boilerplate code for AnimationTree usage (Check out your Output Window)"
	boilerplate_button.disabled = false
	
	button_container.add_child(copy_button)
	button_container.add_child(paste_button)
	button_container.add_child(delete_button)
	button_container.add_child(markdown_button)
	button_container.add_child(boilerplate_button)

func _create_action_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	button.disabled = true
	return button

func _add_tree_view_section(container: VBoxContainer) -> void:
	var tree_label := Label.new()
	tree_label.text = "Animation Tree Structure:"
	container.add_child(tree_label)
	
	tree_view = Tree.new()
	tree_view.item_selected.connect(_on_tree_item_selected)
	tree_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(tree_view)

# New function to update clipboard status display
func _update_clipboard_status(has_content: bool, node_type: String = "", source_tree_name: String = "", node_name: String = "") -> void:
	if has_content:
		clipboard_status_label.text = "Copied: %s (%s) from '%s'" % [node_name, node_type, source_tree_name]
		clipboard_status_label.modulate = Color.GREEN
		if selected_animation_tree:
			paste_button.disabled = false
	else:
		clipboard_status_label.text = "Empty clipboard"
		clipboard_status_label.modulate = Color.GRAY
		paste_button.disabled = true

func _auto_detect_animation_tree() -> void:
	var found_tree: AnimationTree = _find_selected_animation_tree()
	if not found_tree:
		found_tree = _find_scene_animation_tree()
	
	if found_tree:
		_set_animation_tree(found_tree)
	else:
		_set_error_status("No AnimationTree found. Please select one.", Color.RED)

func _find_selected_animation_tree() -> AnimationTree:
	var selected_nodes: Array[Node] = EditorInterface.get_selection().get_selected_nodes()
	for node in selected_nodes:
		if node is AnimationTree:
			return node as AnimationTree
	return null

func _find_scene_animation_tree() -> AnimationTree:
	var current_scene: Node = EditorInterface.get_edited_scene_root()
	return _find_animation_tree_in_node(current_scene) if current_scene else null

func _find_animation_tree_in_node(node: Node) -> AnimationTree:
	if node is AnimationTree:
		return node as AnimationTree
	
	for child in node.get_children():
		var result: AnimationTree = _find_animation_tree_in_node(child)
		if result:
			return result
	
	return null

func _set_animation_tree(tree: AnimationTree) -> void:
	selected_animation_tree = tree
	
	if not _validate_animation_tree(tree):
		return
	
	_set_success_status("%s ✓" % tree.name, Color.GREEN)
	_enable_controls(true)
	_refresh_tree_view()
	
	# Check if we need to update paste button based on clipboard status
	_update_paste_button_state()

func _update_paste_button_state() -> void:
	# This will be called by the plugin to update paste state
	# when clipboard status changes or tree selection changes
	pass

func _validate_animation_tree(tree: AnimationTree) -> bool:
	if not tree or not tree.tree_root:
		_set_error_status("AnimationTree has no tree_root", Color.YELLOW)
		return false
	return true

func _set_success_status(message: String, color: Color) -> void:
	status_label.text = message
	status_label.modulate = color

func _set_error_status(message: String, color: Color) -> void:
	status_label.text = message
	status_label.modulate = color

func _enable_controls(enabled: bool) -> void:
	copy_button.disabled = not enabled
	delete_button.disabled = not enabled
	
	# Paste button depends on both tree selection AND clipboard content
	# This will be properly managed by the plugin

func _refresh_tree_view() -> void:
	tree_view.clear()
	
	if not _validate_animation_tree(selected_animation_tree):
		debug_print("No AnimationTree or tree_root found")
		return
	
	debug_print("Refreshing tree view for: %s" % selected_animation_tree.tree_root.get_class())
	
	var root: TreeItem = tree_view.create_item()
	root.set_text(0, "Root (%s)" % selected_animation_tree.tree_root.get_class())
	root.set_metadata(0, "")
	
	_populate_tree_item(selected_animation_tree.tree_root, root, "")
	

func _populate_tree_item(node: AnimationNode, tree_item: TreeItem, path: String) -> void:
	debug_print("Populating node: %s at path: %s" % [node.get_class(), path])
	
	if node is AnimationNodeStateMachine:
		_populate_state_machine(node as AnimationNodeStateMachine, tree_item, path)
	elif node is AnimationNodeBlendTree:
		_populate_blend_tree(node as AnimationNodeBlendTree, tree_item, path)
	elif _is_blend_space(node):
		debug_print("BlendSpace node detected but not fully supported yet")
	else:
		debug_print("Unknown node type or leaf node: %s" % node.get_class())

func _populate_state_machine(state_machine: AnimationNodeStateMachine, tree_item: TreeItem, path: String) -> void:
	var editor_theme = EditorInterface.get_editor_theme()
	var transitions_folder_icon = editor_theme.get_icon("ArrowRight", "EditorIcons")
	var transition_icon = editor_theme.get_icon("ArrowRight", "EditorIcons")
	var expression_icon = editor_theme.get_icon("Script", "EditorIcons") # Perfect fit for code/logic

	var state_names: Array = _get_container_children(state_machine, "states")
	debug_print("Got states via property inspection: %s" % str(state_names))

	for state_name in state_names:
		var child_path: String = _build_child_path(path, state_name)
		var state_node: AnimationNode = state_machine.get("states/%s/node" % state_name) as AnimationNode
		_add_tree_item(tree_item, state_name, state_node, child_path)

	var transition_count = state_machine.get_transition_count()
	
	if transition_count > 0:
		var transitions_item: TreeItem = tree_item.create_child()
		transitions_item.set_text(0, "Transitions")
		transitions_item.set_selectable(0, false)
		transitions_item.set_custom_color(0, Color.GOLD)
		transitions_item.set_icon(0, transitions_folder_icon)
		transitions_item.collapsed = true
		for i in range(transition_count):
			var from_node = state_machine.get_transition_from(i)
			var to_node = state_machine.get_transition_to(i)
			var transition: AnimationNodeStateMachineTransition = state_machine.get_transition(i)
			
			if transition:
				var transition_label = "%s -> %s" % [from_node, to_node]
				var transition_child_item: TreeItem = transitions_item.create_child()
				transition_child_item.set_text(0, transition_label)
				transition_child_item.set_selectable(0, false)
				# NEW: Assign an icon to the transition itself
				transition_child_item.set_icon(0, transition_icon)
				
				# Store transition metadata including switch mode
				var transition_metadata: Dictionary = {
					"type": "transition",
					"from": from_node,
					"to": to_node,
					"switch_mode": transition.switch_mode
				}
				transition_child_item.set_metadata(0, transition_metadata)

				var expression: String = transition.get("advance_expression")
				if not expression.is_empty():
					var expression_item: TreeItem = transition_child_item.create_child()
					expression_item.set_text(0, "Expression: %s" % expression)
					expression_item.set_selectable(0, false)
					expression_item.set_custom_color(0, Color.AQUAMARINE)
					expression_item.set_icon(0, expression_icon)
	
					# Add metadata for the expression
					var expression_metadata: Dictionary = {
						"type": "expression",
						"expression": expression
					}
					expression_item.set_metadata(0, expression_metadata)
	

func _populate_blend_tree(blend_tree: AnimationNodeBlendTree, tree_item: TreeItem, path: String) -> void:
	debug_print("Processing BlendTree node...")
	
	var node_names: Array = _get_container_children(blend_tree, "nodes")
	debug_print("Found BlendTree node names: %s" % str(node_names))
	
	for node_name in node_names:
		if node_name == "output":
			continue
		
		var child_path: String = _build_child_path(path, node_name)
		var blend_node: AnimationNode = _get_blend_tree_node(blend_tree, node_name)
		_add_tree_item(tree_item, node_name, blend_node, child_path)

func _get_container_children(container: AnimationNode, prefix: String) -> Array:
	var child_names: Array = []
	var properties: Array[Dictionary] = container.get_property_list()
	
	for prop in properties:
		if prop.name.begins_with("%s/" % prefix) and prop.name.ends_with("/node"):
			var child_name: String = prop.name.trim_prefix("%s/" % prefix).trim_suffix("/node")
			child_names.append(child_name)
	
	return child_names

#### Additional "Sugar":
###### Markdown
func export_tree_structure_as_markdown() -> String:
	if not selected_animation_tree or not tree_view.get_root():
		return "# No Animation Tree\n\nNo AnimationTree selected or tree is empty."
	
	var markdown: String = "# Animation Tree Structure\n\n"
	markdown += "**Tree:** %s\n\n" % selected_animation_tree.name
	
	var root_item: TreeItem = tree_view.get_root()
	markdown += _tree_item_to_markdown(root_item, 0)
	
	return markdown

func _tree_item_to_markdown(item: TreeItem, depth: int) -> String:
	var result: String = ""
	var indent: String = "  ".repeat(depth)
	var bullet: String = "- " if depth > 0 else ""
	
	var item_text: String = item.get_text(0)
	var metadata = item.get_metadata(0)
	
	# Check metadata type first
	if metadata is Dictionary:
		if metadata.get("type") == "expression":
			# Expression item - put in code block
			var expression: String = metadata.get("expression", "")
			result += "%s```gdscript\n%s%s\n%s```\n" % [indent, indent,  expression, indent]
		elif metadata.get("type") == "transition":
			# Transition item with switch mode
			var from: String = metadata.get("from", "")
			var to: String = metadata.get("to", "")
			var switch_mode: int = metadata.get("switch_mode", 0)
			var switch_mode_text: String = _get_switch_mode_text(switch_mode)
			result += "%s%s%s%s → %s [SwitchMode=%s]\n" % [indent, bullet, _get_markdown_icon_for_type("NULL"), from, to, switch_mode_text]
		else:
			# Regular node with metadata
			var node_type: String = metadata.get("node_type", "Unknown")
			var icon: String = _get_markdown_icon_for_type(node_type)
			result += "%s%s%s **%s**\n" % [indent, bullet, icon, item_text]
	else:
		# Regular node without proper metadata
		result += "%s%s🔹 %s\n" % [indent, bullet, item_text]
	
	# Process children
	var child: TreeItem = item.get_first_child()
	while child:
		result += _tree_item_to_markdown(child, depth + 1)
		child = child.get_next()
	
	return result

func _get_switch_mode_text(switch_mode: int) -> String:
	match switch_mode:
		0: # AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
			return "Immediate"
		1: # AnimationNodeStateMachineTransition.SWITCH_MODE_SYNC
			return "Sync"
		2: # AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
			return "At End"
		_:
			return "Unknown"
	
func _get_markdown_icon_for_type(node_type: String) -> String:
	match node_type:
		"AnimationNodeStateMachine":
			return "🔀"
		"AnimationNodeBlendTree":
			return "🌳"
		"AnimationNodeAnimation":
			return "🎬"
		"AnimationNodeBlendSpace1D":
			return "📊"
		"AnimationNodeBlendSpace2D":
			return "📈"
		"AnimationNodeAdd2", "AnimationNodeAdd3":
			return "➕"
		"AnimationNodeBlend2", "AnimationNodeBlend3":
			return "🔀"
		"AnimationNodeOneShot":
			return "🔥"
		"AnimationNodeTransition":
			return "🔄"
		"NULL":
			return ""
		_:
			return "🔹"
####### Gd script boilerplate
func _on_boilerplate_pressed() -> void:
	print(generate_animation_tree_boilerplate())

func generate_animation_tree_boilerplate() -> String:
	if not selected_animation_tree or not selected_animation_tree.tree_root:
		return "# No Animation Tree\n\n# No AnimationTree selected or tree is empty."
	
	var boilerplate: String = "# Generated AnimationTree Boilerplate Code\n"
	boilerplate += "# Copy this code into your character script\n\n"
	
	# Generate @onready variables
	var state_machines: Array[Dictionary] = _collect_state_machines(selected_animation_tree.tree_root, "")
	boilerplate += _generate_onready_variables(state_machines)
	boilerplate += "\n"
	
	# Generate match statements
	boilerplate += _generate_match_statements(state_machines)
	
	return boilerplate

func _collect_state_machines(node: AnimationNode, path: String) -> Array[Dictionary]:
	var state_machines: Array[Dictionary] = []
	
	if node is AnimationNodeStateMachine:
		var state_machine_info: Dictionary = {
			"path": path,
			"variable_name": _path_to_variable_name(path),
			"states": _get_state_machine_states(node as AnimationNodeStateMachine),
			"node": node
		}
		state_machines.append(state_machine_info)
		
		# Recursively check child states for nested state machines
		var state_names: Array = _get_container_children(node, "states")
		for state_name in state_names:
			var child_path: String = _build_child_path(path, state_name)
			var state_node: AnimationNode = node.get("states/%s/node" % state_name) as AnimationNode
			if state_node:
				var child_state_machines: Array[Dictionary] = _collect_state_machines(state_node, child_path)
				state_machines.append_array(child_state_machines)
	
	elif node is AnimationNodeBlendTree:
		# Check blend tree nodes for state machines
		var node_names: Array = _get_container_children(node, "nodes")
		for node_name in node_names:
			if node_name == "output":
				continue
			var child_path: String = _build_child_path(path, node_name)
			var blend_node: AnimationNode = _get_blend_tree_node(node, node_name)
			if blend_node:
				var child_state_machines: Array[Dictionary] = _collect_state_machines(blend_node, child_path)
				state_machines.append_array(child_state_machines)
	
	return state_machines

func _get_state_machine_states(state_machine: AnimationNodeStateMachine) -> Array[String]:
	var states: Array[String] = []
	var state_names: Array = _get_container_children(state_machine, "states")
	for state_name in state_names:
		states.append(state_name as String)
	return states

func _path_to_variable_name(path: String) -> String:
	# Split the path by "/" and return the last part
	var parts: PackedStringArray = path.split("/")
	return parts[parts.size() - 1].to_snake_case()

func _generate_onready_variables(state_machines: Array[Dictionary]) -> String:
	var code: String = "# Generated AnimationNodeStateMachinePlayback variables\n"
	
	for sm_info in state_machines:
		var path: String = sm_info.path
		var var_name: String = sm_info.variable_name
		
		# Build the parameter path for playback
		var param_path: String = "parameters"
		if not path.is_empty():
			param_path += "/" + path
		param_path += "/playback"
		
		code += "@onready var %s: AnimationNodeStateMachinePlayback = animation_tree.get(\"%s\")\n" % [var_name, param_path]
	
	return code

func _generate_match_statements(state_machines: Array[Dictionary]) -> String:
	var code: String = "# Generated match statements\n"
	code += "# Add this to your _physics_process or appropriate function\n\n"
	
	if state_machines.is_empty():
		return code + "# No state machines found\n"
	
	# Find the top-level state machine (shortest path or first StateMachine found)
	var main_sm: Dictionary
	var shortest_path_length: int = 999
	
	for sm_info in state_machines:
		var path_parts = sm_info.path.split("/") if not sm_info.path.is_empty() else []
		if path_parts.size() < shortest_path_length:
			shortest_path_length = path_parts.size()
			main_sm = sm_info
	
	if main_sm.is_empty():
		return code + "# No main state machine found\n"
	
	code += _generate_match_statement_recursive(main_sm, state_machines, 0)
	
	return code

func _generate_match_statement_recursive(sm_info: Dictionary, all_state_machines: Array[Dictionary], indent_level: int) -> String:
	var indent: String = "\t".repeat(indent_level)
	var var_name: String = sm_info.variable_name
	var states: Array[String] = sm_info.states
	
	var code: String = "%smatch %s.get_current_node():\n" % [indent, var_name]
	
	for state in states:
		code += "%s\t\"%s\":\n" % [indent, state]
		
		# Check if this state has a nested state machine
		var nested_sm: Dictionary = _find_nested_state_machine(sm_info.path, state, all_state_machines)
		if not nested_sm.is_empty():
			code += _generate_match_statement_recursive(nested_sm, all_state_machines, indent_level + 2)
		else:
			code += "%s\t\t# TODO: Add logic for %s\n" % [indent, state]
	
	code += "%s\t_: # Default case\n" % [indent]
	code += "%s\t\tpass\n" % [indent]
	
	return code

func _find_nested_state_machine(parent_path: String, state_name: String, all_state_machines: Array[Dictionary]) -> Dictionary:
	var target_path: String = _build_child_path(parent_path, state_name)
	
	for sm_info in all_state_machines:
		if sm_info.path == target_path:
			return sm_info
	
	return {}
##########################################
func _build_child_path(parent_path: String, child_name: String) -> String:
	return "%s/%s" % [parent_path, child_name] if not parent_path.is_empty() else child_name

func _get_blend_tree_node(blend_tree: AnimationNodeBlendTree, node_name: String) -> AnimationNode:
	if blend_tree.has_method("get_node"):
		return blend_tree.get_node(node_name) as AnimationNode
	return blend_tree.get("nodes/%s/node" % node_name) as AnimationNode

# Instead of storing just the path as metadata, store a dictionary
func _add_tree_item(parent_item: TreeItem, node_name: String, node: AnimationNode, path: String) -> void:
	var child_item: TreeItem = parent_item.create_child()
	
	if node:
		child_item.set_text(0, "%s (%s)" % [node_name, node.get_class()])
		
		# Store both path and node type information
		var metadata: Dictionary = {
			"path": path,
			"node_type": node.get_class(),
			"node_name": node_name,
			"has_children": _can_have_children(node)
		}
		child_item.set_metadata(0, metadata)
		
		if _can_have_children(node):
			_populate_tree_item(node, child_item, path)
	else:
		child_item.set_text(0, "%s Node" % node_name)
		var metadata: Dictionary = {
			"path": path,
			"node_type": "NULL",
			"node_name": node_name,
			"has_children": false
		}
		child_item.set_metadata(0, metadata)

func _is_blend_space(node: AnimationNode) -> bool:
	return node is AnimationNodeBlendSpace1D or node is AnimationNodeBlendSpace2D

func _can_have_children(node: AnimationNode) -> bool:
	return node is AnimationNodeStateMachine or node is AnimationNodeBlendTree

func _set_path_display(text: String, color: Color) -> void:
	path_label.text = text
	path_label.modulate = color

# Fix _on_tree_item_selected
func _on_tree_item_selected() -> void:
	var selected_item: TreeItem = tree_view.get_selected()
	if not selected_item:
		_set_path_display("No selection", Color.GRAY)
		return
	
	var metadata = selected_item.get_metadata(0)
	var item_path: String
	
	# Handle both old string format and new dictionary format
	if metadata is Dictionary:
		item_path = metadata.get("path", "")
	else:
		item_path = str(metadata) if metadata != null else ""
	
	var display_text: String = item_path if not item_path.is_empty() else "Root"
	_set_path_display(display_text, Color.WHITE)

# Fix the button press handlers
func _on_copy_pressed() -> void:
	var selected_item: TreeItem = tree_view.get_selected()
	if not _validate_selection(selected_item):
		return
		
	var metadata = selected_item.get_metadata(0)
	var node_path: String = metadata.get("path", "") if metadata is Dictionary else str(metadata)
	copy_requested.emit(selected_animation_tree, node_path)

func _on_paste_pressed() -> void:
	var selected_item: TreeItem = tree_view.get_selected()
	if not _validate_selection(selected_item):
		return
		
	var metadata = selected_item.get_metadata(0)
	var target_path: String = metadata.get("path", "") if metadata is Dictionary else str(metadata)
	paste_requested.emit(selected_animation_tree, target_path)

func _on_delete_pressed() -> void:
	var selected_item: TreeItem = tree_view.get_selected()
	if not _validate_selection(selected_item):
		return
		
	var metadata = selected_item.get_metadata(0)
	var node_path: String = metadata.get("path", "") if metadata is Dictionary else str(metadata)
	if node_path.is_empty():
		debug_print("Cannot delete root node")
		return
		
	delete_requested.emit(selected_animation_tree, node_path)

func _on_markdown_pressed() -> void:
	print(export_tree_structure_as_markdown())


func _validate_selection(selected_item: TreeItem) -> bool:
	if not selected_animation_tree:
		debug_print("No AnimationTree selected")
		return false
	if not selected_item:
		debug_print("No tree item selected")
		return false
	return true

# Enhanced tree update system with state preservation
func update_tree_view_after_operation() -> void:
	var current_state: Dictionary = _capture_tree_state()
	await get_tree().process_frame
	
	_refresh_tree_view()
	await get_tree().process_frame
	
	_restore_tree_state(current_state)

func _capture_tree_state() -> Dictionary:
	var state: Dictionary = {
		"selected_path": "",
		"expanded_paths": []
	}
	
	var selected_item: TreeItem = tree_view.get_selected()
	if selected_item:
		var metadata = selected_item.get_metadata(0)
		state.selected_path = metadata.get("path", "") if metadata is Dictionary else str(metadata)
	
	var root_item: TreeItem = tree_view.get_root()
	if root_item:
		_collect_expanded_items(root_item, state.expanded_paths as Array)
	
	debug_print("Captured tree state - expanded: %s" % str(state.expanded_paths))
	return state

func _restore_tree_state(state: Dictionary) -> void:
	var expanded_paths := state.expanded_paths as Array
	if expanded_paths.size() > 0:
		_restore_expanded_items(tree_view.get_root(), expanded_paths)
		debug_print("Restored expanded states")
	
	var selected_path := state.selected_path as String
	if not selected_path.is_empty():
		_select_item_by_path(tree_view.get_root(), selected_path)

# Fix _collect_expanded_items
func _collect_expanded_items(item: TreeItem, expanded_paths: Array) -> void:
	if not item.is_collapsed() and item != tree_view.get_root():
		var metadata = item.get_metadata(0)
		var path: String
		
		if metadata is Dictionary:
			path = metadata.get("path", "")
		else:
			path = str(metadata) if metadata != null else ""
			
		if not path.is_empty():
			expanded_paths.append(path)
			debug_print("Found expanded item: %s" % path)
	
	_process_tree_children(item, func(child: TreeItem): _collect_expanded_items(child, expanded_paths))

# Fix _restore_expanded_items
func _restore_expanded_items(item: TreeItem, expanded_paths: Array) -> void:
	var metadata = item.get_metadata(0)
	var item_path: String
	
	if metadata is Dictionary:
		item_path = metadata.get("path", "")
	else:
		item_path = str(metadata) if metadata != null else ""
	
	if not item_path.is_empty() and item_path in expanded_paths:
		item.set_collapsed(false)
		debug_print("Restored expanded state for: %s" % item_path)
	elif item != tree_view.get_root():
		item.set_collapsed(true)
	
	_process_tree_children(item, func(child: TreeItem): _restore_expanded_items(child, expanded_paths))

# Fix _select_item_by_path
func _select_item_by_path(item: TreeItem, target_path: String) -> bool:
	var metadata = item.get_metadata(0)
	var item_path: String
	
	if metadata is Dictionary:
		item_path = metadata.get("path", "")
	else:
		item_path = str(metadata) if metadata != null else ""
	
	if item_path == target_path:
		item.select(0)
		return true
	
	return _search_tree_children(item, func(child: TreeItem) -> bool: return _select_item_by_path(child, target_path))

func _process_tree_children(item: TreeItem, callback: Callable) -> void:
	var child: TreeItem = item.get_first_child()
	while child:
		callback.call(child)
		child = child.get_next()

func _search_tree_children(item: TreeItem, callback: Callable) -> bool:
	var child: TreeItem = item.get_first_child()
	while child:
		if callback.call(child):
			return true
		child = child.get_next()
	return false

# Clean up the selection signal connection when the dock is destroyed
func _exit_tree() -> void:
	if editor_selection and editor_selection.selection_changed.is_connected(_on_editor_selection_changed):
		editor_selection.selection_changed.disconnect(_on_editor_selection_changed)
		debug_print("Disconnected from editor selection changes")
