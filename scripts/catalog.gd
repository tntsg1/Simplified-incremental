extends RefCounted

const Stage = preload("res://data/stage_spec.gd")
const Weapon = preload("res://data/weapon_spec.gd")
const Upgrade = preload("res://data/upgrade_spec.gd")
const WAVES: Array[int] = [1, 2, 3, 5, 8, 12, 18, 27, 40, 60]
var stages: Array[Resource] = [preload("res://data/city.tres"), preload("res://data/earth.tres"), preload("res://data/solar.tres"), preload("res://data/galaxy.tres"), preload("res://data/cluster.tres"), preload("res://data/cosmos.tres")]
var weapons: Array[Resource] = [preload("res://data/weapons/0.tres"),preload("res://data/weapons/1.tres"),preload("res://data/weapons/2.tres"),preload("res://data/weapons/3.tres"),preload("res://data/weapons/4.tres"),preload("res://data/weapons/5.tres")]
var upgrades: Array[Resource] = [preload("res://data/upgrades/damage.tres"),preload("res://data/upgrades/speed.tres"),preload("res://data/upgrades/reload.tres"),preload("res://data/upgrades/crit.tres"),preload("res://data/upgrades/area.tres"),preload("res://data/upgrades/pierce.tres"),preload("res://data/upgrades/targets.tres")]

static func number(value: float) -> String:
	if value < 1000.0:
		return "%.0f" % value
	var units: Array[String] = ["K", "M", "B", "T", "Qa", "Qi"]
	var v: float = value
	for unit in units:
		v /= 1000.0
		if v < 1000.0:
			return "%.2f%s" % [v, unit]
	var exponent: int=int(floor(log(value)/log(10.0)))
	return "%.2f×10^%d" %[value/pow(10.0,exponent),exponent]
