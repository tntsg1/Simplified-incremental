# Audio

**Designed sound effects** in `sfx/` (weapons, hits, destruction, rewards, interface) are built by `tools/sfx_design.py` from recordings in the **Sonniss GDC Game Audio Bundles** (2015–2026): layered, filtered, compressed and loudness-normalised for Skyguard. Licence: royalty free, commercial use, no attribution required; the raw library files are not redistributed (they live outside the repository in `G:/audio_library`). https://sonniss.com/gameaudiogdc

The former Kenney fire/impact/crunch explosions and the earlier procedural `clean_*` effects are retired. They are excluded from the Windows package; their attribution is retained below.

Kenney, **Sci-fi Sounds**, 70-sound original pack, selected unchanged .ogg files.

- Source: https://kenney.nl/assets/sci-fi-sounds
- License: CC0 1.0 Universal, verified on the official asset page and included `KENNEY_LICENSE.txt`.

`boss_pulse`, `purchase`, `milestone`, `wave_clear`, `victory`, `failed`, `alarm` are original procedural compositions authored for Skyguard by `tools/compose_audio.py`. They contain no third-party music samples. The script records the notes, envelopes, stereo placement, echo and deterministic seed.

**Music**: `bgm_main.ogg` is cut from a track generated with Suno (prompt in `SUNO_PROMPTS.md`) by `tools/music_loop.py` into a beat-aligned seamless loop. Commercial release requires a version generated on a paid Suno plan.
