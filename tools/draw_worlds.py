"""Original vector worlds; projected land, soft atmosphere and directional light."""
from pathlib import Path
out=Path(__file__).resolve().parents[1]/'assets/worlds'
out.mkdir(exist_ok=True)
defs='''<defs><radialGradient id="o" cx="32%" cy="27%" r="75%"><stop stop-color="#287ea1"/><stop offset=".58" stop-color="#16465e"/><stop offset="1" stop-color="#071524"/></radialGradient><radialGradient id="air"><stop offset=".83" stop-color="#6fdae7" stop-opacity="0"/><stop offset=".93" stop-color="#60cede" stop-opacity=".3"/><stop offset="1" stop-color="#6cbed8" stop-opacity="0"/></radialGradient><linearGradient id="night"><stop offset=".30" stop-color="#010812" stop-opacity="0"/><stop offset="1" stop-color="#010812" stop-opacity=".86"/></linearGradient><clipPath id="c"><circle cx="128" cy="128" r="112"/></clipPath></defs>'''
earth='''<circle cx="128" cy="128" r="128" fill="url(#air)"/><circle cx="128" cy="128" r="112" fill="url(#o)"/><g clip-path="url(#c)"><g fill="#527d72" stroke="#709387" stroke-width=".8"><path d="M35 48L51 35 77 30 96 42 112 47 108 58 91 62 98 74 84 90 64 94 65 108 81 115 76 131 62 129 57 112 48 106 42 85 30 75Z"/><path d="M77 132L97 132 114 148 115 170 101 181 96 201 80 213 75 188 65 168 64 148Z"/><path d="M143 36L170 30 205 41 225 59 241 83 218 84 208 94 192 89 175 102 162 95 161 82 151 84 142 67 127 61Z"/><path d="M146 87L161 89 180 109 176 129 159 150 155 169 142 171 127 151 120 126 126 104Z"/><path d="M187 141L203 147 213 163 207 174 193 167Z"/><path d="M193 184L220 180 235 199 217 216 196 211 180 199Z"/><path d="M17 222Q120 202 243 224L252 250 9 250Z" fill="#c5d7ce"/></g><g fill="none" stroke="#c4e1e3" stroke-opacity=".33" stroke-width="4"><path d="M12 71Q61 54 105 71T228 65"/><path d="M20 110Q71 96 97 107T183 105"/><path d="M50 191Q91 177 129 188T238 187"/><path d="M161 47Q180 63 219 55"/></g><g fill="#dfc287">'''
for x,y in [(74,81),(83,84),(91,73),(147,73),(151,80),(157,81),(174,95),(187,86),(203,100),(142,126),(87,155),(103,150),(204,198)]:
 earth+=f'<circle cx="{x}" cy="{y}" r="1.1"/>'
earth+='</g><circle cx="128" cy="128" r="112" fill="url(#night)"/></g><path d="M32 69A112 112 0 0 1 181 28" stroke="#b5e2e6" stroke-opacity=".65" stroke-width="1.5" fill="none"/>'
(out/'earth.svg').write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">{defs}{earth}</svg>',encoding='utf-8')
for name,colors in [('rocky',['#c79269','#705044','#261e23']),('sun',['#fff1bd','#edb551','#b94e24'])]:
 s=f'<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256"><defs><radialGradient id="s" cx="36%" cy="29%" r="72%">'+''.join(f'<stop offset="{i/2}" stop-color="{c}"/>' for i,c in enumerate(colors))+'</radialGradient><clipPath id="c"><circle cx="128" cy="128" r="112"/></clipPath></defs><circle cx="128" cy="128" r="112" fill="url(#s)"/><g clip-path="url(#c)" fill="none" stroke="#fff0d2" stroke-opacity=".12">'
 for i in range(14):
  s+=f'<path d="M5 {20+i*17}Q70 {i*19} 129 {30+i*16}T252 {25+i*16}" stroke-width="{3+i%4}"/>'
 s+='</g></svg>'
 (out/f'{name}.svg').write_text(s,encoding='utf-8')
print('3 original worlds')
