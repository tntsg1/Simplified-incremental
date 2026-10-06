extends Resource

@export var key: String = ""
@export var title: String = ""
@export var base_cost: float = 20.0
@export var cost_growth: float = 1.18
# Retired upgrades stay in saves but are never offered or bought.
@export var retired: bool = false
@export var unlock_stage: int = 0
@export var description: String = ""
