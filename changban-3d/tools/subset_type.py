"""Rebuild the two OFL fonts using full upstream SC OTFs supplied on the CLI."""
from pathlib import Path
import sys

from fontTools import subset
from fontTools.ttLib import TTFont

root = Path(__file__).resolve().parents[1]
characters = "".join(chr(i) for i in range(32, 127)) + "←→◇—–／"
for script in sorted(root.glob("*.gd")):
    characters += script.read_text(encoding="utf-8")

for style, source in zip(("sans", "serif"), sys.argv[1:], strict=True):
    font = TTFont(source)
    options = subset.Options()
    options.name_IDs = ["*"]
    options.name_languages = ["*"]
    options.recalc_bounds = True
    worker = subset.Subsetter(options=options)
    worker.populate(text=characters)
    worker.subset(font)
    for name in font["name"].names:
        if name.nameID in (1, 4, 6):
            family = "Longdan Field " + style.title()
            name.string = (family.replace(" ", "") if name.nameID == 6 else family).encode(name.getEncoding())
    font.save(root / "art" / "ui" / f"longdan-{style}.otf")
