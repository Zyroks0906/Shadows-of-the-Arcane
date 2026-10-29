# Prueba de juego — 29/10/2026

Jugado con un bot (`tools/playtest.gd`, escenarios `bot_*`) que pulsa las acciones reales
(moverse, atacar, habilidad, F, pociones) y apunta con el ratón. Capturas en esta carpeta.

## 1. Emboscada "Forgotten Cellar" (nivel 2) — `01_emboscada_forgotten_cellar.png`
| Clase | Duración | Vida perdida | Botín |
|---|---|---|---|
| Bárbaro (170 HP, antes del ajuste) | 8 s | 8 (5 %) | 8 monedas + 1 poción |
| Bárbaro (150 HP, 2 oleadas + élite) | 14 s | 19 (13 %) | 6 monedas + 1 poción |
| Arquero (90 HP) | 15 s | 52 (58 %) | 2 monedas |

- Era demasiado fácil: ahora 4 + 3 enemigos y la 2.ª oleada trae siempre un élite (`H` en los planos).
- El bárbaro rendía muy por encima del resto → 170 → 150 HP y daño ×1,5 → ×1,3.
- El bot ataca cuerpo a cuerpo hasta con el arquero, así que su número es pesimista.

## 2. Puzzles — `02_compuertas.png`, `03_eco_y_espejos.png`
- **Compuertas**: resuelto andando + F (palancas 2 y 3); cruza a la gruta y abre los cofres.
- **Espejos**: resuelto; el relicario se abre.
- **Eco**: el bot no lo resuelve (fallo del bot; tú lo superaste a mano).
- Fallo real encontrado: el área para pulsar F medía 8 px (había que pegarse al objeto).
  Ahora 14 px.

## 3. Tragaperras — `04_tragaperras.png`
- Una por nivel (nivel 1: junto a la salida del Demonio; 2 y 3: en la sala central).
- 10 / 15 / 20 monedas por tirada según el nivel.
- 12 tiradas con 200 monedas → 50. La casa gana, como debe ser; ¿te parece demasiado?

## 4. Agua — `05_agua_antes_despues.png`
- Agua profunda con shader propio (`shaders/water.gdshader`).
- Charcos (`shaders/shallow_water.gdshader`): orilla irregular y suelo visible.
- Al andar por ellos: chapoteo (`assets/audio/sfx/water/`) y ondas.
- Las tiras de una casilla son ahora charcos de 2-3 casillas.

## 5. Mejoras (perks)
- "Might" y "Fury" no afectaban al arquero → arreglado.
- Valores más altos para que se noten: Fury, Swiftness, Might, Arcana y Focus.
- Al elegir una mejora sale su efecto sobre el personaje, p. ej. "+10% ATTACK SPEED (NOW 20)".
- Hay un test por mejora que mide el efecto real.

## Preguntas para ti
1. ¿La emboscada se siente bien ahora o la quieres más dura (miniboss)?
2. ¿Ajusto la tragaperras para que pierda menos dinero?
3. ¿Te gustan los charcos o los prefieres menos opacos?

## Ronda 2 (tras tus comentarios) — `07_…png`, `08_…png`
- Tragaperras: ahora en salas que se exploran (nv1 bóveda de runas, nv2 Slime Pools, nv3 Barracks).
  Rodillos con 3 filas enteras y flechas de línea de premio. ~1 de cada 9 tiradas sale trío.
- Charcos rehechos: mancha orgánica (no casillas), borde de película fina y centro más profundo.
  Ralentizan más (60 % de velocidad) y solo en la parte mojada.
- El agua de los canales de la Sala de Compuertas ya usa el shader nuevo.
- Aura de salida centrada en la escalera del Demonio y también en la trampilla.
- Proyectiles enemigos: pixel art nuevo para agua, viento y tierra (`tools/gen_bolts.py`),
  y los enemigos usan el mismo arte que el jugador para fuego, hielo y electro. Sin partículas cuadradas.
- Botones de habilidad: ranuras de piedra con remaches dorados, glifo grabado, sombra de recarga
  y placa de latón con la tecla (`tools/gen_hud_art.py`).

## Ronda 3 — `09_ronda3_mago_y_ultis.png`
- Definitivas de área (ventisca del mago, meteorito del nigromante) caen sobre el enemigo visible
  más cercano; la del arquero también exige línea de visión. Test `ult_aim`: con la mirilla
  apuntando al lado contrario, las tres dan en el enemigo.
- E del mago: ayuda de apuntado, radio algo mayor, nunca sale hacia atrás pegado a un muro;
  sprite nuevo de agujas de hielo (`tools/gen_frost_spike.py`) y grieta de escarcha en el suelo.

## Ronda 4 — `10_…`, `11_…` (todas las clases), `12_ronda4_arreglos.png`
- E del mago rehecha como ráfaga helada en abanico (referencia: Frostgnaw de Kaeya): nace 10 px
  delante del mago, vetas de hielo, esquirlas, nube de escarcha; congela a los cercanos.
- Tajos físicos (bárbaro) en gris acero sin colores; el caballero en dorado de un solo color.
  Todos los tajos nacen delante del personaje, no en su cuerpo.
- Explosiones del salto del bárbaro, terremoto del clérigo y final del samurái reducidas a escala.
- HUD: las ranuras se rellenan del color de la habilidad de abajo arriba al recargar.
- Pendiente de tu decisión (láminas 10 y 11): la furia del bárbaro (Q) apenas se ve, la E del
  asesino (shuriken) es pequeña y los ataques básicos del arquero no salen en la captura.

## Ronda 5 — `13_ronda5_golpes_furia_meteorito.png`
- Golpe al suelo (`CombatFX.ground_slam`): rotura de losa en colores de la piedra (fisuras que se
  estrechan y ramifican, borde iluminado, trozos sueltos, hoyo), polvo en motas redondas, sonido
  nuevo grave (`tools/gen_slam.py`). Sin anillos ni efecto de lava. Clérigo: nace donde pega el puño.
- Furia del bárbaro: tinte rojo + resplandor rojo aditivo de su propia silueta detrás de él
  (`_RageGlow`). Quitadas las llamas y las volutas.
- Partículas genéricas (`CombatFX.burst`, 65 usos): ya no son cuadrados planos; estelas para las
  rápidas y motas redondas que se encogen para las lentas.
- Definitivas más largas: Aegis 8→11 s, tornado del arquero 2,2→3,6 s, ventisca 3→4,5 s.
- Meteorito: deja el suelo ardiendo 6 s (`burning_ground.gd`); quien entra o se queda, arde.
- Pendiente: siguen saliendo cuadraditos verdes al golpear slimes (otro sistema de partículas).
