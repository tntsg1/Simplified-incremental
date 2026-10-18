extends SceneTree
# Builds res://locales/game.<code>.translation from every locales/<code>.json (Chinese key -> text).
# Files starting with "_" are working sources, not languages. Simplified Chinese gets an identity
# catalogue built from _source.json: without it, locale "zh" would resolve to zh_TW.

func _initialize() -> void:
	var failed := false
	var identity := Translation.new()
	identity.locale = "zh"
	for source in JSON.parse_string(FileAccess.get_file_as_string("res://locales/_source.json")):
		identity.add_message(source, source)
	failed = ResourceSaver.save(identity, "res://locales/game.zh.translation") != OK
	print("TRANSLATION_BUILD zh ", identity.get_message_count(), " identity messages")
	for file in DirAccess.get_files_at("res://locales"):
		if not file.ends_with(".json") or file.begins_with("_"):
			continue
		var code := file.get_basename()
		var messages: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://locales/" + file))
		if not messages is Dictionary:
			push_error("Invalid translation source " + file)
			failed = true
			continue
		var translation := Translation.new()
		translation.locale = code
		for source in messages:
			translation.add_message(source, messages[source])
		var result := ResourceSaver.save(translation, "res://locales/game.%s.translation" % code)
		print("TRANSLATION_BUILD ", code, " ", translation.get_message_count(), " messages; result ", result)
		failed = failed or result != OK
	quit(1 if failed else 0)
