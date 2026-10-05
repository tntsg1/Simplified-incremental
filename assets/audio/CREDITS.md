# Audio

Production playback uses **original clean SFX** `clean_fire_0` … `clean_fire_5`, `clean_hit_rock`, `clean_hit_ship`, `clean_destroy`, `clean_elite`, `clean_boss`, authored by `tools/clean_audio.py`. Smooth envelopes, linear headroom and low-pass noise; no saturation or recorded samples.

The former Kenney fire/impact/crunch explosions are unused prototype reference files. They are excluded from the Windows package; their attribution is retained below.

Kenney, **Sci-fi Sounds**, 70-sound original pack, selected unchanged .ogg files.

- Source: https://kenney.nl/assets/sci-fi-sounds
- License: CC0 1.0 Universal, verified on the official asset page and included `KENNEY_LICENSE.txt`.

`music_0` … `music_5`, `boss_pulse`, `purchase`, `milestone`, `wave_clear`, `victory`, `failed`, `alarm` are original procedural compositions authored for Skyguard by `tools/compose_audio.py`. They contain no third-party music samples. The script records the notes, envelopes, stereo placement, echo and deterministic seed.
