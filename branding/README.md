# PaiPai branding

Twin gold coins (the doubled "Pai Pai") with a ₹ on the app's blue (`#3B82F6 → #1D4ED8`).

- `paipai_icon.svg` / `paipai_icon_512.png`: full icon (masters)
- `paipai_foreground.svg`, `paipai_monochrome.svg`: adaptive-icon layers
- `generate_icons.js`: the single source of the design. It writes every Android icon (`mipmap-*`, `mipmap-anydpi-v26/ic_launcher.xml`, `drawable/ic_launcher_background.xml`, `drawable/ic_stat_paipai.xml`) plus the masters above.

To change the logo, edit the colours or shapes in `generate_icons.js`, then run it:

```bash
npm i --no-save @resvg/resvg-js@2 && node branding/generate_icons.js
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
