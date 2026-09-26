# Store screenshots

Rendered from the real `TunerScreen` by `tool/store_screenshots/generate.sh`.
All images are opaque RGB PNGs at the exact pixel sizes the stores accept.

| Folder | Store slot | Size |
|---|---|---|
| `ios_iphone_6.9/` | App Store Connect → iPhone 6.9" display | 1320 × 2868 |
| `ios_iphone_6.5/` | App Store Connect → iPhone 6.5" display | 1284 × 2778 |
| `ios_ipad_13/` | App Store Connect → iPad 13" display | 2064 × 2752 |
| `android_phone/` | Play Console → Phone screenshots | 1080 × 1920 |

Each folder has one subfolder per locale (`en`, `zh_TW`), with five scenes in
upload order:

1. `01_maple_in_tune`: Maple, lever harp, A♭ in tune
2. `02_mahogany_flat`: Mahogany, E♭ reading flat
3. `03_spruce_reference`: Spruce, reference mode on C, reading sharp
4. `04_maple_themes`: settings sheet with the theme picker
5. `05_walnut_pedal_in_tune`: Walnut, pedal harp, E♭ in tune

## Regenerating

```bash
pip install pillow                        # once
tool/store_screenshots/generate.sh        # en + zh_TW, all devices
tool/store_screenshots/generate.sh de fr it zh   # other app locales
DEVICES=android_phone tool/store_screenshots/generate.sh en
```

Scenes, devices and status bars are defined in
`tool/store_screenshots/store_screenshots_test.dart`.
