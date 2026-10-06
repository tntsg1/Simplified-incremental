extends RefCounted

static func start_new(ctx: RefCounted, seed_value: int = 4262026) -> void:
	for effect in ctx.effects:
		ctx.effect_pool.append(effect)
	ctx.effects.clear()
	ctx.stage = 0
	ctx.wave = 1
	ctx.money = 0.0
	ctx.health = 100.0
	for key in ctx.levels:
		ctx.levels[key] = 0
	ctx.owned.assign([true, false, false, false, false, false])
	ctx.bodies.assign([0, 0, 0, 0, 0, 0])
	ctx.weapon_damage.assign([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	ctx.automation = false
	ctx.paused = false
	ctx.manual_held = false
	ctx.elapsed = 0.0
	ctx.kills = 0
	ctx.attempts = 0
	ctx.stage_bosses = 0
	ctx.boss_spawned = 0
	ctx.serial = 0
	ctx.rng.seed = seed_value
	ctx.start_wave()

static func advance_phase(ctx: RefCounted) -> bool:
	if ctx.mode=="intermission":
		if ctx.mode_time>=3.0:
			if ctx.wave<10:
				ctx.wave+=1
				ctx.start_wave()
			else:
				ctx.start_boss()
		return true
	if ctx.mode=="transition":
		if ctx.mode_time>=ctx.transition_length:
			ctx.stage+=1
			ctx.wave=1
			ctx.start_wave()
			ctx.stage_entered.emit()
		return true
	return false


static func start_wave(ctx: RefCounted) -> void:
	ctx.clear_battle()
	ctx.mode = "wave"
	ctx.mode_time = 0.0
	ctx.wave_elapsed = 0.0
	ctx.health = 100.0
	ctx.wave_total = int(ctx.stage_data().wave_members[ctx.wave - 1]) * int(ctx.stage_data().count_multiplier)*ctx.wave_density()*(ctx.WAVE_SCALE if ctx.stage > 0 else 1)
	ctx.spawn_left = ctx.wave_total
	ctx.wave_killed = 0
	ctx.spawn_clock = 0.25
	ctx.surge_spawned = 0
	for i in range(6):
		ctx.cooldowns[i] = 0.0
	ctx.checkpoint.emit()


static func start_boss(ctx: RefCounted) -> void:
	ctx.clear_battle()
	ctx.mode = "boss"
	ctx.mode_time = 0.0
	ctx.wave_elapsed = 0.0
	ctx.boss_spawned += 1
	ctx.boss_remaining = float(ctx.stage_data().boss_window)
	ctx.serial += 1
	var e: Dictionary = ctx.enemy_pool.pop_back() if not ctx.enemy_pool.is_empty() else {}
	e.clear()
	var hp: float = ctx.boss_max_hp()
	var origin := Vector2(500.0, 52.0)
	var end: Vector2 = Vector2(500.0, 525.0) if ctx.stage == 0 else Vector2(500.0, 225.0)
	e.merge({"id": ctx.serial, "pos": origin, "start": origin, "end": end, "age": 0.0, "lifetime": float(ctx.stage_data().boss_window), "members": 1, "initial_members": 1, "unit_hp": hp, "hp": hp, "kind": ctx.stage_data().boss_kind, "elite": true, "seed": 995 + ctx.stage * 17, "reserved": 0.0, "radius": 68.0 + ctx.stage * 6.0, "boss": true, "dead": false})
	ctx.enemies.append(e)
	ctx.notice.emit("巨型威胁接近 · " + ctx.stage_data().boss_title)
	ctx.checkpoint.emit()


static func finish_boss(ctx: RefCounted) -> void:
	ctx.money += float(ctx.stage_data().boss_reward) * ctx.reward_scale()
	ctx.stage_bosses += 1
	ctx.clear_battle()
	ctx.health = 100.0
	ctx.mode_time = 0.0
	if ctx.stage == 5:
		ctx.mode = "victory"
		ctx.notice.emit("灾变核心已消散 · 天穹防线完成")
	else:
		ctx.transition_from = ctx.stage
		ctx.mode = "transition"
		ctx.notice.emit("尺度跃迁 · 下一道防线：" + ctx.catalog.stages[ctx.stage + 1].title)
	ctx.checkpoint.emit()


static func fail_stage(ctx: RefCounted) -> void:
	ctx.mode = "failed"
	ctx.manual_held = false
	ctx.attempts += 1
	ctx.notice.emit("防线突破 · 资金、升级和武器全部保留")
	ctx.checkpoint.emit()


static func retry(ctx: RefCounted) -> void:
	ctx.wave = 1
	ctx.paused = false
	ctx.start_wave()


static func progress(ctx: RefCounted) -> float:
	if ctx.mode == "boss":
		return 1.0
	var completed: float = ctx.wave_total - ctx.spawn_left
	return clampf(completed / maxi(1, ctx.wave_total), 0.0, 1.0)

