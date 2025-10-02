class_name Expert
var name: String
var manager: AIManager

func get_config_fields() -> Array[ConfigField]:
	return []

func get_system_prompt_path() -> String:
	return ""

func process(con_ai: ConAI, system_prompt: String, user_input: String) -> void:
	pass
