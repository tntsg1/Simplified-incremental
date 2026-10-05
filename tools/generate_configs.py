"""Write the editable Godot weapon and upgrade resources. No external packages."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
def resource(name, script, fields):
    dest = ROOT / "data" / name
    dest.parent.mkdir(parents=True, exist_ok=True)
    rows = ['[gd_resource type="Resource" load_steps=2 format=3]',
            f'[ext_resource type="Script" path="res://data/{script}_spec.gd" id="1"]',
            '[resource]', 'script=ExtResource("1")']
    for key, value in fields.items():
        text = value if key == "color" else json.dumps(value, ensure_ascii=False)
        rows.append(f'{key}={text}')
    dest.write_text('\n'.join(rows)+'\n', encoding='utf-8')

names = ['导弹发射井','轨道炮','行星炮阵列','恒星炮','类星体炮','宇宙炮']
roles = ['高频拦截 / 蜂群弹头','重弹贯穿 / 轨道齐射','区域清除 / 行星阵列','长程穿透 / 恒星光矛','多域覆盖 / 类星体网络','全域扫掠 / 宇宙共振']
intervals = [1.2,3.6,1.8,4.8,6.0,8.0]
damage = [1.0,1.65,1.275,5.28,10.25,21.2]
coverage = [1,2,5,10,24,60]
colors = ['Color(0.35,0.88,0.76,1)','Color(0.35,0.72,1,1)','Color(1,0.75,0.35,1)','Color(0.72,0.5,1,1)','Color(0.95,0.48,0.7,1)','Color(0.7,0.88,1,1)']
for i in range(6):
    resource(f'weapons/{i}.tres','weapon',dict(title=names[i],role=roles[i],interval=intervals[i],damage_multiplier=damage[i],coverage=coverage[i],color=colors[i],beam=i>=2))
rows = [
    ('damage','弹头伤害',20,0,'每级伤害 +15%。Lv.10 / 25 / 50，伤害翻倍；高阶弹头提高群落覆盖。'),
    ('speed','拦截速度',15,0,'每级弹速 +8%。能量武器更快完成扫描与锁定；弹道最高 4,400 m/s。'),
    ('reload','装填效率',30,0,'每级射速 +10%。每十级发射器翻倍，增加齐射规模。'),
    ('crit','能量暴击',80,1,'每级暴击率 +2%，最高 50%；每二十五级提高暴击倍率。'),
    ('area','火力范围',120,2,'每级增加 18% 基础覆盖；Lv.10 群落爆裂使覆盖额外 +30%，Lv.25 区域轰击额外 +25%。'),
    ('pierce','贯穿能力',180,3,'每级覆盖 +25%；溢出火力继续命中邻近敌人。'),
    ('targets','多重锁定',260,4,'每级齐射伤害 +25%、覆盖 +30%，增加弹头与攻击束。')]
for key,title,cost,stage,description in rows:
    resource(f'upgrades/{key}.tres','upgrade',dict(key=key,title=title,base_cost=cost,unlock_stage=stage,description=description))
