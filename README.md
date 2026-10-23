# El corazón del volcán

Juego de parkour 3D para Godot 4.7, construido con geometría, materiales y animaciones del motor. Abre `project.godot` y ejecuta el proyecto con **F5** para iniciar la escena principal `mundo.tscn`. No necesita paquetes externos.

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

- `partida.gd` coordina inicio, pausa, derrota, entrega y victoria. Es el único responsable de transferir el orbe entre pedestal, espalda y altar.
- `jugador.gd` controla movimiento, salto, viento, cámaras y los estados normal, colgado, escalando y bloqueado.
- `personaje.gd` construye y anima el personaje articulado; `orbe.tscn` y `orbe.gd` comparten el aspecto y la animación del orbe.
- `mundo.tscn` contiene los apoyos y sus colisiones editables. `paisaje.gd` construye decoración determinista y `lava.gdshader` anima la lava.
- `altar.gd` comunica interacciones por proximidad; `interfaz.gd` presenta los menús y las instrucciones.

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
