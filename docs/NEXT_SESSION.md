# Próxima sesión. Lee esto y HANDOFF §1c; nada más al empezar.

(Lo hecho el 28-10, sesión 2, está en HANDOFF §1c y en el historial de git.)

## Feedback del usuario tras jugar (28-10, tarde). Marca [x] lo que se termine.
### Bugs
- [x] J. Al volver al menú principal o cambiar de personaje se conservan monedas, llaves y
      pociones. Solo NEXT LEVEL conserva; salir al menú pierde la partida.
- [x] D. Perk picker: al spamear el clic se elige una carta sin querer. Ignorar clics los
      primeros ~0,6 s y exigir soltar el botón.
- [x] B. El combate del Golem empieza al pasar por el pasillo de arriba: debe empezar al
      entrar en la sala. Al huir a otra sala, la barra del jefe se va. El golem se queda
      atascado en el pasillo y bloquea el paso: rediseñar la entrada (rejas que se cierran,
      el golem no sale de su sala).
- [x] F. Monedas y objetos caen dentro de sólidos (cristales, etc.) y no se pueden coger:
      deben chocar o rebotar con todo lo que bloquea al jugador.
- [x] Settings: no debe haber scroll (ventana más alta). Pestañas AUDIO y CONTROLS dentro de
      la misma ventana: ahora CONTROLS se abre detrás o encima de Settings.
- [x] I. Tras la victoria, en la selección de mapas, botones para volver a la selección de
      personaje y al menú principal (aquí no hace falta salir del juego).
- [x] Cofres de la sala de la derecha del nivel 1 girados de lado; el botín debe salir
      delante del personaje.
### UI
- [x] C. "You Died" con la gótica cuesta leerlo: usar la misma letra que el resto (Pixelify).
      Revisar también la cinta de perks.
- [x] G. Crisol: botón visible "LEAVE" (además de Esc).
### Gameplay y balance
- [x] H. Mana: cada ataque del mago o nigromante cuesta (básico < E < Q), para que las
      pociones de maná sirvan.
- [x] N. Arquero E: durante la ráfaga los ataques normales hacen mucho más daño (3 → 10).
- [x] E. Props sólidos: jarrones, pilares y estructuras bloquean; huesos y calaveras se
      atraviesan con sonido de pisada.
- [x] K. Atacar arriba o abajo: el tajo y el personaje deben orientarse a la dirección real
      del ataque (no solo izquierda o derecha), en todas las clases.
- [~] M. Rediseño de habilidades (hecho: ninja con shurikens y clones; FALTA: repensar la E del caballero):
  - Caballero: la E (un dash) no tiene sentido teniendo esquiva.
  - Ninja/asesino: E = estrellas ninja (3 rápidas o una nube de 6); Q = clones de sombra
    (3 a 5, aleatorio) que distraen, tienen poquísima vida y hacen poco daño, y se
    deshacen en humo.
- [ ] L. Animaciones de habilidades (E y Q de todos) mucho más trabajadas: ahora parecen de
      principiante (el hielo del mago son 3 bolitas). La Q del caballero apenas se ve.
- [ ] O. Nivel 1, sala derecha (pinchos y 2 cofres): más grande, que el botín no se vea de
      lejos, mejores trampas y un PUZZLE tipo Genshin.
- [ ] P. Dar al usuario un resumen de lo que hace cada personaje (básico, E y Q).

### Feedback 2 (28-10, probando todas las clases). Investigar el carácter de cada clase.
- [x] Nigromante: la E no se entiende (parece un básico que empuja) → que QUEME: daño en el
      tiempo de ~10 % de la vida por tic. La Q (meteorito) gusta pero hay que mejorar la
      animación.
- [x] Samurái: la E no puede ser escudo ni dash. Mejor una ráfaga de varios tajos en cono
      (el rango del básico, en secuencia). La Q no se ve (tajos invisibles): que se vea.
      Identidad: mucho ataque, poca defensa, gran habilidad.
- [x] Caballero: la Q pasa a ser AEGIS como en Megabonk: 3-4 escudos que orbitan y dañan.
- [ ] Clérigo: la E (escudo) vale; la Q (empujón fuerte) vale.
- [ ] El escudo del cristal geo (hexágono) se ve pobre: mejorarlo.
- [x] Bárbaro:
  - La E tiene la misma animación que el básico: tiene que ser distinta.
  - La Q no se entiende y está desequilibrada (hace muchísimo daño). Propuesta: furia
    (más ataque y más velocidad de ataque, pero recibe un 5 % más de daño), con toques de
    God of War y mitología griega.
- [ ] Enemigos imbuidos de anemo en el nivel 1 sin motivo aparente: investigar.
- [x] Números de daño: el usuario no los ve (existen en `base_character`:
      `CombatFX.damage_number`). Revisar tamaño, capa y oscuridad.
- [ ] Al terminar: respuestas al usuario CORTAS y directas (qué cambió y qué falta).

### Hecho en la sesión 3 (28-10)
- Bolsa de la partida (`GameManager.reset_run`, `snapshot_bag`, `restore_bag`).
- Protección contra clics sin querer en las perks.
- Gótica fuera de los títulos.
- Crisol con botón LEAVE.
- Settings con pestañas AUDIO y CONTROLS y sin scroll.
- Jefes con línea de visión, correa y abandono del combate.
- Caída segura de objetos.
- Botones de vuelta en la selección de mapas.
- Coste de maná en E y Q.
- Ráfaga del arquero con daño ×3.
- El botín de los cofres sale hacia el jugador.
- Inclinación y estocada en los ataques cuerpo a cuerpo.
- Números de daño en una capa sin oscuridad.
- Nuevas habilidades:
  - Nigromante, Hellfire: quema (`scripts/combat/burn.gd`).
  - Samurái: Iaido Flurry y una Q visible.
  - Caballero: Aegis en órbita (`scripts/combat/aegis_orbit.gd`).
  - Bárbaro: Earthshaker (salto) y Spartan Rage (×1,3 velocidad, ×1,2 daño, +5 % daño
    recibido).
  - Ninja: Shuriken Volley (`scripts/combat/shuriken.gd`) y Shadow Clones
    (`scripts/combat/shadow_clone.gd`; `Enemy.player` ahora es `BaseCharacter`).
  - Mago: Glacial Path.

### Pendiente
- E (props sólidos y pisadas).
- L (pulir la Q del mago, el escudo geo y el clérigo).
- O (puzzle y sala derecha del nivel 1).
- E del caballero.
- Rejas en la sala del golem.
- Anemo en el nivel 1.

### Feedback 3 (28-10, tarde)
- [x] URGENTE: la sala del golem tiene que encerrarte (rejas al entrar, se abren al matarlo).
- [x] Portal: que no se coja automáticamente, sino con F. En el nivel 1, tras el jefe final,
      las escaleras de bajada llevan al siguiente nivel (con F).
- [x] Los pinchos también dañan a los enemigos (proporcional).
- [x] Tempest Arrow: auto-apunta al enemigo más cercano.
- [x] Clones del ninja: que se muevan y vayan a por los enemigos.
- [x] Quemadura: algo más de daño pero equilibrada (no proporcional sin tope en jefes).
- [x] Cofres del nivel 1 como los de los niveles 2 y 3: muchas monedas y un objeto
      (poción, llave o perk).
- [x] Jaula del puzzle: el cofre se sale de los barrotes. Ajustar el tamaño.
- [x] Primera sala del nivel 1: demasiados enemigos nada más empezar, y no sueltan
      monedas. Los enemigos normales deberían soltar alguna moneda.
- [x] Pasillo de flechas: se cruza andando sin daño. Rediseñarlo con baldosas de presión
      ocultas que disparan, ráfagas más seguidas, corriente de aire...
- [ ] Sala de los dos cofres: más grande, con otro puzzle distinto y mejor ambientada.
- [~] VFX (MUY IMPORTANTE; HECHA la primera pasada): todas las E y Q y los proyectiles de los magos se ven pobres y
      no están al nivel de los sprites de itch.io. Faltan efectos visibles en la E del
      samurái y en la E del mago; hay que mejorar Aegis, Blizzard y los proyectiles
      básicos. Plan: buscar packs de VFX pixel art de calidad (itch.io, licencia libre) y
      usarlos en lugar de dibujar a mano.

### Hecho en la sesión 3b
- Rejas del golem (`level1_extras._golem_gates`).
- Portal con F.
- Los pinchos dañan a los enemigos.
- Tempest Arrow automática.
- Clones que cazan.
- Quemadura ignora la armadura, con tope de 8 por tic en jefes.
- Cofres del nivel 1 con monedas y objeto.
- Jaula ajustada.
- Primera sala más tranquila.
- Monedas de enemigos normales (35 %; 70 % en los grandes).
- Suelo de baldosas en el pasillo de flechas (`scripts/world/pressure_plates.gd`).
- Props sólidos y huesos que crujen (`scripts/world/decor_physics.gd`).
- Escudo de cristal rediseñado.
- E del caballero: golpe de escudo sin dash.

### LO SIGUIENTE (por orden)
1. VFX profesionales (lo que más pide el usuario). Usar multi-search-engine para buscar
   packs de efectos pixel art gratuitos de itch.io (hielo, fuego, rayos, slashes,
   escudos, auras) y sustituir lo dibujado a mano en E y Q, proyectiles de magos, Aegis,
   Blizzard y tajos.
2. Sala de los cofres más grande, con otro puzzle (requiere pintar tiles en el nivel 1).
3. Opcional: en el nivel 1, las escaleras tras el jefe como salida en lugar del portal.

### VFX, sesión 3c
- **PVFX Foundry** (CC0, `assets/VFX/PVFX/`): `CombatFX.pvfx(name, pos, size, rot, tint, speed)`.
  - crescent-slash en todos los tajos.
  - frost-nova en Glacial Path y Blizzard.
  - earth-rupture y landing-dust en el bárbaro y el clérigo.
  - cinder-orchid y ember-jet en Hellfire.
  - warm-explosion y solar-shrapnel en el meteorito.
  - arcane-parry en el golpe de escudo y en los escudos de Aegis.
  - radiant-heal en el clérigo.
  - resonant-break y splash-crown en la Q del samurái.
  - smoke-puff en los clones.
- **Proyectiles de mago y nigromante** con sprites de StarsteelGaming (`assets/VFX/Spells/`):
  lanza de hielo, bola de fuego, esfera de rayo.
- Los objetos que orbitan se centran en `Player.body_center()`.

### Siguiente
- Revisar con el usuario.
- Más efectos donde sigan siendo pobres: Blizzard (lluvia helada), Tempest Arrow, la Q del
  ninja, las E del ninja y del arquero.
- Sala de los cofres más grande.
- Portal: `rift-portal`.

### Sesión 3d
- Blizzard y tornado redibujados en `ability_zone.gd` (`_draw_blizzard` y `_draw_tornado`):
  - Blizzard: suelo helado, borde de cristales, nube, nieve con viento, granizo y ráfagas.
  - Tornado: embudo de anillos, cuerpo verde, escombros que suben y polvo.
  - Las zonas tienen luz propia (`_add_glow`).
- Escenario de playtest `zones`.
- El meteorito ya tiene explosión PVFX (verificado).

## PENDIENTE PRIORITARIO (feedback 28-10, noche)
1. **Q del arquero (tornado):** se ve plano, un círculo gris con rayas. Necesita textura
   real: buscar un sprite sheet pixel art de tornado o torbellino (CC0) o pintarlo a mano.
   Mantener la mecánica (le gusta).
2. **Meteorito:** el proyectil era una bola naranja. Ahora usa el sprite de bola de fuego
   (hecho al final de la sesión 3e); conviene un meteorito de verdad, rocoso y en llamas,
   con estela de humo. La explosión ya gusta.
3. **Ventisca:** "algo mejor, pero poco". Usar sprites de nieve, viento o tormenta reales
   en lugar de formas dibujadas.
4. **Otros:**
   - Sala de los cofres del nivel 1 más grande, con un puzzle nuevo.
   - Efectos de la ráfaga del arquero y del portal (`rift-portal`).
5. **Ahorro de tokens:** mirar una sola captura recortada por cambio, no regenerar hojas de
   contactos grandes y agrupar ediciones. El usuario nota mucho gasto.
