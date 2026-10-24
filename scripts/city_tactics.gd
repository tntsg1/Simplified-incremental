extends Node
# The missile settings page is opened by clicking the silo; no battle panel.
var game: Control

func setup(owner_game: Control) -> void:
	game = owner_game

func mode_name(value: int) -> String:
	return game.words("重点拦截", "Focused interception") if value == 0 else game.words("分路拦截", "Split interception")

func open_modes() -> void:
	game.menu = "city_modes"
	game.sim.paused = true
	game.sim.manual_held = false
	game.sim.manual_queued = false
	var column: VBoxContainer = game.new_modal(minf(620, game.size.x - 64), game.words("导弹发射井 · 射击模式", "Missile silo · Fire mode"), game.words("免费调整。战斗中更改，下波生效；准备时立即生效。", "Free to change. Combat changes apply next wave; preparation changes apply now."))
	for value in range(2):
		var chosen: int = value
		var description: String = game.words("一枚完整导弹打向所选目标。适合本体或裂隙。", "One full missile hits your target. Good for the body or fissure.") if value == 0 else game.words("最多三枚小导弹，各打一个目标，每枚伤害为原来的 1/3。目标不足不补发。", "Up to three small missiles hit different targets, each at 1/3 damage. Empty lanes waste firepower.")
		column.add_child(game.button(mode_name(value), func(): game.sim.set_city_mode(chosen); game.close_modal()))
		var explanation: Label = game.label(description, 15)
		explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(explanation)
	column.add_child(game.button(game.words("返回战场", "Return"), game.close_modal))
