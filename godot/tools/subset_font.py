"""Bundle the open-source Chinese font glyphs used by this game."""
from pathlib import Path
import json
from fontTools import subset
from fontTools.ttLib import TTFont

project = Path(__file__).resolve().parents[1]
original = project.parent / '.qa' / 'NotoSansSC-original.otf'
font_path = project / 'assets' / 'fonts' / 'NotoSansSC-Regular.otf'
if not original.exists():
    import urllib.request
    original.parent.mkdir(exist_ok=True)
    urllib.request.urlretrieve('https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/SubsetOTF/SC/NotoSansSC-Regular.otf', original)
text = ''.join(chr(i) for i in range(32, 127)) + '✓○◆…→× ·：，。！？ / 0123456789'
for directory, pattern in [('scripts','*.gd'), ('data','*.json')]:
    for path in (project / directory).glob(pattern):
        text += path.read_text(encoding='utf-8')
options = subset.Options()
options.name_IDs = ['*']; options.name_languages = ['*']; options.recalc_bounds = True
font = TTFont(original)
subsetter = subset.Subsetter(options=options)
subsetter.populate(text=text)
subsetter.subset(font)
# The subset has its own family name; retain the upstream OFL file and attribution.
for entry in font['name'].names:
    if entry.nameID in (1, 4, 6):
        entry.string = ('Longdan Game Sans' if entry.nameID != 6 else 'LongdanGameSans').encode(entry.getEncoding())
font.save(font_path)
print('Chinese game font:', font_path.stat().st_size, 'bytes;', len(set(text)), 'used characters')
