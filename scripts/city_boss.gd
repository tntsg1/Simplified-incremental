extends RefCounted
# Optional first-chapter lesson. Part damage transfers once, never twice.
const HP_SHARE := .12
const BODY_TRANSFER := .6
const RAIN_INTACT := 10
const RAIN_BROKEN := 4
const EXPOSE_WINDOW := 1.2
const TRACK_TIME := .55

static func setup(boss: Dictionary, maximum: float) -> void:
	boss["rift_max"] = maximum * HP_SHARE
	boss["rift_hp"] = maximum * HP_SHARE
	boss["rift_selected"] = false
	boss["rift_track"] = 0.0
	boss["rift_aim_used"] = false

static func available(boss: Dictionary) -> bool:
	return not boss.is_empty() and boss.has("rift_hp")

static func point(boss: Dictionary) -> Vector2:
	return Vector2(boss.pos) + Vector2(.32, .12) * float(boss.radius)

static func hit_radius(boss: Dictionary) -> float:
	return maxf(30.0,float(boss.radius)*.4)

static func exposed(ctx: RefCounted, boss: Dictionary) -> bool:
	if ctx.stage!=0 or not available(boss) or float(boss.rift_hp)<=0 or bool(boss.get("rift_aim_used",false)) or not charging(ctx): return false
	var left: float=ctx.boss_skill_windup("meteor_rain")-float(ctx.skill.age)
	return left>0 and left<=EXPOSE_WINDOW

static func update_aim(ctx: RefCounted, boss: Dictionary, delta: float) -> bool:
	if ctx.stage!=0 or not available(boss): return false
	if not exposed(ctx,boss) or not ctx.city_aim_held or not bool(boss.rift_selected) or ctx.priority_id!=int(boss.id) or ctx.city_aim_point.distance_to(point(boss))>hit_radius(boss):
		boss["rift_track"]=0.0
		return false
	boss["rift_track"]=minf(TRACK_TIME,float(boss.get("rift_track",0.0))+delta)
	if float(boss.rift_track)<TRACK_TIME-.000001: return false
	boss["rift_track"]=0.0
	boss["rift_aim_used"]=true
	ctx.end_skill()
	ctx.boss_skill.emit("broken","meteor_rain",point(boss))
	return true

static func words(zh: String, en: String) -> String:
	if TranslationServer.get_locale().begins_with("zh"): return TranslationServer.translate(zh)
	var translated: String=TranslationServer.translate(zh)
	return en if translated==zh else translated

static func charging(ctx: RefCounted) -> bool:
	return not ctx.skill.is_empty() and str(ctx.skill.kind) == "meteor_rain" and str(ctx.skill.phase) == "windup"

static func damage(ctx: RefCounted, boss: Dictionary, amount: float) -> float:
	if not available(boss) or float(boss.rift_hp) <= 0.0:
		return amount
	var multiplier: float = 2.0 if charging(ctx) else 1.0
	# Overflow stays on the body. Breaking the part never deletes a large hit.
	var allocated: float = minf(amount, float(boss.rift_hp) / multiplier)
	boss.rift_hp = maxf(0.0, float(boss.rift_hp) - allocated * multiplier)
	if float(boss.rift_hp) <= .000001:
		boss.rift_hp = 0.0
		boss.rift_selected = false
		ctx.add_effect(point(boss), "boss_burst", 22.0, 0)
		if charging(ctx):
			ctx.end_skill()
			ctx.boss_skill.emit("broken", "meteor_rain", boss.pos)
		ctx.notice.emit(TranslationServer.translate("裂隙已封闭：陨石雨从 10 枚减为 4 枚"))
	return amount - allocated + allocated * BODY_TRANSFER

static func rain_count(boss: Dictionary) -> int:
	return RAIN_BROKEN if available(boss) and float(boss.rift_hp) <= 0.0 else RAIN_INTACT
