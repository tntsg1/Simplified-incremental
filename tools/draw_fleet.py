"""Original vector art: six readable silhouettes for hazards, fleets and guns."""
from pathlib import Path
import math
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/fleet'
OUT.mkdir(parents=True,exist_ok=True)

def svg(name,body,w=256,h=256):
    defs='''<defs><linearGradient id="h" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#b0c5d5"/><stop offset=".42" stop-color="#55728b"/><stop offset="1" stop-color="#172737"/></linearGradient><linearGradient id="d"><stop stop-color="#668294"/><stop offset="1" stop-color="#152937"/></linearGradient><radialGradient id="hot"><stop stop-color="#fff4c6"/><stop offset=".48" stop-color="#eca074"/><stop offset="1" stop-color="#8d3858"/></radialGradient><radialGradient id="cold"><stop stop-color="#badde8"/><stop offset=".6" stop-color="#528ba5"/><stop offset="1" stop-color="#19354b"/></radialGradient><radialGradient id="g"><stop stop-color="#defbff" stop-opacity=".9"/><stop offset="1" stop-color="#78b9ff" stop-opacity="0"/></radialGradient></defs>'''
    (OUT/(name+'.svg')).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{defs}{body}</svg>',encoding='utf-8')

def path(d,fill='url(#h)',stroke='#91b6ce',width=2):return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{width}" stroke-linejoin="round"/>'
def line(x1,y1,x2,y2,c='#7dcde6',w=2):return f'<path d="M{x1} {y1} {x2} {y2}" stroke="{c}" stroke-width="{w}"/>'
def circle(x,y,r,c,stroke='none',w=2):return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{c}" stroke="{stroke}" stroke-width="{w}"/>'
def rect(x,y,w,h,c,stroke='none'):return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="2" fill="{c}" stroke="{stroke}"/>'

svg('ship_0',path('M128 25 164 89 219 206 153 177 128 228 103 177 37 206 92 89Z')+path('M128 51 128 184','none','#d2e6f1',4)+path('M109 119 128 85 147 119 139 156 117 156Z','#b582ab')+line(54,184,107,156)+line(202,184,149,156)+circle(128,193,19,'url(#g)'))
svg('ship_1',path('M115 22 141 22 162 124 195 89 219 188 160 170 146 230 110 230 96 170 37 188 61 89 94 124Z')+rect(112,56,32,94,'#213445','#c4d6e0')+rect(122,64,12,74,'#d89aac')+path('M61 98 77 151 46 174M195 98 179 151 210 174','none','#b5cad6')+circle(99,185,12,'url(#g)')+circle(157,185,12,'url(#g)'))
svg('ship_2',path('M128 15 155 72 196 98 228 190 167 166 146 234 110 234 89 166 28 190 60 98 101 72Z')+path('M94 112 162 112 172 145 84 145Z','#a1878b','#d9c2c8')+rect(119,49,18,143,'#172c3c','#8bbdd4')+rect(124,64,8,77,'#e2a6a4')+''.join(rect(60+j*25,151,12,31,'#2a3c50','#6c889d') for j in range(6))+circle(112,209,14,'url(#g)')+circle(144,209,14,'url(#g)'))
svg('ship_3',path('M128 27 154 62 205 85 235 166 200 194 159 151 144 225 112 225 97 151 56 194 21 166 51 85 102 62Z')+path('M44 160 100 113 128 87 156 113 212 160 160 146 128 177 96 146Z','#334862','#a7b9d2')+circle(128,131,25,'#202942','#d5b0dc',3)+circle(128,131,12,'#cd9bd9')+line(128,45,128,104,'#baddf0',3)+''.join(line(62+j*27,103,74+j*21,139,'#90b5d8') for j in range(6))+circle(128,211,19,'url(#g)'))
svg('ship_4',path('M93 30 163 30 210 77 224 158 171 218 85 218 32 158 46 77Z')+path('M107 12 149 12 149 96 179 111 177 178 149 189 145 239 111 239 107 189 79 178 77 111 107 96Z','#284159','#b2c7d9')+circle(128,140,34,'#1a2d3f','#b899c9',3)+circle(128,140,17,'#b182bd')+''.join(rect(x,86,13,88,'#8192ad','#c1d1e1') for x in [46,66,177,197])+line(128,30,128,105,'#dfc7e0',3)+circle(87,211,18,'url(#g)')+circle(169,211,18,'url(#g)'))
svg('ship_5',path('M128 14 163 58 215 83 241 140 207 207 157 183 128 243 99 183 49 207 15 140 41 83 93 58Z','#20384e','#b1c9df',3)+circle(128,128,76,'none','#8fb6d2',10)+circle(128,128,60,'#17243d','#354d69',4)+''.join(path(f'M128 128 {128+math.cos(j*math.tau/6)*70:.1f} {128+math.sin(j*math.tau/6)*70:.1f}','none','#d1b2d7',6) for j in range(6))+circle(128,128,23,'#d3c4e8','#edf9ff',3)+circle(128,128,13,'#6877a0')+rect(121,24,14,43,'#c4dfe9')+rect(121,190,14,42,'#8faed2'))

svg('hazard_0',path('M112 22 165 31 215 83 227 145 198 207 141 234 80 215 29 165 35 93 70 49Z','url(#hot)','#dba58a',2)+''.join(circle(x,y,r,'#684953','#ba8b81') for x,y,r in [(89,99,22),(159,81,15),(146,167,29),(70,167,12)])+path('M80 43 102 81 121 118 141 139 163 210','none','#edbb8c',3))
svg('hazard_1',path('M120 16 188 52 223 116 205 197 152 237 69 218 23 160 41 78Z','url(#cold)','#b8d9e8',2)+path('M41 80 82 126 144 113 188 52M82 126 70 218M144 113 205 197','none','#9dc3d7',3)+''.join(circle(x,y,r,'#416376','#7095ac') for x,y,r in [(115,66,17),(157,156,25),(77,170,16)]))
svg('hazard_2',circle(128,128,99,'url(#hot)','#efbd87')+path('M55 76 102 46 159 62 206 107 171 164 115 206 58 173Z','#8b5261','#c88479')+path('M104 46 120 107 58 173M120 107 171 164M120 107 206 107','none','#fac995',4)+circle(84,103,15,'#624659')+circle(151,164,24,'#694650')+path('M28 160 58 145M211 70 237 107','none','#ebad83',5))
svg('hazard_3',path('M128 18 173 72 227 115 184 177 146 238 92 213 32 150 64 89Z','url(#cold)','#c1e7f0',3)+path('M128 18 143 120 227 115M143 120 146 238M143 120 32 150','none','#b9e8f0',4)+path('M64 89 94 123 143 120 92 213Z','#4784a2','#7dafc2')+path('M173 72 158 120 184 177 202 143Z','#c5e2e4','#9fc7d7'))
svg('hazard_4',circle(128,128,98,'url(#cold)','#bad5e0',3)+path('M37 106 Q122 75 211 101M30 139 Q128 172 224 145M42 185 Q129 199 194 181','none','#7ba8bc',6)+circle(91,80,17,'#3e6279','#9abbca')+circle(169,151,25,'#386078','#668ea2')+f'<ellipse cx="128" cy="130" rx="123" ry="32" fill="none" stroke="#b7b5ce" stroke-width="5" transform="rotate(-24 128 130)"/>')
svg('hazard_5',path('M127 16 152 80 219 40 190 111 241 137 174 163 197 231 133 194 86 240 86 168 16 145 81 117 50 51 107 84Z','#274254','#a7d6e8',3)+path('M128 57 162 106 195 131 159 153 126 198 98 156 59 137 100 112Z','#91bcca','#d6eef1')+path('M128 68 128 184M77 136 184 131','none','#f0fcff',5)+circle(128,131,18,'#d9f4f7'))

# Functional guns: consistent metallic hulls, very different working geometry.
pal=['#65e2c1','#62b9ef','#eec57c','#b795e5','#dda3c5','#b8dce9']
for i in range(6):
    c=pal[i]
    body=path('M23 74 49 33 190 33 223 62 207 91 48 95Z','url(#h)','#92afc2')
    body+=rect(29,72,164,19,'#263d51','#557c94')
    if i==0:
        body=path('M22 81 34 58 208 58 225 82 213 107 25 107Z','url(#h)','#9eb6c5')
        for j in range(5):
            body+=rect(54+j*25,16,12,55,'#b4c7cc','#607d8d')+path(f'M{54+j*25} 17 {60+j*25} 7 {66+j*25} 17Z',c,c)
        body+=rect(172,78,27,15,'#193547','#6a97a7')+line(177,85,193,85,c,3)
    elif i==1:
        body+=circle(68,62,29,'#456681','#9abace')+circle(68,62,16,'#253b56',c,3)
        body+=rect(76,40,156,9,'#93b2c2','#c3d7e0')+rect(76,72,156,9,'#93b2c2','#c3d7e0')+line(105,44,244,44,c,4)+line(105,77,244,77,c,4)
    elif i==2:
        body+=path('M52 25 128 5 193 26 168 50 112 39 60 50Z','#859caa','#c8d7df')+circle(126,57,26,'#334a59',c,4)+circle(126,57,12,c)+rect(151,52,87,12,'#597587','#b0cfdb')+line(152,58,250,58,c,4)
    elif i==3:
        body+=path('M74 16 154 17 189 45 187 78 157 109 76 111 51 86 51 41Z','#405469','#b4bdd1',3)+circle(118,64,36,'#25374c',c,5)+circle(118,64,23,'#c5b6de')+rect(146,48,92,28,'#516378','#b6c2d5')+line(167,62,254,62,c,8)
    elif i==4:
        body+=f'<ellipse cx="111" cy="62" rx="81" ry="45" fill="none" stroke="#a7b5c8" stroke-width="12"/>'+circle(111,62,29,'#4b3c62',c,4)+circle(111,62,16,c)+path('M37 15 68 25 68 99 37 111Z','#7a7494','#a7b5cc')+rect(162,46,79,31,'#655574','#b3adcc')+line(174,61,253,61,c,6)
    else:
        body+=f'<ellipse cx="117" cy="62" rx="83" ry="48" fill="none" stroke="#b2c9d8" stroke-width="12"/>'+circle(117,62,34,'#2d4962',c,4)+circle(117,62,20,'#c2e9f1')+''.join(line(117,62,117+math.cos(j*math.tau/6)*75,62+math.sin(j*math.tau/6)*41,'#7babc3',5) for j in range(6))+path('M154 47 230 47 251 62 230 77 154 77Z','#798fa6','#cbdeeb')+line(184,62,253,62,'#defcff',7)
    body+=''.join(rect(44+j*18,84,9,4,c) for j in range(7))
    svg(f'weapon_{i}',body,256,128)

svg('boss_ship',path('M128 8 155 40 207 47 236 86 237 167 203 211 156 215 128 246 100 215 53 211 19 167 20 86 49 47 101 40Z')+path('M72 69 184 69 204 101 204 167 174 193 82 193 52 167 52 101Z','#33465c','#9bb7cc',3)+circle(128,128,40,'#263046','#d3a5d1',4)+circle(128,128,21,'#c68cba')+''.join(rect(33+j*29,87,16,78,'#668299','#aebeca') for j in range(7))+''.join(circle(56+j*35,207,13,'url(#g)') for j in range(5))+line(128,17,128,85,'#e9d7e9',4))
print('vector fleet authored:',len(list(OUT.glob('*.svg'))))
