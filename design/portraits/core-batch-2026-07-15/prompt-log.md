# Core Portrait Prompt Log

## Global style stem {#global_style}

Use this stem for every generation call before adding the character-specific section.

```text
Use case: stylized-concept
Asset type: tactical RPG in-game character portrait master
Primary request: create a high-resolution bust or half-body portrait for a grim low-fantasy tactics game, designed to crop cleanly to a readable 96x96 in-game portrait
Subject: one adult character from the HBO-style Game of Thrones adaptation, recognizable from the TV version while still feeling like premium game portrait art rather than a photo still
Style/medium: hybrid live-action-recognizable likeness + painterly tactical RPG portrait rendering, mature, solemn, low-fantasy, grounded medieval materials, no cartoon stylization
Composition/framing: bust or half-body, face large in frame, shoulders visible, slight 3/4 angle allowed, clean silhouette, eyes readable after aggressive downscale, no hands near the face
Lighting/mood: dramatic but controlled key light, restrained contrast, strong facial planes, readable materials, war-torn atmosphere, not glossy poster lighting
Background: very simple soft-focus background with low detail only, color-field or subtle environmental haze that supports the character and never competes with the face
Constraints: one subject only; no text; no watermark; no logo; no frame; no exaggerated fantasy magic; no abstract icon look; preserve age, hair, beard, and social rank cues; the face must remain the first read at 96x96
Avoid: anime, chibi, flat-shaded mobile icon, caricature, celebrity photo shoot, modern fashion, extra people, busy battle tableau, tiny face, over-rendered jewelry, oversaturated colors, soft blurry eyes, smeared facial features
```

## Naming + review rules

- Save only the selected master image for each character into `design/portraits/core-batch-2026-07-15/masters/`.
- Use filenames `<character>_master_v1.png`.
- After export, record one line under the character heading with:
  - selected master filename
  - why it was chosen
  - crop note in one sentence
- Final runtime export must replace the existing file with the exact same filename in `game/冰与火/assets/units/`.

## Character prompts

### Ned Stark {#ned_stark}

```text
Character addendum: Ned Stark, middle-aged northern lord, dark brown hair, trimmed beard, long weathered face, solemn honest eyes, restrained authority, cold grey-blue palette, fur-lined northern cloak, dark leather and iron details, wind-worn skin, honor without theatrical heroism. Emphasize northern austerity, fatigue, and quiet resolve. Keep the likeness clearly closer to the TV adaptation than to generic fantasy art. Avoid making him too young, too glamorous, or too triumphant.
```

Expected master path: `design/portraits/core-batch-2026-07-15/masters/ned_stark_master_v1.png`
Expected runtime export: `game/冰与火/assets/units/ned_stark_portrait.png`

### Rhaegar Targaryen {#rhaegar_targaryen}

```text
Character addendum: Rhaegar Targaryen, noble tragic prince, pale skin, silver-blond hair, elegant but battle-worn, introspective gaze, red-black-gold palette, refined prince-warrior armor, melancholy and fatalism rather than flamboyant fantasy glamour. Make him recognizable as a TV-adaptation Targaryen prince, regal and sorrowful, with subtle dragon-court luxury restrained by wartime gravity. Avoid elf-like prettiness, romance-cover posing, or overly ornate fantasy excess.
```

Expected master path: `design/portraits/core-batch-2026-07-15/masters/rhaegar_targaryen_master_v1.png`
Expected runtime export: `game/冰与火/assets/units/rhaegar_targaryen_portrait.png`

### Robert Baratheon {#robert_baratheon}

```text
Character addendum: Robert Baratheon in his warrior-king prime leaning toward early wear, broad powerful frame, black hair, heavy beard, broken-nose roughness, warm brown-gold palette, stag-lord authority, brute force and charisma with visible excess and fatigue. Armor should feel practical and weighty, not ceremonial cosplay. Avoid making him a generic strongman or a tidy polished king portrait.
```

Expected master path: `design/portraits/core-batch-2026-07-15/masters/robert_baratheon_master_v1.png`
Expected runtime export: `game/冰与火/assets/units/robert_baratheon_portrait.png`

### Howland Reed {#howland_reed}

```text
Character addendum: Howland Reed, compact marshland scout-lord, alert watchful eyes, lean face, practical dark hair, low-profile green-brown palette, damp leather and swamp-ranger textures, intelligence and survival instinct more important than brute force. He should feel smaller and quieter than Ned or Robert, but sharper and harder to surprise. Avoid boyishness, generic peasant styling, or faceless background-soldier energy.
```

Expected master path: `design/portraits/core-batch-2026-07-15/masters/howland_reed_master_v1.png`
Expected runtime export: `game/冰与火/assets/units/howland_reed_portrait.png`

### Arthur Dayne {#arthur_dayne}

```text
Character addendum: Ser Arthur Dayne, legendary royal knight, pale dignified face, silver-white and soft steel palette, immaculate but battle-capable plate, sacred order without overt religious iconography, poised and deadly. The portrait should sell legendary purity and supreme discipline, not generic holy-warrior fantasy. Avoid exaggerated halos, giant fantasy pauldrons, or overly decorative church imagery.
```

Expected master path: `design/portraits/core-batch-2026-07-15/masters/arthur_dayne_master_v1.png`
Expected runtime export: `game/冰与火/assets/units/arthur_dayne_portrait.png`

### Jaime Lannister {#jaime_lannister}

```text
Character addendum: Jaime Lannister as a dangerous young elite knight, handsome but not soft, golden hair, aristocratic confidence, amused contempt in the eyes, warm gold-crimson palette, polished lion-court armor, dangerous charm over vanity. Make him feel fast, privileged, and lethal. Avoid turning him into a delicate pretty-boy or a generic faceless noble.
```

Expected master path: `design/portraits/core-batch-2026-07-15/masters/jaime_lannister_master_v1.png`
Expected runtime export: `game/冰与火/assets/units/jaime_lannister_portrait.png`

### Royal Guard Captain {#royal_guard_captain}

```text
Character addendum: royal guard captain, elite crown enforcer, hard authoritarian presence, cold steel palette with restrained royal accents, rigid posture, disciplined helmet or partial helm design that still leaves enough face visibility for 96x96 readability, intimidating but still human. Distinguish him from rank-and-file soldiers through heavier authority and cleaner elite armor lines. Avoid full-face obscuration or anonymous infantry blandness.
```

Expected master path: `design/portraits/core-batch-2026-07-15/masters/royal_guard_captain_master_v1.png`
Expected runtime export: `game/冰与火/assets/units/royal_guard_captain_portrait.png`

### Lannister Soldier {#lannister_soldier}

```text
Character addendum: Lannister foot soldier representative portrait, disciplined rank-and-file, red-gold palette, practical helmet and breastplate shapes, believable infantry equipment, stern expression, a little more templated than named characters but still grounded and specific. The result must read as a real Westerosi soldier rather than an abstract red icon. Avoid toy-soldier simplification, blank faceplates, and cartoon heraldry.
```

Expected master path: `design/portraits/core-batch-2026-07-15/masters/lannister_soldier_master_v1.png`
Expected runtime export: `game/冰与火/assets/units/lannister_soldier_portrait.png`
