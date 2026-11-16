# El corazón del volcán

**Asignatura:** Ingeniería de Videojuegos: Fundamentos y Aplicaciones Interactivas (USACH)  
**Entrega:** LAB 3 – Mecánica Principal Implementada  
**Video de demostración:** _(pendiente: agregar enlace de Google Drive / OneDrive)_  
**Nombre del equipo:** CTM Lovers 

**Integrantes:** Benjamín Sepúlveda, Bastian Brito, Mohamed Al-Marzuk 
**Nombre del proyecto:** El Juego CTM  
**Motor utilizado:** Godot Engine v4.7.2-stable (Renderer Forward+, Jolt Physics 3D)  

---

## Instrucciones para abrir y ejecutar el proyecto

1. Descargar e instalar **Godot 4.7** (o ejecutar la versión portable de Godot 4.7.x).
2. Abrir el administrador de proyectos de Godot (*Project Manager*), presionar **Importar** y seleccionar el archivo `project.godot` ubicado en la raíz de este repositorio.
3. Presionar **F5** (o el botón **Ejecutar proyecto** en la barra superior derecha).
4. El juego iniciará en la escena de vestíbulo inicial (`res://niveles/spawn/spawn.tscn`). El personaje aparecerá en la plaza del spawn; desde allí, camina hacia el portal identificado con el texto **Parkour** para ingresar al nivel volcánico (`res://niveles/mundo/mundo.tscn`).
5. Para regresar al vestíbulo desde el nivel de parkour, cruza la puerta identificada como **Inicio** en la isla de partida.
6. *(Nota: si en el editor estás editando `mundo.tscn` y presionas **F6**, se ejecutará solo esa escena. Usa siempre **F5** para iniciar el flujo completo desde el spawn).*

No se requieren paquetes, plugins ni dependencias externas.

---

## Control de versiones y exclusiones (.gitignore)

El repositorio cuenta con un archivo `.gitignore` configurado adecuadamente para proyectos en Godot Engine. Este archivo ignora de forma obligatoria carpetas pesadas y temporales generadas automáticamente por el motor:
- **`.godot/`:** Carpeta equivalente a `Library/` en Unity o `Intermediate/` en Unreal Engine. Contiene la caché de importación de recursos, mallas precompiladas, texturas procesadas y metadatos locales. Ignorarla evita sobrecargar el repositorio y previene conflictos de sincronización entre distintas máquinas.
- **`/android/`:** Carpeta temporal de compilación móvil (si aplica).

---

## Descripción del proyecto

## Objetivo y controles

Cruza los cuatro sectores del circuito, sube la torre del orbe, recoge el Orbe Sagrado de su cima y devuélvelo al altar de la isla inicial. La lava es letal.

**Recorrido y curva de dificultad** (32 apoyos y una torre):

1. **Sector 1** (Apoyo01-08): saltos cortos para aprender.
2. **Sector 2** (Apoyo09-16): saltos más largos, viento y la primera plataforma inestable.
3. **Sector 3** (Apoyo17-24): saltos largos, más giros y viento.
4. **Descanso** (Apoyo25): una plataforma amplia, sin viento y con un cristal de agua. Es el respiro antes del clímax.
5. **Sector 4, el clímax** (Apoyo26-32): plataformas más pequeñas que exigen precisión, los saltos más largos y dos plataformas inestables.
6. **Torre del orbe:** 5 pisos en espiral, cada uno 2.3 m más alto que el anterior. Es demasiado para saltar, así que se sube **colgándose del borde** del piso siguiente y escalando. El orbe está en la cima.

Las tres zonas de viento están en los sectores 2 y 3. La lava es letal: al caer aparece **Has caído**, el orbe vuelve a su pedestal y **Reintentar** comienza una partida nueva desde el inicio.

**Mecánica principal:** el salto entre plataformas sobre la lava, con agarre de bordes. La complican las ráfagas de viento (que se resisten agachándose) y las plataformas inestables.

**Calor (sistema de salud):** la barra **CALOR** del HUD es tu resistencia. En el volcán baja sola: la barra llena dura 75 s. Baja el doble de rápido dentro de las zonas de viento y ×1.5 agachado, porque estás más cerca de la lava (agachado en el viento: ×3). Recoger el orbe la llena. Si llega a cero aparece **El calor te venció**; caer a la lava la vacía de golpe. Con poca resistencia la barra late en rojo, y al recuperarse destella en celeste. Las pantallas de derrota, pausa y victoria ofrecen **Volver al vestíbulo**.

**Desvíos y cristales de agua:** de cada sector sale un desvío, un callejón sin salida más difícil que el camino principal: saltos más largos en el sector 1, una plataforma final inestable en el 2 y tres saltos en subida en el 3. Al final de cada uno hay un **cristal de agua** azul que recupera el 40 % de la barra. Los cristales **no se recargan**: si los gastas todos a la ida, a la vuelta no quedan. El cuarto cristal está en la plataforma de descanso, sobre el camino. El HUD cuenta los recogidos (**Cristales de agua: N / 4**).

**Plataformas inestables:** los tres apoyos bajo las zonas de viento tienen grietas incandescentes. Al pisarlos o colgarse de ellos tiemblan durante 1.5 s, con las grietas cada vez más brillantes y un crujido, y luego se desploman a la lava. Unos 3.5 s después reaparecen en su sitio, así que el regreso con el orbe sigue siendo posible. Agacharse protege del viento, pero no del derrumbe: el jugador no puede quedarse quieto.

### Controles

El juego se controla con **teclado y ratón** o con **mando** (probado con la distribución Xbox; en otros mandos se usa el botón en la misma posición). Todas las acciones están definidas en el InputMap (*Proyecto → Configuración del proyecto → Mapa de entrada*); el código nunca lee teclas directamente.

| Acción (InputMap) | Teclado / ratón | Mando | Uso |
| --- | --- | --- | --- |
| `mover_adelante` / `atras` / `izquierda` / `derecha` | WASD / flechas | Stick izquierdo / cruceta | Moverse |
| `camara_*` | Ratón | Stick derecho | Orientar al personaje y la cámara |
| `saltar` | Espacio | A | Saltar (mantener = más altura). Colgado: subir |
| `mover_atras` (colgado) | S / flecha abajo | Stick abajo / cruceta abajo | Soltarse del borde |
| `agacharse` | Shift (mantener) | B (mantener) | Aferrarse al suelo: inmune al viento y a cualquier empuje, sin poder moverse ni saltar |
| `interactuar` | E | X | Recoger o entregar el orbe cerca del altar |
| `cambiar_camara` | V | Y | Alternar primera y tercera persona |
| `pausa` | Esc | Start | Pausar / continuar, en el volcán y en el vestíbulo |

En los menús se navega con flechas o con la cruceta, y se confirma con Enter o con A. Los textos en pantalla (altares, ayuda al colgarse, barra de controles) muestran los botones del último dispositivo usado; lo detecta el autoload `Dispositivo` (`ui/dispositivo.gd`).

El agarre de bordes es automático al caer junto a una plataforma y no tiene límite de tiempo. Al bajarse caminando hacia otra plataforma que está justo debajo (como en la torre), no se agarra del borde que acaba de dejar; si debajo hay lava, sí se agarra. Solo funcionan los bordes del circuito y de la isla inicial. Un techo u otro obstáculo que bloquee la subida impide escalar. Al soltarse hay una breve tolerancia para no volver a agarrarse inmediatamente.

El orbe flota en la espalda mientras se transporta. En primera persona se oculta con el cuerpo. Al entregarlo, viaja al altar mediante una animación; después aparece **Orbe colocado** y **Reiniciar escenario**.

## Organización

El proyecto se organiza **por funcionalidad**: cada pieza del juego tiene su propia carpeta con su escena y su script. Así quien trabaja en una pieza toca una sola carpeta y se reducen los conflictos de merge.

```
├── niveles/
│   ├── spawn/      Vestíbulo inicial (escena principal)
│   └── mundo/      Nivel volcánico: partida, generador de parkour, paisaje y lava
├── jugador/        Movimiento del jugador y personaje articulado
├── objetos/
│   ├── orbe/       Orbe Sagrado
│   ├── puerta/     Portales entre niveles
│   ├── altar/      Altares (interacción por proximidad)
│   ├── viento/     Zonas de viento
│   ├── plataforma_inestable/  Apoyos RigidBody3D que se derrumban
│   └── cristal/    Cristales de agua que recuperan resistencia
├── ui/             Menús e instrucciones
├── audio/          Música de fondo (autoload) y SonidoSuelto: sonidos que sobreviven a cambios de escena
├── assets/
│   ├── texturas/   Texturas PBR
│   └── audio/      Efectos de sonido y música
└── tests/          Pruebas automáticas
```

- `niveles/mundo/partida.gd` coordina inicio, pausa, derrota, entrega y victoria. Es el único responsable de transferir el orbe entre pedestal, espalda y altar.
- `jugador/jugador.gd` controla movimiento, salto, viento, cámaras y los estados normal, colgado, escalando y bloqueado.
- `jugador/personaje.gd` construye y anima el personaje articulado; `objetos/orbe/orbe.tscn` y `orbe.gd` comparten el aspecto y la animación del orbe.
- `niveles/mundo/mundo.tscn` contiene los apoyos y sus colisiones editables. `paisaje.gd` construye decoración determinista y `lava.gdshader` anima la lava.
- `niveles/mundo/parkour_generador.gd` coloca los apoyos del parkour de forma aleatoria al entrar al nivel. Cada apoyo queda al alcance del anterior y la dificultad sube por sector. Los parámetros de distancia, altura y giro están en el script; `semilla` fija un mapa concreto. Apoyo01-24 están en `mundo.tscn`; el descanso, el sector 4 (Apoyo25-32) y la torre se crean por código copiando apoyos existentes. También genera los tres desvíos (lista `desvios`): si uno no cabe desde su apoyo, lo intenta desde los vecinos, y nunca invade la decoración. El volcán decorativo (`Z_VOLCAN` en `paisaje.gd`) está calculado para que el circuito más largo no lo toque.
- `objetos/plataforma_inestable/plataforma_inestable.gd` es un `RigidBody3D` congelado (`freeze`) mientras está estable. Al derrumbarse se descongela y su caída la calcula el motor de física (Jolt). Apoyo12, Apoyo16 y Apoyo21 en `mundo.tscn` usan este script. Si se agregan `assets/audio/crujido.wav` y `derrumbe.wav` (también .mp3 / .ogg), se usan automáticamente.
- `jugador/salud.gd` (`Salud`) es un componente reutilizable: lleva la salud y avisa con las señales `cambiada` y `agotada`. No sabe qué causa el daño. En el volcán lo quema `niveles/mundo/calor.gd`, y `ui/barra_salud.gd` lo muestra en el HUD conectándose a esas señales (patrón Observer, sin consultar la salud cada frame).
- `objetos/altar/altar.gd` comunica interacciones por proximidad; `ui/interfaz.gd` presenta los menús y las instrucciones.
- `audio/musica.gd` (autoload `Musica`) mantiene la música entre escenas y la mezcla consigo misma al repetirse. Buses de audio: **SFX**, **Musica** y **Ambiente**.

Las rutas escritas en el código (`preload(...)`, la propiedad `escena` de las puertas) no se actualizan solas al mover archivos. Si mueves algo, búscalas con **Ctrl+Shift+F** en el editor de scripts.

Capas físicas: **1** sólidos, **2** superficies agarrables, **3** jugador. Los apoyos e isla pertenecen a las capas 1 y 2; los pedestales solo a la 1. Una plataforma inestable que cae pasa a solo la capa 1 (ya no se puede agarrar). Todos los colisionadores son primitivos: caja, cápsula, esfera o cilindro, sin colisionadores de malla. La decoración no tiene colisión. El área de lava detecta al jugador y existe además un límite de altura para caídas fuera del mapa.

## Pruebas

Ejecuta desde la carpeta del proyecto, usando el ejecutable de Godot instalado en tu equipo en lugar de `godot` si no está en el PATH:

```sh
godot --headless --path . --script res://tests/test_partida.gd --fixed-fps 120
godot --headless --path . --script res://tests/test_bordes.gd --fixed-fps 120
godot --headless --path . --script res://tests/test_recorrido.gd --fixed-fps 120
godot --headless --path . --script res://tests/test_viaje.gd --fixed-fps 120
godot --headless --path . --script res://tests/test_inestables.gd --fixed-fps 120
godot --headless --path . --script res://tests/test_salud.gd --fixed-fps 120
godot --headless --path . --script res://tests/test_cristales.gd --fixed-fps 120
```

Las pruebas cubren transferencias del orbe, lava, reintentos, cámaras, pausa, entrega y victoria; caras y esquinas agarrables, obstrucciones, soltarse y ausencia de límite de tiempo; los 48 saltos individuales de ida/vuelta; y un viaje continuo desde la aparición hasta la victoria, con viento activo. En la prueba continua el jugador usa las acciones de movimiento y salto, sin teletransportes ni cambios artificiales de velocidad. `test_inestables` comprueba el temblor, la caída por física, la reaparición, el derrumbe estando colgado y las acciones con mando (botones y sticks).

`test_viaje` usa un mapa aleatorio y a veces falla porque el bot se demora en una plataforma inestable o falla un salto puntual. Si falla, vuelve a ejecutarla.
