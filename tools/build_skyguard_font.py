from pathlib import Path
from urllib.request import urlretrieve
from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
root=Path(__file__).resolve().parents[1]
source=root/'build/NotoSansSC-VF.ttf'
if not source.exists():
    urlretrieve('https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf',source)
target=root/'assets/fonts/SkyguardSC.ttf'
chars=set(TTFont(target).getBestCmap())
for folder in ['scripts','data','locales','assets/achievements']:
    for file in (root/folder).rglob('*'):
        if file.suffix in ['.gd','.tres','.json']:
            chars.update(ord(c) for c in file.read_text(encoding='utf-8') if c.isprintable())
options=subset.Options()
options.layout_features=['*']
options.name_IDs=['*']
font=subset.load_font(str(source),options)
source_coverage=set(font.getBestCmap())
font=instantiateVariableFont(font,{"wght":400},inplace=True)
subsetter=subset.Subsetter(options)
subsetter.populate(unicodes=chars)
subsetter.subset(font)
# Keep the shipped Skyguard line metrics while extending its glyph coverage.
font["hhea"].ascent=1000
font["hhea"].descent=-200
font["hhea"].lineGap=0
subset.save_font(font,str(target),options)
coverage=TTFont(target).getBestCmap()
assert all(c in coverage for c in chars if c>=32 and c in source_coverage)
assert all(c in coverage for c in chars if 0x4E00<=c<=0x9FFF)
print('SYSTEM_FALLBACK_GLYPHS',','.join(hex(c) for c in sorted(chars-source_coverage)))
print('FONT_COVERAGE_OK',len(coverage),'characters',target.stat().st_size,'bytes')
