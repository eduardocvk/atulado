# A tu lado · Prueba Garmin v2

Prueba de viabilidad para Forerunner 970: mensajes de ánimo a 200 y 400 metros durante Carrera. No usar aún en competición.

## Cambio tras el error de medios en el reloj

La v1 iniciaba el reproductor nativo con un iterador vacío y reproducía los audios por Audio.Output. El usuario observó «Se ha producido un error de medios», posiblemente incluso antes de 200 m. El simulador no había detectado ese aviso. La lista vacía es un defecto comprobado del diseño; su relación con el aviso es una hipótesis pendiente de confirmar en el reloj.

La v2 utiliza solamente el reproductor nativo: descarga tres MP3 válidos en la caché de medios y proporciona contenido real al iterador. Una pista silenciosa de dos segundos se repite entre mensajes. La distancia se consulta al preparar la siguiente pista: puede haber retraso por precarga/transición y no se promete exactitud al metro. Mantener el reproductor activo puede consumir más batería; pendiente medirlo.

## Instalar y sincronizar

1. Descomprimir `bin/atulado-fr970-prueba-v2.zip` y copiar los dos `.prg` a la carpeta existente `GARMIN/Apps` del reloj, sustituyendo los de la prueba anterior. Son las mismas aplicaciones e identificadores.
2. Para registrar la prueba, crear `atulado-provider-fr970.txt` vacío en `GARMIN/Apps/Logs`. Los logs contienen distancia y eventos de reproducción, sin ubicación GPS.
3. Con wifi configurado, abrir el proveedor **A tu lado - prueba**. Su pantalla debe indicar **A TU LADO / V2**.
4. Pulsar START para descargar los tres archivos. También se puede mantener MENU para forzar una nueva sincronización. Esperar a que termine y volver al proveedor: debe indicar **3 audios preparados**. Los archivos públicos de prueba se descargan desde este mismo repositorio de GitHub; no se envían grabaciones ni datos del usuario.
5. Conectar los auriculares al reloj. Antes de caminar, pulsar DOWN en la configuración para probar la primera voz. Después quedará el silencio de espera. Esta reproducción manual no cuenta como mensaje de una carrera.
6. Salir del proveedor y abrirlo de nuevo para iniciar una sesión nueva. Pulsar START cuando ya haya 3 archivos preparados, iniciar una nueva actividad nativa de Carrera y recorrer más de 450 m. El primer y segundo mensaje deben aparecer una sola vez. Dejar que cada voz termine; evitar saltarla.
7. Repetir sin móvil ni wifi después de descargar, cambiando de pantalla y pausando/reanudando la actividad. Añadir si se desea el campo **A tu lado - distancia** para ver los metros. Ese campo es independiente: no controla el proveedor ni muestra mensajes escuchados.

Si falla la descarga, conservar el código mostrado. Si reaparece el error de medios, recuperar el log del reloj y anotar si también falla la prueba manual de voz. No hace falta repetir la caminata si la voz manual falla.

## Comportamiento y límites

Los mensajes se marcan completados mediante `SONG_EVENT_COMPLETE` y el identificador real de la pista, no por pasar su kilómetro ni por un simple STOPPED. La precarga devuelve una selección estable y no marca mensajes completados. No hay integración con Playrun ni persistencia de progreso de la carrera entre reinicios. Interrumpir una voz puede dejarla pendiente sin reintento automático durante esa sesión; reiniciar la prueba desde una actividad nueva. No borrar ni modificar actividades reales para probar.

La validación de auriculares, ciclo de vida dentro de Carrera, sincronización y avisos nativos debe hacerse en el reloj. El mockup web es independiente y no se ha modificado.

## Compilar y ejecutar pruebas

Verificado en esta revisión: compilación para `fr970`, MP3 decodificables y `distanceQueueRegression` en el simulador (1 prueba, 0 fallos, 0 errores). Pendientes: sincronización real, reproducción nativa, precarga y audios por distancia en el reloj. No se presenta esta versión como una solución ya confirmada en hardware.

SDK Garmin 9.3.0, Java 21 y perfil oficial `fr970` instalados. En este equipo SDK Manager necesitó iniciarse como administrador. Clave privada en `.local/` o fuera del repositorio, nunca en Git.

```powershell
./scripts/build.ps1 -SdkPath 'RUTA_AL_SDK' -SigningKey 'RUTA_A_CLAVE.der'
./scripts/build.ps1 -SdkPath 'RUTA_AL_SDK' -SigningKey 'RUTA_A_CLAVE.der' -Tests
& 'RUTA_AL_SDK/bin/connectiq.bat'
& 'RUTA_AL_SDK/bin/monkeydo.bat' 'bin/tests/atulado-provider-fr970.prg' fr970 /t
```

`garmin/shared/DistanceQueueTests.mc` comprueba umbrales, pausa, salto de distancia, exclusión de simultáneos, errores y finalización. No sustituye las pruebas del reproductor nativo ni las de hardware. Los binarios de instalación están en `bin/`; los de tests en `bin/tests/`.

## Referencias

- [Ejemplo oficial de proveedor de audio](https://github.com/garmin/connectiq-apps/tree/master/audio-provider/monkeymusic)
- [ContentIterator](https://developer.garmin.com/connect-iq/api-docs/Toybox/Media/ContentIterator.html)
- [Sincronización](https://developer.garmin.com/connect-iq/api-docs/Toybox/Communications/SyncDelegate.html)
