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
var refresh_button: Button

# For automatic detection
var editor_selection: EditorSelection

func _init() -> void:
	name = "AnimTree Copy/Paste"
	_create_ui()
	_setup_auto_detection()

func _setup_auto_detection() -> void:
	# Connect to editor selection changes for automatic detection
	editor_selection = EditorInterface.get_selection()
	if editor_selection:
		editor_selection.selection_changed.connect(_on_editor_selection_changed)
		debug_print("Connected to editor selection changes")
	_detect_selected_animation_tree()

func _detect_selected_animation_tree() -> void:
	var selected_nodes: Array[Node] = editor_selection.get_selected_nodes()
	
	for node in selected_nodes:
		if node is AnimationTree:
			debug_print("Auto-detected AnimationTree: %s" % node.name)
			_set_animation_tree(node as AnimationTree)
			return
	debug_print("No AnimationTree in current selection")
	
func _on_editor_selection_changed() -> void:
	# Automatically detect AnimationTree when selection changes
	_detect_selected_animation_tree()

func debug_print(message: String) -> void:
	if DEBUG_MODE:
		print(message)

func _create_ui() -> void:
	var vbox := VBoxContainer.new()
	add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	_add_title_section(vbox)
	_add_tree_selection_section(vbox)
	_add_separator(vbox)
	_add_clipboard_status_section(vbox)
	_add_separator(vbox)
	_add_path_section(vbox)
	_add_buttons_section(vbox)
	_add_separator(vbox)
	_add_tree_view_section(vbox)
	_add_refresh_button(vbox)

func _add_title_section(container: VBoxContainer) -> void:
	var title := Label.new()
	title.text = "Animation Tree Helper"
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	container.add_child(title)

func _add_tree_selection_section(container: VBoxContainer) -> void:
	var select_button := Button.new()
	select_button.text = "Force - Detect Anim.Tree"
	select_button.pressed.connect(_auto_detect_animation_tree)
	container.add_child(select_button)
	
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
	
	copy_button = _create_action_button("Copy", _on_copy_pressed)
	paste_button = _create_action_button("Paste", _on_paste_pressed)
	delete_button = _create_action_button("Delete", _on_delete_pressed)
	
	button_container.add_child(copy_button)
	button_container.add_child(paste_button)
	button_container.add_child(delete_button)

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

func _add_refresh_button(container: VBoxContainer) -> void:
	refresh_button = Button.new()
	refresh_button.text = "Refresh Tree"
	refresh_button.pressed.connect(_refresh_tree_view)
	refresh_button.disabled = true
	container.add_child(refresh_button)

# New function to update clipboard status display
func _update_clipboard_status(has_content: bool, node_type: String = "", source_tree_name: String = "") -> void:
	if has_content:
		clipboard_status_label.text = "Copied: %s from '%s'" % [node_type, source_tree_name]
		clipboard_status_label.modulate = Color.GREEN
		# Enable paste button if we have content and a valid target
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
	
	_set_success_status("AnimationTree: %s ✓" % tree.name, Color.GREEN)
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
	refresh_button.disabled = not enabled
	
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
	var state_names: Array = _get_container_children(state_machine, "states")
	debug_print("Got states via property inspection: %s" % str(state_names))
	
	for state_name in state_names:
		var child_path: String = _build_child_path(path, state_name)
		var state_node: AnimationNode = state_machine.get("states/%s/node" % state_name) as AnimationNode
		_add_tree_item(tree_item, state_name, state_node, child_path)

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

func _build_child_path(parent_path: String, child_name: String) -> String:
	return "%s/%s" % [parent_path, child_name] if not parent_path.is_empty() else child_name

func _get_blend_tree_node(blend_tree: AnimationNodeBlendTree, node_name: String) -> AnimationNode:
	if blend_tree.has_method("get_node"):
		return blend_tree.get_node(node_name) as AnimationNode
	return blend_tree.get("nodes/%s/node" % node_name) as AnimationNode

func _add_tree_item(parent_item: TreeItem, node_name: String, node: AnimationNode, path: String) -> void:
	var child_item: TreeItem = parent_item.create_child()
	
	if node:
		child_item.set_text(0, "%s (%s)" % [node_name, node.get_class()])
		child_item.set_metadata(0, path)
		
		if _can_have_children(node):
			_populate_tree_item(node, child_item, path)
	else:
		child_item.set_text(0, "%s (NULL)" % node_name)
		child_item.set_metadata(0, path)

func _is_blend_space(node: AnimationNode) -> bool:
	return node is AnimationNodeBlendSpace1D or node is AnimationNodeBlendSpace2D

func _can_have_children(node: AnimationNode) -> bool:
	return node is AnimationNodeStateMachine or node is AnimationNodeBlendTree

func _on_tree_item_selected() -> void:
	var selected_item: TreeItem = tree_view.get_selected()
	if not selected_item:
		_set_path_display("No selection", Color.GRAY)
		return
	
	var item_path: String = selected_item.get_metadata(0)
	var display_text: String = item_path if not item_path.is_empty() else "Root"
	_set_path_display(display_text, Color.WHITE)

func _set_path_display(text: String, color: Color) -> void:
	path_label.text = text
	path_label.modulate = color

func _on_copy_pressed() -> void:
	var selected_item: TreeItem = tree_view.get_selected()
	if not _validate_selection(selected_item):
		return
		
	var node_path: String = selected_item.get_metadata(0)
	copy_requested.emit(selected_animation_tree, node_path)

func _on_paste_pressed() -> void:
	var selected_item: TreeItem = tree_view.get_selected()
	if not _validate_selection(selected_item):
		return
		
	var target_path: String = selected_item.get_metadata(0)
	paste_requested.emit(selected_animation_tree, target_path)

func _on_delete_pressed() -> void:
	var selected_item: TreeItem = tree_view.get_selected()
	if not _validate_selection(selected_item):
		return
		
	var node_path: String = selected_item.get_metadata(0)
	if node_path.is_empty():
		debug_print("Cannot delete root node")
		return
		
	delete_requested.emit(selected_animation_tree, node_path)

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
		state.selected_path = selected_item.get_metadata(0)
	
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

func _collect_expanded_items(item: TreeItem, expanded_paths: Array) -> void:
	if not item.is_collapsed() and item != tree_view.get_root():
		var path: Variant = item.get_metadata(0)
		if path != null and path != "":
			expanded_paths.append(path)
			debug_print("Found expanded item: %s" % path)
	
	_process_tree_children(item, func(child: TreeItem): _collect_expanded_items(child, expanded_paths))

func _restore_expanded_items(item: TreeItem, expanded_paths: Array) -> void:
	var item_path: Variant = item.get_metadata(0)
	
	if item_path != null and item_path in expanded_paths:
		item.set_collapsed(false)
		debug_print("Restored expanded state for: %s" % item_path)
	elif item != tree_view.get_root():
		item.set_collapsed(true)
	
	_process_tree_children(item, func(child: TreeItem): _restore_expanded_items(child, expanded_paths))

func _select_item_by_path(item: TreeItem, target_path: String) -> bool:
	if item.get_metadata(0) == target_path:
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
