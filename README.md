# El corazón del volcán

**Asignatura:** Ingeniería de Videojuegos: Fundamentos y Aplicaciones Interactivas (USACH)  
**Entrega:** LAB 2 – Prototipo de Escena Base  
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

Cruza los tres sectores del circuito, recoge el Orbe Sagrado del altar final y devuélvelo al altar de la isla inicial. Hay 24 apoyos, dos vigas y tres zonas de viento. La lava es letal: al caer aparece **Has caído**, el orbe vuelve a su pedestal y **Reintentar** comienza una partida nueva desde el inicio.

| Control | Acción |
| --- | --- |
| WASD / flechas | Moverse |
| Ratón | Orientar al personaje y la cámara |
| Espacio | Saltar; mantenerlo permite alcanzar mayor altura |
| E | Recoger o entregar el orbe cerca del altar |
| V | Alternar primera y tercera persona |
| Esc | Pausar / continuar, también durante escalada o entrega |
| Espacio, colgado | Subir sobre la plataforma |
| S / flecha abajo, colgado | Soltarse |

El agarre de bordes es automático al caer junto a una plataforma y no tiene límite de tiempo. Solo funcionan los bordes del circuito y de la isla inicial. Un techo u otro obstáculo que bloquee la subida impide escalar. Al soltarse hay una breve tolerancia para no volver a agarrarse inmediatamente.

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
│   └── viento/     Zonas de viento
├── ui/             Menús e instrucciones
├── assets/
│   ├── texturas/   Texturas PBR
│   └── audio/      Efectos de sonido y música
└── tests/          Pruebas automáticas
```

- `niveles/mundo/partida.gd` coordina inicio, pausa, derrota, entrega y victoria. Es el único responsable de transferir el orbe entre pedestal, espalda y altar.
- `jugador/jugador.gd` controla movimiento, salto, viento, cámaras y los estados normal, colgado, escalando y bloqueado.
- `jugador/personaje.gd` construye y anima el personaje articulado; `objetos/orbe/orbe.tscn` y `orbe.gd` comparten el aspecto y la animación del orbe.
- `niveles/mundo/mundo.tscn` contiene los apoyos y sus colisiones editables. `paisaje.gd` construye decoración determinista y `lava.gdshader` anima la lava.
- `niveles/mundo/parkour_generador.gd` coloca los apoyos del parkour de forma aleatoria al entrar al nivel. Cada apoyo queda al alcance del anterior y la dificultad sube por sector. Los parámetros de distancia, altura y giro están en el script; `semilla` fija un mapa concreto.
- `objetos/altar/altar.gd` comunica interacciones por proximidad; `ui/interfaz.gd` presenta los menús y las instrucciones.

Las rutas escritas en el código (`preload(...)`, la propiedad `escena` de las puertas) no se actualizan solas al mover archivos. Si mueves algo, búscalas con **Ctrl+Shift+F** en el editor de scripts.

Capas físicas: **1** sólidos, **2** superficies agarrables, **3** jugador. Los apoyos e isla pertenecen a las capas 1 y 2; los pedestales solo a la 1. La decoración no tiene colisión. El área de lava detecta al jugador y existe además un límite de altura para caídas fuera del mapa.

## Pruebas

Ejecuta desde la carpeta del proyecto, usando el ejecutable de Godot instalado en tu equipo en lugar de `godot` si no está en el PATH:

```sh
godot --headless --path . --script res://tests/test_partida.gd --fixed-fps 120
godot --headless --path . --script res://tests/test_bordes.gd --fixed-fps 120
godot --headless --path . --script res://tests/test_recorrido.gd --fixed-fps 120
godot --headless --path . --script res://tests/test_viaje.gd --fixed-fps 120
```

Las pruebas cubren transferencias del orbe, lava, reintentos, cámaras, pausa, entrega y victoria; caras y esquinas agarrables, obstrucciones, soltarse y ausencia de límite de tiempo; los 48 saltos individuales de ida/vuelta; y un viaje continuo desde la aparición hasta la victoria, con viento activo. En la prueba continua el jugador usa las acciones de movimiento y salto, sin teletransportes ni cambios artificiales de velocidad.
