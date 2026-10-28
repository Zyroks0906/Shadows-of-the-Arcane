# Shadows of the Arcane — Documento de traspaso

> **Para la IA que retome este proyecto:** lee este documento entero antes de tocar nada.
> Recoge el estado real del código, todo lo que el usuario (Alejandro) ha pedido y criticado
> tras jugar, y un plan priorizado. Las críticas del usuario son el criterio de "terminado":
> una tarea no está hecha hasta que el usuario lo vería bien **jugando**, no solo porque compile
> o pasen los tests.

---

## 0. Contexto en 30 segundos

- Juego 2D top-down de mazmorras en **Godot 4.6** (GDScript), proyecto académico de DAM
  (Alejandro + un compañero). Ruta: `E:\Shadows-of-the-Arcane`.
- Godot está en `E:\INSTALLERS\Godot_v4.6.2-stable_win64.exe` (y `..._console.exe` para
  headless). No está en el PATH.
- Rama de trabajo: **`feat/combat-overhaul`** (creada desde `feat/alejandro`). Hay muchos
  cambios **sin commitear**; no hagas commit sin que el usuario lo pida.
- El usuario quiere calidad "de juego de verdad": lógica humana, equilibrio, animaciones y
  efectos pulidos, niveles con diseño intencional. Pide que se investigue en juegos de
  referencia (sobre todo **The Binding of Isaac**) y se decida con criterio propio.
- **Muy importante:** el trabajo anterior se hizo solo con código y renders headless, sin
  jugar. Muchos de los fallos de abajo solo se ven jugando. Si tienes **computer use**
  (Claude Desktop), úsalo: abre Godot, juega, haz capturas y verifica cada cambio a mano.

---

## 1. Qué se hizo en la sesión anterior (estado actual)

### Combate (funciona, pero el equilibrio es malo — ver sección 2)
- `scripts/combat/reactions.gd`: cada reacción elemental tiene efecto real (Sobrecarga
  explota en área + empuje, Superconducción reduce resistencia, Electrocargado hace daño en
  el tiempo y salta a enemigos cercanos, Congelado paraliza y el siguiente golpe hace
  *Shatter*, Torbellino propaga el elemento, Cristalizar suelta un fragmento que da escudo).
- `scripts/global/combat_fx.gd` (autoload `CombatFX`): hit-stop, temblor de cámara, números
  de daño, partículas, ondas, rayos, destello blanco. El hit-stop usa un *token* para
  restaurar `Engine.time_scale` (antes se quedaba atascado en cámara lenta: **no** volver a
  comparar timestamps).
- `base_character.gd`: knockback, `terrain_speed_mult`, `external_push` (viento),
  reducción de resistencia, colores de números de daño.
- `player.gd`: invulnerabilidad tras golpe, escudo, regeneración de maná por Sabiduría,
  daño cuerpo a cuerpo = `7 + strength`, el especial cuesta 8 de maná, las clases sin
  elemento atacan con el elemento que tengan imbuido.
- `enemy.gd`: congelación, destello, knockback, el elemento imbuido caduca (7 s) y los
  enemigos elementales recuperan el suyo (3 s).
- Clérigo arreglado (no compilaba) y ahora es Geo.
- Shader `assets/shaders/elemental_tint.gdshader`: añadidos `flash_amount` y `freeze_amount`.

### Contenido nuevo
- Enemigos: **Wisp** (`wisp.gd`, sprites generados por `tools/generate_wisp.py`), **Orco**
  (`orc.gd`, arte que ya existía sin usar). Jefes: **Guardian** (`guardian.gd`, mapa 2) y
  **Warden** (`warden.gd`, hereda de `golem.gd`, mapa 3).
- Niveles generados desde ASCII: `tools/levels/whispering_caverns.txt` → `level_2.tscn`,
  `tools/levels/skyhold_ruins.txt` → `level_3.tscn`, con `tools/level_builder.gd`.
- Entorno: `element_zone.gd` (agua que imbuye Hydro y frena; viento que empuja e imbuye
  Anemo), `arcane_crystal.gd` (cristal que pulsa un elemento), `level_exit.gd` (portal),
  `level_ambience.gd` (oscuridad con `CanvasModulate` + luz que sigue al jugador = el
  "modo focus" que al usuario le gustó, partículas, música, título del nivel).
- Tilesets recoloreados en `assets/tilesets/generated/` (`tools/recolor_tileset.py`).
- Progresión: el Demon del mapa 1 desbloquea el mapa 2; el portal del mapa 2 desbloquea el 3
  (antes `unlock_level` no se llamaba nunca).

### Herramientas y tests
- Regenerar niveles y escenas de enemigos:
  `Godot_v4.6.2-stable_win64_console.exe --headless --path . res://tools/level_builder.tscn`
- Previsualizar un nivel a PNG (necesita ventana, no headless):
  `Godot_v4.6.2-stable_win64_console.exe --path . res://tools/render_level.tscn -- res://scenes/levels/level_2.tscn salida.png 1 1`
  (args: escena, png, zoom, 1=con ambientación, [x y ancho alto] recorte opcional en px).
- Tests headless: `res://tests/combat_test.tscn` y `res://tests/level_smoke.tscn`
  (`--headless --path . <escena>`; imprimen `RESULT failures=N`).
- Partida automatizada con ventana (mide velocidades, alcance, cadencia, viento y guarda
  capturas): `Godot_v4.6.2-stable_win64_console.exe --path . res://tools/playtest.tscn -- <carpeta_salida> knight archer mage`
- **Trampas conocidas:** con `--script` no existen los autoloads → ejecuta como escena.
  Tras crear un `class_name` nuevo, ejecuta una vez `--headless --editor --quit` para
  regenerar la caché de clases. Los avisos `invalid UID` de los .tscn son antiguos e inocuos.

---

## 1b. Sesión del 26-10-2026 (sin commitear)

- **P1 hecho** (pendiente de opinión del usuario): velocidades, aceleración, ataques por
  fases con impacto en el frame real (`Player._start_action`), apuntado a la mirilla
  (`scripts/combat/aim.gd`, `scripts/ui/crosshair.gd`), carga del arco (`archer.gd`), orbes
  de Mago/Nigromante (`ElementBolt.from_player`), viento 45 px/s + 10 % en contra,
  armadura del jugador en porcentaje (`Player._mitigate`), roles de clase.
- **Correcciones tras el feedback 2:** escala por animación (`Player.anim_scale`, Bárbaro
  ×1,34 en las hojas "360"), Clérigo 0,35 → 0,09 (salía 4 veces más grande), Clérigo a
  puñetazos, sonidos por clase (`sfx_swing/hit/cast/impact/hurt`, nada de `Retro/` en
  combate), antorchas reales en niveles 2 y 3 (`level_builder._torch_frames`).
- Herramientas nuevas: `tools/playtest.tscn` (tokens `lineup`, `torches`, `wind` o clases)
  y `tools/measure_sprites.tscn` (altura opaca de cada frame de cada clase).
- **Audio nuevo** (`assets/audio/sfx2/`, catálogo generado en `scripts/global/sound_bank.gd`,
  créditos en `docs/CREDITS.md`): `AudioManager.play_bank(cat)` / `play_bank_at(cat, pos)`
  eligen variante sin repetir. Cada clase tiene perfil (`snd_swing/hit/cast/impact/block`,
  `voice` m1–m4/f1 + `voice_pitch`); cada especie de enemigo `Enemy.SOUND_SETS`. Los clips
  `Human/man_*.wav` eran un hombre leyendo números: no usarlos nunca.
- **Enemigos:** `body_scale` por especie (esqueleto 0,6, rata 0,4, slime 0,55, murciélago
  0,55, orco 1,25, wisp 0,65), ataque con aviso rojo + dirección fijada + arco corto
  (`Enemy._melee_attack`), separación entre ellos, aturdimiento (`apply_stun`), icono de
  elemento sobre la cabeza (`ElementBadge`) en vez de las auras de pinchos, sangre pequeña y
  direccional (`CombatFX.blood`). El shader `elemental_tint` ahora respeta `modulate`.
- **P2 hecho:** controles nuevos en `project.godot` (clic izq. atacar, clic der. bloquear,
  Q/E especial, Espacio esquivar, F, C/V, Esc, H ayuda; mando incluido), `PlayerGuard`
  (aguante, bloqueo frontal, parry que aturde y devuelve proyectiles, ruptura de guardia),
  esquiva con estelas e invulnerabilidad, `CombatHud` (barra de guardia, indicadores,
  panel de controles). Teclas de depuración: F4 modo dios, F6 rellenar.
- **P3 hecho:** cofres con apertura de 0,6 s y botín que sale en arco (`collectible.pop_out`),
  rótulo estilo Isaac (`ItemBanner`), música amortiguada (paso bajo) en pausa.
- **P5 hecho:** planos en `tools/levels/design_levels.py` (genera los .txt). Salas de combate
  (`ArenaRoom`: `R`, `=`, `E`, recompensas `k`/`g`/`r`), progresión con llaves como el
  mapa 1. La erosión ya no toca los pasillos (`_near_corridor`).
- **Habilidades (E/Q, estilo Genshin):** E con recarga, Q con energía (golpes, muertes,
  poción de maná en clases físicas). Cada clase en su script (`_do_skill`, `_do_burst`);
  utilidades en `player.gd` (`_aoe`, `_skill_dash`, `_buff`, `_target_point`) y zonas en
  `scripts/combat/ability_zone.gd`. Maná solo para Mago/Nigromante (orbes básicos).
  Efectos de pinchos one-shot: `CombatFX.spike/spike_ring` (assets/VFX/Elemental_Spikes).
- **Progresión:** autoload `Progression` (XP de `XpOrb`, niveles, mejoras por rareza,
  copia al empezar mapa y restauración al morir), `PerkPicker` (3 cartas). Tests usan
  `Progression.auto_pick = true`.
- **Extras de mundo:** cofres sellados con monedas (`chest.coin_cost`), transmutador
  (`Transmuter`, 'T' en los planos), recompensas de jefe ocultas (`BossReward`), trampilla
  trampa del Golem (`Trapdoor`). En el mapa 1 todo lo añade `scripts/levels/level1_extras.gd`
  (ojo: la raíz de level_1 está desplazada (-200,-14); usar posiciones globales).
- **Victoria:** botón NEXT MAP (`GameManager.MAPS`, `current_map`); el Demonio abre un portal.
- **HUD:** barras continuas con números, barra de XP y nivel, indicadores SPC/E/Q.
- **Atajos de desarrollo:** `-- class=barbarian map=2`, F4 modo dios, F6 rellenar.
- **Rondas 4 y 5 (28-10-2026):**
  - Mapa 1:
    - `level1_extras` encoge la decoración (no los personajes): grupos de tiles pasan a
      Sprite2D a ×0,62, anclados a la pared o al suelo, y las velas, antorchas y banderas
      se reducen.
    - Modo foco: oscuridad, luz del jugador, luces en antorchas y velas, y título
      "THE FORGOTTEN CRYPT".
    - La trampilla lleva a la Cripta (`scenes/levels/crypt.tscn`, generada con
      `fragment: true`); al limpiarla da una perk RARA o superior y una escalera de vuelta.
  - Equilibrio:
    - Slime lento a saltitos (velocidad 22), esqueleto normal (34) y murciélago rápido
      (66) con aleteo (`Enemy._move_rhythm`).
    - Vida de jefes: golem 450, guardián 600, warden 750 y demonio 900.
  - Parry más fácil pero no gratis: "!" y clic 0,15 s antes del golpe (`Enemy._parry_cue`),
    con una ventana base de 0,25 s.
  - Barra de jefe arriba (`scripts/ui/boss_bar.gd`): solo en combate y cerca del jefe, con
    nombre, estela de daño y números.
  - Maná: las clases físicas ni ven ni usan maná, y las pociones de maná ya no cargan la Q.
    El transmutador cobra 2 monedas por poción.
  - Nivel en medallón dorado junto a la vida; las perks se mantienen entre mapas y se
    reinician al elegir clase.
  - Pantalla de perks medieval (`perk_picker.gd`): cinta roja, cartas de pergamino con marco
    del metal de su rareza e icono 16×16 por perk. El arte se genera con
    `python tools/gen_ui_art.py` en `assets/ui/perks/`.
    - Las cartas van a escala ×3.
    - Fuentes: Jersey 15 para el texto de las cartas (nítida solo a 27 px o múltiplos) y
      Jacquarda Bastarda 9 para la cinta (nítida a 13, 26 y 39 px). No usar tamaños
      intermedios.
    - Brillo neón aditivo por rareza (`glow_*.png`): común y poco común sin brillo, rara
      suave, épica media y legendaria fuerte, con rayos (`rays.png`) y destellos.
  - Playtest: escenarios nuevos `level1`, `boss` (barra de jefe) y `perks` (todas las
    rarezas).
- **Ronda 6:**
  - Renombrado: `Map_1.tscn` → `level_1.tscn` y `map1_extras.gd` → `level1_extras.gd`; el
    botón de victoria dice "NEXT LEVEL".
  - `CombatFX.slash` se dibuja con triángulos: el polígono degenerado causaba el error
    "Invalid polygon data".
  - El título de nivel lleva una banda oscura detrás.
  - El aviso "resources still in use at exit" de los tests headless viene del driver de
    audio Dummy, que no libera la música; es inofensivo.
- **Pendiente:** minimapa, opción de asistencia de apuntado en Ajustes, pulido de las
  animaciones de ataque enemigas, modo infinito tipo Megabonk (idea futura) y YouTube
  (cuando el juego esté listo).

## 1c. Ronda 7 (28-10-2026) y CÓMO RETOMAR

**Retomar gastando poco:** lee solo esta sección y `CLAUDE.md`. Comprueba con:
`--headless --path . res://tests/combat_test.tscn` y `res://tests/level_smoke.tscn` (deben dar
`RESULT failures=0`). Para ver cosas: `tools/playtest.tscn -- <carpeta> <escenarios>`
(escenarios: lineup enemies guard chest level1 boss perks elites death victory torches wind
<clase> abil:<clase>). Tras crear un `class_name` o fuentes nuevas: `--headless --editor --quit`.

Hecho en la ronda 7:
- Cartas de perks:
  - Pixelify Sans a 22/33 px (tamaños exactos de su rejilla: 11, 22, 33).
  - Sin el contorno del tema global (`outline_size` 0), que engordaba las letras.
  - Diseño vertical con bandas fijas: `perk_picker.gd`, constantes `ICON_Y`, `NAME_Y`, ...,
    a juego con `tools/gen_ui_art.py`.
- Sombras en el suelo (2,5D): `scripts/world/ground_shadow.gd`.
  - Los personajes la llevan automáticamente desde `BaseCharacter._ready`.
  - Los voladores usan `shadow_hover`.
  - Objetos: la sombra se queda en el suelo mientras vuelan.
  - Proyectiles: `GroundShadow.attach_flying`.
- Élites: `scripts/entities/elite_affix.gd`.
  - Tipos: Swift, Hulking, Vampiric, Volatile, Warded y Gilded.
  - Probabilidad por nivel de 8/12/16 %.
  - Aura, placa con vida, cartel explicativo la primera vez, ×3 XP, monedas y a veces poción.
  - Los tests las desactivan con `EliteAffix.enabled = false`. `EliteAffix.forced` fuerza
    un tipo.
- Pantalla de muerte: `scripts/ui/death_screen.gd`, con el resumen de la partida
  (`Progression.stats`, `stat()`, `run_time_text()`), la build y TRY AGAIN / MAIN MENU.
- Escalas proporcionadas al héroe (unos 13,5 px; medir con `tools/measure_scale.tscn`):
  esqueleto 0,5, slime 0,4, murciélago 0,42, rata 0,36, wisp 0,55 y orco 1,1.
- Orbes de XP más pequeños.

- **Crisol del alquimista** (`scripts/world/transmuter.gd`, arte en
  `tools/gen_props_art.py` → `assets/sprites/props/transmuter.png`):
  - Si está dentro de una `ArenaRoom` queda enterrado y la sala trae 2 élites
    (`ArenaRoom.elite_spawns`); al limpiarla emerge.
  - Menú `Transmuter.TransmuteMenu` (1: maná → vida, 2: vida → maná, 2 monedas cada una).
  - La poción nueva sale disparada al suelo.
  - Ubicaciones: en la cripta del nivel 1 (ya no en el spawn) y en la arena 1 de los
    niveles 2 y 3.
- Playtest: escenarios `elites`, `death` y `crucible`.

Siguiente (ideas pendientes, por prioridad):
1. Probar a mano con el usuario (aún no ha jugado esta versión).
2. Minimapa y santuarios de riesgo y recompensa (por ejemplo, pagar vida por una perk
   legendaria).
3. Desbloqueos entre partidas (clases o perks nuevas), semilla diaria y códice de
   enemigos.
4. Modo infinito tipo Megabonk en 3D pixel (proyecto aparte, el usuario quiere hacerlo
   bien y sin prisas): buscar assets 3D low-poly CC0 (Kenney, Quaternius, KayKit) y usar
   el shader de pixelado de Godot.

## 2. Feedback del usuario tras jugar (TODO esto es obligatorio)

Citas resumidas y la causa real encontrada en el código.

### 2.1 Controles confusos
- "No sé para qué sirven la Q y la E." → **Q / clic izquierdo = `attack_1`**,
  **E / clic derecho = `attack_2`** (ataque especial). C/V = pociones, F = interactuar,
  Esc = pausa, F3 = debug de colisiones. No hay ninguna ayuda en pantalla que lo explique.
- "El clic derecho gasta estamina y suena como un parry aunque no bloquee nada." → No existe
  parry: es el especial, que gasta **maná** y reproduce `sword_clash.wav` siempre.
  **Hay que rediseñarlo** (ver 3.2).

### 2.2 Ataques del jugador: sin lógica humana
- **Alcance absurdo:** `player._check_hit` usa un círculo de radio 50 px desplazado 35 px →
  golpea a ~85 px (especial ~115 px). "Un caballero con espada debería tener que pegarse."
- **Cadencia absurda:** `attack_lock_time = 0.1` → se puede atacar 10 veces por segundo.
  No hay *wind-up*, ni ventana activa, ni recuperación.
- **Todos atacan hacia donde se mueven** (`last_direction`), así que si huyes hacia la
  izquierda no puedes golpear a un enemigo que tienes a la derecha. Es especialmente grave en
  el Arquero. El usuario pide **mirilla como cursor y aim assist** que ayude sin acertar el
  100 % de las veces (diseño en P1.3). El Arquero además debe **cargar** la flecha, porque
  tensar el arco lleva tiempo.
- El daño de golpe no está sincronizado con el frame de impacto de la animación.

### 2.3 Movimiento demasiado rápido
- Velocidades de clase entre 70 y 140 px/s, y el `player.gd` base usa 135. "Podía ir contra la
  corriente de viento como si nada". El viento empuja 70 px/s, que no compensa.

### 2.4 Equilibrio de clases inexistente
- El usuario quiere **roles claros**: los cuerpo a cuerpo (Caballero, Bárbaro, Samurái)
  necesitan más vida, resistencia y capacidad de bloqueo porque tienen que acercarse; los de
  distancia (Mago, Arquero/"elfo") son frágiles pero mantienen la distancia; algunos "50/50".
  No tomes sus ejemplos como valores absolutos: investiga y decide.

### 2.5 Bloqueo y parry (petición explícita)
- Mantener **clic derecho = bloquear**. Barra de **aguante de bloqueo** por clase (el
  Caballero con escudo, mucha; el elfo, poca). Cada golpe bloqueado gasta aguante; si se
  vacía, el bloqueo se rompe, los golpes pasan y hay *cooldown*.
- **Parry** al levantar el bloqueo justo a tiempo.
- **El sonido de bloqueo/parry solo suena si de verdad bloqueas un golpe**, nunca al pulsar
  al aire ("como levantar el escudo y bloquear el aire").

### 2.6 Cofres y objetos
- Abres un cofre → el objeto aparece → se recoge solo al instante. "Es tan rápido que ni
  sabes qué cogiste." (`chest.gd` muestra `hidden_item` de golpe y `collectible.gd`
  autorrecoge al solaparse).
- Debe haber animación de apertura legible, el objeto debe **salir** del cofre, quedarse en
  el suelo, y al cogerlo mostrar **qué es** (nombre + descripción, estilo Isaac).

### 2.7 Pausa
- Al pulsar Esc el juego se pausa pero **la música sigue** (MusicManager usa
  `PROCESS_MODE_ALWAYS`). Pausar la música (o atenuarla) al pausar.

### 2.8 Animaciones y efectos feos o rotos
- **Antorchas (fallo de la sesión anterior):** `level_builder._decorate_wall_face` usa los
  tiles `(0,9)` y `(1,9)` del tileset como si fueran dos frames, pero son **dos antorchas
  distintas** → "el palo se parte y resucita". Usar las animaciones reales de
  `assets/tilesets/items and trap_animation/torch/` (`torch_1..4`, `side_torch_1..4`;
  `level_1` ya las usa bien) donde **solo se mueve la llama**.
- **Aura de los slimes elementales** (sobre todo Hydro): son los VFX "spike from ground" en
  bucle (`elemental_aura.gd` + nodos `Aura*` en `slime_base.tscn`). Se ven bugueados y feos.
- **Animaciones de ataque de los enemigos** poco pulidas; golpes por temporizador, no por
  frame.
- **Sangre** "dispersa, sin sentido" (`vfx_blood_hit.tscn` / `blood_hit_vfx.gd`).

### 2.9 Diseño de niveles (mapas 2 y 3)
- **Demasiado grandes para un personaje tan pequeño**, con salas enormes casi vacías
  ("una sala gigante con 3 pociones y 2 monedas"). Falta diseño de nivel profesional:
  cada sala debe tener un propósito y una densidad de contenido razonable.
- **Lo que sí gustó:** la identidad visual de cada mapa y el "modo focus" (oscuridad + luz
  alrededor del jugador), aunque en mapas tan grandes se pierde la orientación.

---

## 3. Plan de trabajo propuesto (por prioridad)

Los números son **valores iniciales razonados**, no verdades: ajústalos jugando. Se basan en
convenciones de juegos de acción top-down (Isaac, Hades, Enter the Gungeon, Soul Knight) y
en la escala del juego: tiles de 16 px, cámara con zoom 2 → a 1152×648 se ven unos
36×20 tiles (576×324 px), y los personajes miden unos 16–32 px.

### P1 — Sensación básica de combate y movimiento
1. **Velocidades** (px/s): Caballero 72, Bárbaro 76, Clérigo 78, Mago 80, Nigromante 80,
   Arquero 88, Samurái 92, Asesino 100. Arranque y frenada con aceleración breve
   (`move_toward`), no instantáneos.
2. **Ataques con fases** (*startup*, activo y recuperación), con el daño aplicado en el frame
   de impacto (`AnimatedSprite2D.frame_changed`) y una caja de golpe orientada en arco o
   rectángulo **delante** del personaje, no un círculo enorme.
   - Espada (Caballero, Samurái): alcance unos 22–26 px, arco de 100°, ciclo de unos 0,45 s.
   - Arma pesada (Bárbaro): unos 28 px, ciclo de unos 0,75 s, más daño y más empuje.
   - Dagas (Asesino): unos 18 px, ciclo de unos 0,3 s.
   - Mago y Nigromante: proyectil con lanzamiento de unos 0,35 s, cadencia de unos 0,6 s.
3. **Apuntado separado del movimiento + aim assist suave** (petición del usuario: "se fallan
   demasiados ataques porque atacas hacia donde corres"). Decisión recomendada:
   - **Para todas las clases, el ataque va hacia el cursor**, no hacia donde te mueves.
     Puedes huir hacia la izquierda y golpear o disparar a la derecha: es el apuntado
     independiente del movimiento de Enter the Gungeon, Hades o Isaac jugados con ratón.
     El personaje se gira hacia el cursor al atacar.
   - **Cursor de mirilla:** un sprite de cruz pixel art con `Input.set_custom_mouse_cursor`
     (o un nodo dibujado en un `CanvasLayer`), que se tiñe o se cierra cuando hay un enemigo
     dentro del alcance del arma.
   - **Aim assist suave, con un acierto aproximado del 70–80 %:** al atacar, busca enemigos
     vivos dentro de un **cono de unos ±25°** alrededor de la dirección de apuntado y
     dentro del alcance del arma. Elige el más cercano a la línea de apuntado (no el más
     cercano al jugador). Después **gira la dirección del ataque un 70–80 %** hacia él con
     `dir.slerp(to_enemy, 0.75)`, en lugar de clavarla al 100 %, para que sigas teniendo que
     apuntar. Proyectiles: desvío inicial igual más un leve guiado (≤ 60°/s, solo los primeros
     0,25 s), que se pueden esquivar. Cuerpo a cuerpo: el arco de golpe se orienta con la
     dirección asistida.
   - **Con mando:** el stick derecho apunta, el cono es mayor (±35°) y el giro más fuerte
     (0,85). Sin stick ni ratón movido, se apunta al enemigo más cercano dentro del alcance.
   - Opción en Ajustes: **Asistencia de apuntado: No / Baja (0,5) / Normal (0,75) / Alta (0,9)**.
   - Por qué no un sistema de "clic para fijar objetivo" como LoL: en un juego de acción en
     tiempo real quita control y habilidad. El cursor más la asistencia suave da precisión
     sin que el juego "juegue solo".
   - Test: con un enemigo a 20° de la mirilla, el ataque debe acertar; a 60°, no.
   - El **Arquero carga** la flecha manteniendo pulsado: a partir de 0,35 s el disparo es
     mínimo y hacia 0,9 s alcanza la carga completa (más daño y velocidad), con un indicador
     visual alrededor de la mirilla.
4. **Viento:** con las velocidades nuevas, empuje de unos 55 px/s y, además, penalizar
   moverse contra la corriente (multiplicar la velocidad según el producto escalar con la
   dirección del viento), de forma que remontarla cueste de verdad.
5. **Roles de clase** (vida / resistencia / aguante de bloqueo), como punto de partida:
   Caballero 150/12/100, Bárbaro 170/6/45, Samurái 115/8/55 con una ventana de parry
   mayor, Clérigo 110/8/60, Asesino 85/4/25 (a cambio, esquiva), Arquero 90/5/25,
   Mago 75/3/15 (barrera mágica), Nigromante 85/5/20.

### P2 — Controles, bloqueo y parry
- **Esquema propuesto:**
  - Clic izquierdo: atacar.
  - Clic derecho (mantener): bloquear.
  - Q y E: habilidades de clase (el especial actual pasa aquí, con *cooldown* visible).
  - C y V: pociones; F: interactuar; Esc: pausa.
  - Opcional: espacio para esquivar o rodar.
- **Bloqueo:** el bloqueo frontal reduce el daño a 0 o casi y consume aguante proporcional al
  golpe. El aguante se regenera tras 1 s sin bloquear. Si se agota, el bloqueo se rompe: 0,6 s
  de aturdimiento y 2 s sin poder bloquear. Mientras se bloquea el movimiento es más lento.
- **Parry:** los primeros unos 0,15 s tras levantar la guardia. No gasta aguante, el enemigo
  queda aturdido y hay chispa, hit-stop y sonido.
- **Los sonidos de bloqueo y de parry suenan solo al recibir un golpe de verdad.**
- Barra de aguante en el HUD y una **ayuda de controles** visible (primera vez o en la pausa).

### P3 — Cofres, objetos y pausa
- Apertura del cofre en unos 0,6 s. El objeto sale en un arco con rebote y aterriza en el
  suelo; solo se puede recoger tras unos 0,4 s y caminando por encima.
- Al recogerlo, un **banner** con nombre y descripción corta durante unos 2 s (como Isaac),
  más un sonido propio de cada tipo de objeto.
- Pausa: pausar la música (`stream_paused`) o bajarla con un filtro paso bajo, y retomarla al
  reanudar.

### P4 — Arte y efectos
- Antorchas con su animación real (2.8). Revisar en el juego que solo se mueva la llama.
- Sustituir las auras de spike de los slimes por un **icono de elemento sobre la cabeza**
  (como en Genshin) más un brillo o partículas suaves del color del elemento. Quitar los
  spikes en bucle.
- Enemigos: *wind-up* telegrafiado (destello o postura), golpe en el frame de impacto y
  recuperación. Revisar uno a uno Slime, Rata, Murciélago, Esqueleto, Orco, Wisp y jefes.
- Sangre: un estallido pequeño y direccional en el punto de impacto (unos 0,25 s), sin
  manchas dispersas.

### P5 — Rediseño de niveles 2 y 3 (estilo Isaac)
- **Salas de una pantalla o algo menos:** entre 13×9 y 22×13 tiles. Pasillos cortos. El área
  total de cada mapa debería quedar en la mitad o menos de la actual.
- **Cada sala con propósito:** encuentro de combate (3–6 enemigos combinados para provocar
  reacciones), tesoro, peligro o puzle de entorno (agua, cristales, viento), descanso,
  minijefe o jefe. Que no haya salas grandes vacías.
- **Puertas que se cierran** hasta limpiar la sala de combate (como Isaac), con una
  recompensa al limpiarla.
- Que el entorno se use de verdad: atraer enemigos al agua y rematar con Electro, cristales
  que castigan quedarse quieto, viento que obliga a elegir la ruta.
- **Orientación:** minimapa o salas reveladas, manteniendo el "modo focus".
- Los planos están en `tools/levels/*.txt` (la leyenda está al principio de
  `tools/level_builder.gd`). La erosión orgánica de la cueva se aplica en `_erode()`.

### P6 — Verificación (obligatoria por cada bloque)
1. `tests/combat_test.tscn` y `tests/level_smoke.tscn` en verde. Añade tests para el bloqueo,
   el parry y la carga del arco.
2. **Jugar de verdad** con al menos 3 clases (un cuerpo a cuerpo, el Arquero y el Mago) y
   comprobar cada punto de la sección 2. Si hay computer use, haz capturas y compáralas.
3. Enseñar el resultado al usuario y pedirle su opinión antes de pasar al siguiente bloque.

---

## 4. Archivos clave

| Área | Archivos |
|---|---|
| Jugador y clases | `scripts/entities/player.gd`, `scripts/entities/classes/*.gd`, `scripts/levels/player_spawner.gd` |
| Base de personaje | `scripts/entities/base_character.gd` |
| Enemigos | `scripts/entities/enemy.gd`, `scripts/entities/enemies/*.gd`, `scenes/entities/Enemies/*.tscn` |
| Elementos | `scripts/global/elemental_system.gd`, `scripts/combat/reactions.gd`, `scripts/vfx/elemental_aura.gd` |
| Efectos | `scripts/global/combat_fx.gd`, `scripts/vfx/blood_hit_vfx.gd`, `assets/shaders/elemental_tint.gdshader` |
| Objetos y cofres | `scripts/world/chest.gd`, `scripts/items/collectible.gd`, `scenes/world/*.tscn` |
| UI | `scripts/ui/hud_manager.gd`, `scripts/ui/pause_menu.gd`, `scripts/global/music_manager.gd` |
| Niveles | `scenes/levels/level_1.tscn` (hecho a mano), `tools/level_builder.gd`, `tools/levels/*.txt` |
| Entradas | `project.godot` → sección `[input]` |
