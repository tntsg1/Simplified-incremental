extends RefCounted
# Per converted installation, never a global weapon or attack-type setting.
const BURST_GAP := .12
const MAX_PENDING := 100
var triples: Array[int] = [0,0,0,0,0,0,0,0,0,0]
var pending: Array[Dictionary] = []

func reset() -> void:
	triples.fill(0)
	pending.clear()

func valid(ctx: RefCounted, chapter: int, slot: int) -> bool:
	return chapter == 0 and ctx.stage == 0 and slot >= 0 and slot < ctx.BODIES[chapter].size() and ctx.body_converted_at(chapter,slot)

func count(chapter: int, slot: int) -> int:
	return 3 if (triples[chapter] & (1 << slot)) != 0 else 1

func configure(ctx: RefCounted, chapter: int, slot: int, shots: int) -> bool:
	if not valid(ctx,chapter,slot) or shots not in [1,3]: return false
	if shots == 3:
		triples[chapter] |= 1 << slot
	else:
		triples[chapter] &= ~(1 << slot)
	return true

func enqueue(ctx: RefCounted, chapter: int, slot: int, target: int, beat: int) -> void:
	if not valid(ctx,chapter,slot) or count(chapter,slot) != 3 or pending.size() >= MAX_PENDING: return
	for shot in pending:
		if int(shot.chapter)==chapter and int(shot.slot)==slot: return
	pending.append({"chapter":chapter,"slot":slot,"target":target,"beat":beat,"left":2,"due":ctx.elapsed+BURST_GAP})

func advance(ctx: RefCounted) -> void:
	if pending.is_empty(): return
	var lanes: Array[Dictionary] = []
	var lanes_ready := false
	# Reverse iteration keeps removal safe; each installation has at most one salvo.
	for i in range(pending.size()-1,-1,-1):
		var shot: Dictionary = pending[i]
		if float(shot.due) > ctx.elapsed + .000001: continue
		if not valid(ctx,int(shot.chapter),int(shot.slot)):
			pending.remove_at(i)
			continue
		if not lanes_ready:
			lanes = ctx.turret_lanes()
			lanes_ready = true
		while int(shot.left)>0 and float(shot.due)<=ctx.elapsed+.000001:
			var target: Dictionary = ctx.find_enemy(int(shot.target))
			if target.is_empty():
				for candidate in lanes:
					if not bool(candidate.dead):
						target=candidate
						break
			if target.is_empty():
				shot.left=0
				break
			ctx.fire_body_once(int(shot.chapter),int(shot.slot),target,lanes,int(shot.beat))
			shot.left = int(shot.left)-1
			shot.due = float(shot.due)+BURST_GAP
		if int(shot.left)<=0: pending.remove_at(i)

func snapshot() -> Dictionary:
	return {"triples":triples.duplicate(),"pending":pending.duplicate(true)}

func accepts(ctx: RefCounted, data: Variant, saved_stage: int, saved_time: float) -> bool:
	if not data is Dictionary or not data.get("triples") is Array or data.triples.size()!=ctx.STAGE_COUNT or not data.get("pending") is Array or data.pending.size()>MAX_PENDING: return false
	for chapter in range(ctx.STAGE_COUNT):
		if not data.triples[chapter] is float and not data.triples[chapter] is int: return false
		if not is_finite(float(data.triples[chapter])): return false
		var mask: int = int(data.triples[chapter])
		if (chapter>0 and mask!=0) or float(mask) != float(data.triples[chapter]) or mask<0 or mask >= (1 << ctx.BODIES[chapter].size()): return false
	var installations: Dictionary = {}
	for shot in data.pending:
		if not shot is Dictionary: return false
		for key in ["chapter","slot","target","beat","left"]:
			if not shot.has(key) or (not shot[key] is float and not shot[key] is int): return false
			if not is_finite(float(shot[key])) or float(shot[key])!=int(shot[key]): return false
		var chapter: int = int(shot.chapter)
		var slot: int = int(shot.slot)
		if chapter!=0 or saved_stage!=0 or slot<0 or slot>=ctx.BODIES[chapter].size() or int(shot.left) not in [1,2] or int(shot.target)<0 or int(shot.beat)<0: return false
		if not shot.has("due") or not is_finite(float(shot.due)) or float(shot.due)<saved_time-.1 or float(shot.due)>saved_time+BURST_GAP*2+.1: return false
		var key: String = "%d:%d" % [chapter,slot]
		if installations.has(key): return false
		installations[key] = true
	return true

func restore(data: Dictionary) -> void:
	reset()
	if data.is_empty(): return
	for chapter in range(triples.size()): triples[chapter]=int(data.triples[chapter])
	for shot in data.pending: pending.append(shot.duplicate(true))
