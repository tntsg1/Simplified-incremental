extends SceneTree

func _initialize() -> void:
	var messages: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://locales/en.json"))
	if not messages is Dictionary:
		push_error("Invalid English translation source")
		quit(1)
		return
	var translation := Translation.new()
	translation.locale = "en"
	for source in messages:
		translation.add_message(source, messages[source])
	var result := ResourceSaver.save(translation, "res://locales/game.en.translation")
	print("TRANSLATION_BUILD ", translation.get_message_count(), " messages; result ", result)
	quit(0 if result == OK else 1)
