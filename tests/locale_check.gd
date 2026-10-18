extends SceneTree
# Every language resolves to its own catalogue, and Simplified Chinese stays on the source keys.

func _initialize() -> void:
	for code in ["zh", "zh_CN", "en", "ja", "ko", "zh_TW", "fr", "de", "es", "pt_BR", "ru", "ar"]:
		TranslationServer.set_locale(code)
		print("LOCALE ", code, " -> ", TranslationServer.get_locale(), " | ", TranslationServer.translate("弹头"), " | ", TranslationServer.translate("语言"))
	quit()
