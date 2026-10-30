# Hoja de ruta — próxima versión

Acordado con Alejandro tras la lluvia de ideas (29/10/2026). Decisiones: progresión entre
partidas con almas, minimapa + mapa con TAB, reliquias con algunas sinergias, empezar por
la fase 1.

## Fase 1 — Acabado rápido
- [ ] Exportar el juego como `.exe` (plantillas de exportación de Godot 4.6.2) y publicarlo para
      los testers; `actualizar_y_jugar.bat` descarga la última versión compilada.
- [x] Tutorial integrado en la primera sala: 5 piedras talladas (moverse, atacar, esquivar,
      bloquear/parry, habilidades), placa con la tecla real del jugador, se guarda al terminar
      (`scripts/world/tutorial_stone.gd`, `playtest tutorial`).

## Fase 2 — Reliquias y mercader
- [x] 12 reliquias con efecto real (`scripts/global/relics.gd`): Ascua, Colmillo de lobo, Anillo de
      tormenta, Marca del cazador, Última resistencia, Cañón de cristal, Piedra de sangre, Cáliz rojo,
      Dado trucado, Corazón de piedra, Talones de escarcha, Pluma de fénix. Iconos en el HUD con descripción.
- [x] 4 sinergias escondidas: Plasma, Depredador alfa, Festín sanguíneo, Glaciar.
- [x] Origen: todos los jefes, cofres sellados (35 %) y el mercader ("Curio").
- [ ] Más reliquias (rebote de proyectiles, estela al esquivar…) y elegir entre 2 al matar un jefe.
- [x] Mercader en cada nivel: pociones y una perk al azar, precios por nivel (`scripts/world/merchant.gd`).
- [ ] Mercader: "cambiar las mejoras ofrecidas" (reroll).

## Fase 3 — Enemigos y élites
- [x] Arquetipos (sprites de LuizMelo, CC0; base `SheetEnemy`):
      Escudero = esqueleto con escudo (`Shieldbearer`: bloquea de frente, gira despacio),
      Embestidor = goblin (`Charger`: carril de flechas rojas y carga; contra un muro queda aturdido),
      Invocador = mago oscuro (`Summoner`: guarda distancia y abre grietas de ojos voladores, `Eyeling`),
      Escupidor = seta (`Spitter`: lanza esporas que dejan un charco tóxico, `AcidPool`).
- [x] Élites nuevas: Fantasmal (se desvanece y los golpes la atraviesan) y Elemental (solo las
      reacciones le hacen daño completo). La Vengativa ya existía como "Volátil".
- [x] Icono del elemento sobre cada enemigo (ya existía: `ElementBadge`).
- [ ] Animaciones de ataque propias para el goblin cargando (usa la de correr acelerada).

## Fase 4 — Exploración
- [ ] Minimapa en la esquina + mapa completo con TAB; salas descubiertas al pisarlas; cofres y
      puzzles marcados.
- [ ] Paredes agrietadas con salas secretas.
- [ ] Altares de elección (p. ej. -20 % vida máxima por una reliquia).
- [ ] Salas variantes al azar entre partidas.

## Fase 5 — Sonido
- [ ] Pasos según superficie (piedra, agua, hueso).
- [ ] Ambiente por nivel (goteo, viento…).
- [ ] Música de jefe al empezar el combate.

## Progresión entre partidas (transversal)
- [ ] Almas: se ganan en la partida y se conservan al morir.
- [ ] Desbloqueos permanentes pequeños, reliquias nuevas en el botín, salas nuevas.
