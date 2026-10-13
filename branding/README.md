# PaiPai branding

Twin lowercase **p** (the doubled "Pai Pai") with a gold dot, on the app's blue (`#2563EB`). The back p is light
blue and cut away around the front one. The letter is Fredoka SemiBold (SIL OFL), outlined to a path, so nothing
depends on the font being installed. The wordmark is "paipai." in the same face, with the dot in gold.

- `paipai_icon.svg` / `paipai_icon_512.png`: full icon (masters, whole 108 grid; launchers show the middle 72)
- `paipai_foreground.svg`, `paipai_monochrome.svg`: adaptive-icon layers
- `paipai_status_96.png`: the white status-bar icon
- `generate_icons.js`: the single source of the design. It writes every Android icon (`mipmap-*`, `mipmap-anydpi-v26/ic_launcher.xml`, `drawable/ic_launcher_background.xml`, `drawable-*/ic_stat_paipai.png`) plus the masters above. The status-bar icon is a PNG per density, not a vector, because the gap between the letters is a mask

To change the logo, edit the colours or positions in `generate_icons.js`, then run it:

```bash
npm i --no-save @resvg/resvg-js@2 && node branding/generate_icons.js
```

To outline another letter (for example for a wordmark):

```python
# pip install fonttools; Fredoka[wdth,wght].ttf from github.com/google/fonts/tree/main/ofl/fredoka
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from fontTools.pens.svgPathPen import SVGPathPen
font = instancer.instantiateVariableFont(TTFont('Fredoka[wdth,wght].ttf'), {'wght': 600, 'wdth': 100})
glyphs = font.getGlyphSet()
pen = SVGPathPen(glyphs); glyphs[font.getBestCmap()[ord('p')]].draw(pen)
print(pen.getCommands())   # font units, 1000/em, y up from the baseline
```

## App font (Roboto Flex)

`assets/fonts/` holds static cuts of the Roboto Flex variable font (SIL OFL), made with fontTools
because Flutter's `FontWeight` doesn't drive a variable font's `wght` axis:

```python
# pip install fonttools; RobotoFlex.ttf from github.com/google/fonts/tree/main/ofl/robotoflex
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
axes = {a.axisTag: a.defaultValue for a in TTFont('RobotoFlex.ttf')['fvar'].axes}
for name, (wght, opsz) in {'RobotoFlex-Regular': (400, 14), 'RobotoFlex-Medium': (500, 14),
        'RobotoFlex-SemiBold': (600, 14), 'RobotoFlex-Bold': (700, 14),
        'RobotoFlexDisplay-SemiBold': (600, 48), 'RobotoFlexDisplay-Bold': (700, 48)}.items():
    instancer.instantiateVariableFont(TTFont('RobotoFlex.ttf'), {**axes, 'wght': wght, 'opsz': opsz}).save(f'{name}.ttf')
```
