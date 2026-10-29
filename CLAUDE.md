# Shadows of the Arcane

Juego 2D top-down en Godot 4.6 (GDScript). Para empezar lee solo `docs/NEXT_SESSION.md` (lo
pendiente) y la sección 1c "CÓMO RETOMAR" de `docs/HANDOFF.md`. El resto de HANDOFF es
histórico: consúltalo con Grep cuando haga falta.

- Godot: `E:\INSTALLERS\Godot_v4.6.2-stable_win64.exe` (headless: `..._console.exe`).
- Tests: `--headless --path . res://tests/combat_test.tscn` y `res://tests/level_smoke.tscn`.
  Ejecútalos redirigiendo a un log y muestra solo `grep -E "RESULT|FAIL|SCRIPT ERROR"`.
- Ver el juego: `tools/playtest.tscn -- <carpeta> <escenarios>` (lista en HANDOFF 1c).
  Mira una sola captura, recortada o reducida con PIL si basta.
- Tras un `class_name` o recurso nuevo: `--headless --editor --quit` (las fuentes pueden
  necesitar dos pasadas).
- Los niveles 2 y 3 y la cripta se generan con `res://tools/level_builder.tscn` desde
  `tools/levels/*.txt` (los planos salen de `design_levels.py`).
- Skills del proyecto en `.claude/skills/` (Godot: input-handling, godot-ui, save-load,
  godot-code-review, ...). Las `spritecook-*` están desactivadas en `.claude/skills_disabled/`
  (SpriteCook es de pago); el arte se hace con herramientas gratuitas.
- El usuario valora la lógica "humana" y el pulido visual: escala respecto al héroe, letras
  finas y nítidas, espaciado. Verifica con capturas, no solo compilando.
- No hagas commit sin que el usuario lo pida. Habla en español.
