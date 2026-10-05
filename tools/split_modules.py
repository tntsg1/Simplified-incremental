"""One-time extraction of the already-tested economy/campaign methods.

The coordinator keeps authoritative serializable state. Modules receive it as an
argument, so no RefCounted reference cycle or duplicate state is introduced.
"""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
path = root / 'scripts/combat.gd'
text = path.read_text(encoding='utf-8')
fields = set(re.findall(r'^var (\w+)', text, re.M))
signals = set(re.findall(r'^signal (\w+)', text, re.M))
methods = set(re.findall(r'^func (\w+)', text, re.M))
names = fields | signals | methods
groups = {
    'Growth': ('growth.gd', ['damage_multiplier','launcher_count','shot_interval',
        'salvo_packets','shot_damage','coverage','crit_chance','crit_multiplier',
        'nominal_dps','upgrade_cost','buy_upgrade','automation_available',
        'buy_automation','buy_weapon']),
    'Campaign': ('campaign.gd', ['start_new','start_wave','start_boss',
        'finish_boss','fail_stage','retry','progress'])}
pattern = re.compile(r'^func (\w+)\((.*?)\) -> (\w+):\n(.*?)(?=^func |\Z)', re.M | re.S)
tokens = re.compile(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|#[^\n]*|(?<![.\w])\b\w+\b')
for module, (filename, wanted) in groups.items():
    extracted = []
    def extract(match):
        name, args, result, body = match.groups()
        if name not in wanted:
            return match.group(0)
        converted = tokens.sub(lambda m: 'ctx.'+m[0] if m[0] in names else m[0], body)
        extracted.append(f'static func {name}(ctx: RefCounted{", " if args else ""}{args}) -> {result}:\n{converted}')
        arg_names = re.findall(r'(\w+)\s*:', args)
        call = f'{module}.{name}(self'+''.join(', '+a for a in arg_names)+')'
        return f'func {name}({args}) -> {result}:\n\t'+('return ' if result!='void' else '')+call+'\n\n'
    text = pattern.sub(extract, text)
    if extracted:
        (root/'scripts'/filename).write_text('extends RefCounted\n\n'+'\n'.join(extracted),encoding='utf-8')
        text = text.replace('const Catalog =',f'const {module} = preload("res://scripts/{filename}")\nconst Catalog =',1)
path.write_text(text,encoding='utf-8')
