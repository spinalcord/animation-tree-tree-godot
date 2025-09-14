@tool
extends EditorPlugin

var dock: Control
var clipboard_data: Dictionary = {}

# Debug mode flag - set to false to disable debug prints
const DEBUG_MODE: bool = true

func debug_print(message: String) -> void:
	if DEBUG_MODE:
		print(message)

func _enter_tree() -> void:
	# Add the custom dock to the left UL dock
	dock = preload("./animation_tree_dock.gd").new()
	add_control_to_dock(DOCK_SLOT_LEFT_UL, dock)
	
	# Connect to dock signals
	dock.copy_requested.connect(_on_copy_requested)
	dock.paste_requested.connect(_on_paste_requested)
	dock.delete_requested.connect(_on_delete_requested)
	
	scene_changed.connect(_on_scene_changed)

	debug_print("AnimationTree-Tree Plugin loaded")

func _on_scene_changed(scene_root: Node) -> void:
	# Only update if we have a valid dock and AnimationTree selected
	# Add safety checks to prevent null parameter errors
	if not is_instance_valid(dock):
		return
	
	# Use call_deferred to ensure scene is fully loaded
	call_deferred("_refresh_dock_safely")

func _refresh_dock_safely() -> void:
	# Double-check dock is still valid
	if not is_instance_valid(dock):
		return
	
	# Ensure the dock has a valid parent before refreshing
	if dock.get_parent() == null:
		return
	
	dock._refresh_tree_view()

func _exit_tree() -> void:
	# Ensure dock is valid before removing
	if is_instance_valid(dock) and dock.get_parent() != null:
		remove_control_from_docks(dock)
	dock = null

# Enhanced copy function that stores source tree info
func _on_copy_requested(animation_tree: AnimationTree, node_path: String) -> void:
	# Add validation to prevent null parameter errors
	if not is_instance_valid(animation_tree) or not animation_tree.tree_root:
		debug_print("No valid Animation Tree selected")
		return
	
	var node: AnimationNode = _get_node_at_path(animation_tree.tree_root, node_path)
	if not is_instance_valid(node):
		debug_print("Node not found at path: " + node_path)
		return
	
	# Deep copy the animation node with safety checks
	var copied_node: AnimationNode = _deep_copy_animation_node(node)
	if not is_instance_valid(copied_node):
		debug_print("Failed to copy animation node")
		return
	
	clipboard_data = {
		"type": "animation_node",
		"node": copied_node,
		"original_path": node_path,
		"node_type": node.get_class(),
		"source_tree_name": animation_tree.name,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# Update dock to show clipboard status with validation
	if is_instance_valid(dock):
		dock._update_clipboard_status(true, node.get_class(), animation_tree.name)
	
	debug_print("Copied node: " + node.get_class() + " from path: " + node_path + " (from tree: " + animation_tree.name + ")")

# Enhanced paste function with better cross-tree support
func _on_paste_requested(animation_tree: AnimationTree, target_path: String) -> void:
	if not clipboard_data.has("node"):
		debug_print("Nothing in clipboard")
		if is_instance_valid(dock):
			dock._update_clipboard_status(false, "", "")
		return
	
	# Validate animation tree and node
	if not is_instance_valid(animation_tree) or not is_instance_valid(animation_tree.tree_root):
		debug_print("No valid Animation Tree selected")
		return
	
	# Validate clipboard node is still valid
	var clipboard_node = clipboard_data.node as AnimationNode
	if not is_instance_valid(clipboard_node):
		debug_print("Clipboard node is no longer valid")
		clipboard_data.clear()
		if is_instance_valid(dock):
			dock._update_clipboard_status(false, "", "")
		return
	
	# Get the target node directly instead of its parent
	var target_node: AnimationNode = _get_node_at_path(animation_tree.tree_root, target_path)
	if not is_instance_valid(target_node):
		debug_print("Target node not found at path: " + target_path)
		return
	
	# Check if target can accept children
	if not (target_node is AnimationNodeStateMachine or target_node is AnimationNodeBlendTree):
		debug_print("Target node cannot accept children. Target type: " + target_node.get_class())
		return
	
	# Create new node from clipboard (always create a fresh copy)
	var new_node: AnimationNode = _deep_copy_animation_node(clipboard_node)
	if not is_instance_valid(new_node):
		debug_print("Failed to create copy of clipboard node")
		return
	
	# Add directly to target node
	_add_node_to_container(target_node, new_node, target_path)
	
	# Update the dock's tree view without full refresh - use call_deferred for safety
	if is_instance_valid(dock):
		call_deferred("_update_dock_tree_safely")
	
	var source_info: String = ""
	if clipboard_data.has("source_tree_name"):
		source_info = " from tree: " + str(clipboard_data.source_tree_name)
	
	debug_print("Pasted node: " + clipboard_data.node_type + " to path: " + target_path + 
		  " (to tree: " + animation_tree.name + ")" + source_info)

func _update_dock_tree_safely() -> void:
	# Ensure dock is still valid and has parent
	if not is_instance_valid(dock) or dock.get_parent() == null:
		return
	
	dock.update_tree_view_after_operation()

func _on_delete_requested(animation_tree: AnimationTree, node_path: String) -> void:
	# Add validation to prevent null parameter errors
	if not is_instance_valid(animation_tree) or not is_instance_valid(animation_tree.tree_root):
		debug_print("No valid Animation Tree selected")
		return
	
	if node_path.is_empty():
		debug_print("Cannot delete root node")
		return
	
	var node: AnimationNode = _get_node_at_path(animation_tree.tree_root, node_path)
	var parent_path: String = _get_parent_path(node_path)
	var parent: AnimationNode = _get_node_at_path(animation_tree.tree_root, parent_path)
	
	if is_instance_valid(node) and is_instance_valid(parent):
		var dialog := ConfirmationDialog.new()
		dialog.dialog_text = "Delete this node?"
		
		# Ensure dialog has a valid parent before adding
		var main_screen := EditorInterface.get_editor_main_screen()
		if is_instance_valid(main_screen):
			main_screen.add_child(dialog)
		else:
			# Fallback to adding to dock if main screen not available
			if is_instance_valid(dock) and dock.get_parent() != null:
				dock.get_parent().add_child(dialog)
			else:
				debug_print("Could not show confirmation dialog - no valid parent")
				return
		
		dialog.popup_centered()

		await dialog.confirmed
		
		# Ensure dialog is still valid before freeing
		if is_instance_valid(dialog):
			dialog.queue_free()

		# Double-check nodes are still valid before deletion
		if is_instance_valid(node) and is_instance_valid(parent):
			_remove_node_from_parent(parent, node, node_path)
			
			# Update the dock's tree view without full refresh - use call_deferred
			if is_instance_valid(dock):
				call_deferred("_update_dock_tree_safely")
		
		debug_print("Deleted node: " + node.get_class() + " from path: " + node_path)

# Helper function to get clipboard status
func get_clipboard_status() -> Dictionary:
	if clipboard_data.has("node"):
		# Validate clipboard node is still valid
		var clipboard_node = clipboard_data.node as AnimationNode
		if not is_instance_valid(clipboard_node):
			clipboard_data.clear()
			return {"has_content": false, "node_type": "", "source_tree": "", "original_path": ""}
		
		return {
			"has_content": true,
			"node_type": clipboard_data.get("node_type", "Unknown"),
			"source_tree": clipboard_data.get("source_tree_name", "Unknown"),
			"original_path": clipboard_data.get("original_path", "")
		}
	else:
		return {
			"has_content": false,
			"node_type": "",
			"source_tree": "",
			"original_path": ""
		}

func _generate_random_id() -> String:
	const CHARS: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var result: String = ""
	for i in range(4):
		result += CHARS[randi() % CHARS.length()]
	return result

func _deep_copy_animation_node(node: AnimationNode) -> AnimationNode:
	# Use Godot's built-in duplicate method for deep copy with validation
	if not is_instance_valid(node):
		return null

	var copied_node: AnimationNode = node.duplicate(true)
	
	# Validate the copy was successful
	if not is_instance_valid(copied_node):
		debug_print("Failed to duplicate animation node")
		return null
		
	return copied_node

func _get_node_at_path(root: AnimationNode, path: String) -> AnimationNode:
	# Add validation to prevent null parameter errors
	if not is_instance_valid(root):
		return null
		
	if path.is_empty() or path == "/":
		return root
	
	var parts: PackedStringArray = path.split("/")
	var current: AnimationNode = root
	
	for part in parts:
		if part.is_empty():
			continue
		
		# Ensure current node is still valid
		if not is_instance_valid(current):
			return null
		
		if current is AnimationNodeStateMachine:
			# Use property access instead of get_state()
			var state_property: String = "states/" + part + "/node"
			var next_node = current.get(state_property)
			current = next_node as AnimationNode
		elif current is AnimationNodeBlendTree:
			# Use property access instead of get_node()
			var node_property: String = "nodes/" + part + "/node"
			var next_node = current.get(node_property)
			current = next_node as AnimationNode
		else:
			return null
		
		# Validate the retrieved node
		if not is_instance_valid(current):
			return null
	
	return current

func _get_parent_node_at_path(root: AnimationNode, path: String) -> AnimationNode:
	var parent_path: String = _get_parent_path(path)
	return _get_node_at_path(root, parent_path)

func _get_parent_path(path: String) -> String:
	var parts: PackedStringArray = path.split("/")
	if parts.size() <= 1:
		return ""
	
	# Convert to Array[String] and remove last element
	var parts_array: Array[String] = []
	for i in range(parts.size() - 1):  # Skip the last element
		parts_array.append(parts[i])
	
	var result_parts: PackedStringArray = PackedStringArray()
	for part in parts_array:
		result_parts.append(part)
	return "/".join(result_parts)

# Adds nodes directly to container with new naming scheme
func _add_node_to_container(container: AnimationNode, node: AnimationNode, container_path: String) -> void:
	debug_print("Attempting to add node to container: " + container.get_class())
	
	# Validate inputs to prevent null parameter errors
	if not is_instance_valid(container) or not is_instance_valid(node):
		debug_print("Invalid container or node for adding")
		return
	
	# Generate name with "new" prefix and original node class name + random ID
	var original_name: String = node.get_class().replace("AnimationNode", "").to_lower()
	var random_id: String = _generate_random_id()
	var base_name: String = "new" + original_name + random_id
	
	if container is AnimationNodeStateMachine:
		var state_machine := container as AnimationNodeStateMachine
		# Generate unique name for state
		var unique_name: String = _get_unique_state_name(state_machine, base_name)
		debug_print("Adding state: " + unique_name + " to StateMachine")
		
		# Calculate a good position near existing nodes
		var new_position: Vector2 = _calculate_good_position_for_state(state_machine)
		debug_print("Calculated position for new state: " + str(new_position))
		
		# Use Godot 4 API with validation
		if state_machine.has_method("add_node"):
			state_machine.add_node(unique_name, node, new_position)
			debug_print("Added state using add_node method")
		else:
			debug_print("add_node method not available, using property access")
			var state_property: String = "states/" + unique_name + "/node"
			var position_property: String = "states/" + unique_name + "/position"
			state_machine.set(state_property, node)
			state_machine.set(position_property, new_position)
			debug_print("Set state via property: " + state_property + " at position: " + str(new_position))
		
		# Force notification of changes with validation
		if state_machine.has_method("emit_changed"):
			state_machine.emit_changed()
		
	elif container is AnimationNodeBlendTree:
		var blend_tree := container as AnimationNodeBlendTree
		# Generate unique name for blend node
		var unique_name: String = _get_unique_node_name(blend_tree, base_name)
		debug_print("Adding node: " + unique_name + " to BlendTree")
		
		# Calculate a good position near existing nodes
		var new_position: Vector2 = _calculate_good_position_for_blend_node(blend_tree)
		debug_print("Calculated position for new blend node: " + str(new_position))
		
		# Use Godot 4 API with validation
		if blend_tree.has_method("add_node"):
			blend_tree.add_node(unique_name, node, new_position)
			debug_print("Added node using add_node method")
		else:
			debug_print("add_node method not available, using property access")
			var node_property: String = "nodes/" + unique_name + "/node"
			var position_property: String = "nodes/" + unique_name + "/position"
			blend_tree.set(node_property, node)
			blend_tree.set(position_property, new_position)
			debug_print("Set node via property: " + node_property + " at position: " + str(new_position))
		
		# Force notification of changes with validation
		if blend_tree.has_method("emit_changed"):
			blend_tree.emit_changed()

func _calculate_good_position_for_state(state_machine: AnimationNodeStateMachine) -> Vector2:
	# Validate input to prevent null parameter errors
	if not is_instance_valid(state_machine):
		return Vector2(100, 100)
	
	# Get positions of existing states
	var existing_positions: Array[Vector2] = []
	var properties: Array[Dictionary] = state_machine.get_property_list()
	
	for prop in properties:
		if prop.name.begins_with("states/") and prop.name.ends_with("/position"):
			var pos_value: Variant = state_machine.get(prop.name)
			if pos_value != null and pos_value is Vector2:
				existing_positions.append(pos_value as Vector2)
	
	debug_print("Found existing state positions: " + str(existing_positions))
	
	# If no existing positions, start at a reasonable default
	if existing_positions.is_empty():
		return Vector2(100, 100)
	
	# Find the rightmost position and add some offset
	var rightmost_x: float = -999999.0
	var average_y: float = 0.0
	
	for pos in existing_positions:
		if pos.x > rightmost_x:
			rightmost_x = pos.x
		average_y += pos.y
	
	average_y = average_y / existing_positions.size()
	
	# Position new node to the right with some spacing
	var new_position := Vector2(rightmost_x + 200, average_y)
	
	# Make sure it's not too far right, wrap to next "row" if needed
	if new_position.x > 1000:
		new_position.x = 100
		new_position.y = average_y + 150
	
	return new_position

func _calculate_good_position_for_blend_node(blend_tree: AnimationNodeBlendTree) -> Vector2:
	# Validate input to prevent null parameter errors
	if not is_instance_valid(blend_tree):
		return Vector2(100, 100)
	
	# Get positions of existing nodes
	var existing_positions: Array[Vector2] = []
	var properties: Array[Dictionary] = blend_tree.get_property_list()
	
	for prop in properties:
		if prop.name.begins_with("nodes/") and prop.name.ends_with("/position"):
			var node_name: String = prop.name.trim_prefix("nodes/").trim_suffix("/position")
			if node_name != "output":  # Skip output node
				var pos_value: Variant = blend_tree.get(prop.name)
				if pos_value != null and pos_value is Vector2:
					existing_positions.append(pos_value as Vector2)
	
	debug_print("Found existing blend node positions: " + str(existing_positions))
	
	# If no existing positions, start at a reasonable default
	if existing_positions.is_empty():
		return Vector2(100, 100)
	
	# Find the bottommost position and add some offset
	var bottommost_y: float = -999999.0
	var average_x: float = 0.0
	
	for pos in existing_positions:
		if pos.y > bottommost_y:
			bottommost_y = pos.y
		average_x += pos.x
	
	average_x = average_x / existing_positions.size()
	
	# Position new node below with some spacing
	var new_position := Vector2(average_x, bottommost_y + 120)
	
	# Make sure it's not too far down, wrap to next "column" if needed
	if new_position.y > 800:
		new_position.y = 100
		new_position.x = average_x + 250
	
	return new_position

func _remove_node_from_parent(parent: AnimationNode, node: AnimationNode, full_path: String) -> void:
	# Validate inputs to prevent null parameter errors
	if not is_instance_valid(parent) or not is_instance_valid(node):
		debug_print("Invalid parent or node for removal")
		return
	
	var node_name: String = _get_node_name_from_path(full_path)
	
	debug_print("Attempting to remove node: " + node_name + " from parent: " + parent.get_class())
	
	if parent is AnimationNodeStateMachine:
		var state_machine := parent as AnimationNodeStateMachine
		# Use the proper Godot 4+ API with validation
		if state_machine.has_method("has_node") and state_machine.has_method("remove_node"):
			if state_machine.has_node(node_name):
				debug_print("Found node, removing with remove_node()")
				state_machine.remove_node(node_name)
				debug_print("Successfully removed state: " + node_name)
			else:
				debug_print("Node not found in StateMachine: " + node_name)
		else:
			debug_print("StateMachine missing required methods")
		
	elif parent is AnimationNodeBlendTree:
		var blend_tree := parent as AnimationNodeBlendTree
		# Use the proper Godot 4+ API with validation
		if blend_tree.has_method("has_node") and blend_tree.has_method("remove_node"):
			if blend_tree.has_node(node_name):
				debug_print("Found node, removing with remove_node()")
				blend_tree.remove_node(node_name)
				debug_print("Successfully removed blend node: " + node_name)
			else:
				debug_print("Node not found in BlendTree: " + node_name)
		else:
			debug_print("BlendTree missing required methods")
	
	# Force notification of changes with validation
	if parent.has_method("emit_changed"):
		parent.emit_changed()
	if parent.has_method("notify_property_list_changed"):
		parent.notify_property_list_changed()

func _get_node_name_from_path(path: String) -> String:
	var parts: PackedStringArray = path.split("/")
	if parts.size() > 0:
		return parts[parts.size() - 1]
	return ""

func _get_unique_state_name(state_machine: AnimationNodeStateMachine, base_name: String) -> String:
	# Validate input to prevent null parameter errors
	if not is_instance_valid(state_machine):
		return base_name
	
	var counter: int = 1
	var unique_name: String = base_name
	
	while _has_state_property(state_machine, unique_name):
		unique_name = base_name + "_" + str(counter)
		counter += 1
	
	return unique_name

func _has_state_property(state_machine: AnimationNodeStateMachine, state_name: String) -> bool:
	# Check if state exists via property instead of has_state()
	if not is_instance_valid(state_machine):
		return false
	
	var state_property: String = "states/" + state_name + "/node"
	return state_machine.get(state_property) != null

func _get_unique_node_name(blend_tree: AnimationNodeBlendTree, base_name: String) -> String:
	# Validate input to prevent null parameter errors
	if not is_instance_valid(blend_tree):
		return base_name
	
	var counter: int = 1
	var unique_name: String = base_name
	
	while _has_node_property(blend_tree, unique_name):
		unique_name = base_name + "_" + str(counter)
		counter += 1
	
	return unique_name

func _has_node_property(blend_tree: AnimationNodeBlendTree, node_name: String) -> bool:
	# Check via property instead of has_node()
	if not is_instance_valid(blend_tree):
		return false
	
	var node_property: String = "nodes/" + node_name + "/node"
	return blend_tree.get(node_property) != null
