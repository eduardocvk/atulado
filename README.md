# A tu lado · Prueba Garmin

Experimento para Forerunner 970: reproducir dos mensajes de voz al superar **200 y 400 metros**, manteniendo la actividad nativa de Carrera. Aún no es una app lista para competir.

## Qué hay

- `garmin/provider`: proveedor de audio con dos voces sintéticas de prueba incluidas en WAV. Usa la API Audio.Output (6.0.3), sin teléfono, servidor ni descargas durante la carrera.
- `garmin/field`: campo independiente que muestra los metros de la actividad. **No comparte estado con el proveedor ni puede mantenerlo activo**. Por ello no muestra un contador de mensajes escuchados.
- `garmin/shared`: cola por distancia y pruebas Monkey C de umbrales, pausas, saltos de distancia, exclusión de reproducciones simultáneas, errores y finalización.
- `scripts/build.ps1`: compilación específica para fr970. La clave privada nunca se sube al repositorio.

## Estado de verificación (4 de noviembre de 2026)

Ambos proyectos pasan la compilación genérica del SDK oficial 9.3.0. No se han ejecutado en simulador ni reloj. Las pruebas de regresión están escritas y se compilan con `-t`, pero todavía no se han ejecutado.

**Bloqueo:** falta el perfil oficial `fr970`. Instalarlo en Garmin Connect IQ SDK Manager, iniciando sesión con la cuenta Garmin. No se han inventado perfiles ni usado uno de otro reloj. Los binarios genéricos locales no son entregables validados para instalar.

## Compilar

Instalar SDK 9.3.0 o posterior, Java 21 y el dispositivo Forerunner 970 desde SDK Manager. Generar una clave de desarrollo siguiendo la documentación oficial de Garmin y guardarla fuera del código, o en `.local/` (ignorado por Git).

Desde PowerShell, en la raíz:

```powershell
./scripts/build.ps1 -SdkPath 'RUTA_AL_SDK' -SigningKey 'RUTA_A_CLAVE.der'
./scripts/build.ps1 -SdkPath 'RUTA_AL_SDK' -SigningKey 'RUTA_A_CLAVE.der' -Tests
```

Para ejecutar los tests, abrir el simulador con `connectiq.bat` y lanzar:

```powershell
& 'RUTA_AL_SDK/bin/monkeydo.bat' 'bin/atulado-provider-fr970.prg' fr970 /t
```

## Instalar y probar en el reloj

1. Compilar para fr970. Conectar el reloj por USB y copiar los dos `.prg` de `bin/` a la carpeta existente `GARMIN/Apps`. No copiar los binarios genéricos.
2. Para obtener registros, crear `atulado-provider-fr970.txt` vacío en `GARMIN/Apps/Logs` antes de ejecutar. Recuperarlo al terminar; las líneas empiezan por `ATULADO` e incluyen segundos de ejecución, distancia y estados de audio. No se registran ubicaciones ni datos personales.
3. Añadir el campo **A tu lado - distancia** a Carrera. Conectar auriculares al reloj, desconectar el móvil y seleccionar **A tu lado - prueba** como proveedor de música.
4. Pulsar START en la pantalla de configuración. Se solicita el contexto nativo de reproducción. No hay una pista silenciosa: queremos comprobar si Garmin conserva vivo el proveedor entre mensajes. Si sale o no permanece activo, ese resultado es un fallo de esta estrategia, no de la distancia.
5. Iniciar una actividad nueva de Carrera, caminar/correr más de 450 metros y cambiar entre el campo, ritmo y mapa. Deben oírse los dos mensajes una sola vez. El punto es la distancia del reloj, no un poste del recorrido.
6. Repetir desde una nueva ejecución de la app, pausando antes de los 200 m y reanudando. Durante la pausa no debe comenzar un mensaje nuevo. Uno ya iniciado puede terminar.
7. Guardar la actividad y revisar el archivo FIT en Garmin Connect y el log de la prueba.

Control adicional: mantener MENU en la configuración activa la lectura de distancia y audio en ese contexto. Sirve para separar los problemas de audio de los de ciclo de vida; no demuestra funcionamiento autónomo dentro de Carrera.

## Criterio para continuar

Se necesita evidencia en reloj de: ticks y distancia actualizada con Carrera visible; dos audios en auriculares; reproducción sin cobertura; continuidad entre mensajes; ausencia de duplicados; actividad guardada correctamente. La API podría enviar el audio al altavoz: hay que observar la salida real, no asumirla.

El contador del proveedor solo se reduce después de observar PLAYING y luego STOPPED. Eso indica fin de reproducción, pero no garantiza que se haya oído completo; también podría ser una interrupción. En caso de error se conserva el pendiente y se bloquean más intentos hasta reiniciar. Es una prueba de viabilidad, pendiente de mejorar el reconocimiento de fin, persistencia ante reinicios, cancelaciones, salida de audio y watchdog de reproducciones atascadas.

Si Garmin cierra el proveedor sin pista, habrá que probar otra arquitectura; este prototipo no intenta evadir las restricciones del sistema. No hay integración con Playrun ni sincronización entre aplicaciones. El sitio publicado es un mockup separado y no se ha modificado.

## Referencias oficiales

- [Audio.Output](https://developer.garmin.com/connect-iq/api-docs/Toybox/Audio/Output.html)
- [Recursos de audio](https://developer.garmin.com/connect-iq/articles/core-topics/Resources.html)
- [Tipos y permisos](https://developer.garmin.com/connect-iq/articles/core-topics/Manifest_and_Permissions.html)
- [SDK y dispositivos](https://developer.garmin.com/connect-iq/sdk/)
