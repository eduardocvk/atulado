# A tu lado · Sincronización recuperable y menús del reloj (v5)

Web de carreras e invitaciones con grabación de voz, almacenamiento privado y proveedor Connect IQ para Forerunner 970. La prueba anterior de reproducción a 200 y 400 m funcionó en el reloj del usuario. Esta versión añade carreras reales y debe validarse de nuevo en hardware, especialmente la descarga de WAV.

## Uso

1. Entrar en [A tu lado](https://a-tu-lado.eduardocvk.chatgpt.site) con ChatGPT y crear una carrera. Los familiares no necesitan cuenta.
2. Crear una invitación y compartirla. El destinatario elige un kilómetro y graba o sube hasta 60 segundos de audio. Escucha la grabación y confirma el envío.
3. Descargar el ZIP v5 desde la web o desde `bin/atulado-fr970-v5.zip`. Copiar sus dos `.prg` a la carpeta existente `GARMIN/Apps` del reloj, sustituyendo los de prueba. Se conservan los identificadores de las aplicaciones.
4. Abrir **A tu lado - prueba** desde los proveedores de música del Garmin. La pantalla inicial es un menú nativo: UP/DOWN desplazan y START selecciona. Elegir **Vincular con la web** para obtener un código nuevo. No hace falta mantener pulsado MENU.
5. En el detalle de carrera de la web, abrir **Vincular esta carrera al Garmin** e introducir las ocho cifras. El código caduca a los diez minutos.
6. Volver al menú del reloj y elegir **Sincronizar carrera**, la primera opción, con conexión disponible. Solo cambia el paquete activo cuando terminan todas las descargas. Si falla o se cancela, conserva el anterior; repetir esta opción retoma los archivos completados, comprobando que sigan en caché y coincidan su carrera y huella de contenido. El archivo que se interrumpió se descarga entero.
7. Conectar auriculares al reloj. **Probar auriculares** permite escuchar la primera voz sin modificar el progreso. **Continuar carrera** inicia la reproducción de la cola. Iniciar la actividad nativa de Carrera/Trail y dejar el proveedor reproduciendo. **Ver progreso** muestra los pendientes, interrupciones y el último estado de sincronización. BACK vuelve al menú.
8. **Reiniciar progreso** permite iniciar una nueva salida con los mismos audios, tras una confirmación. Continuar no borra los mensajes completados.

El modo sorpresa oculta las voces y kilómetros en la web y en los títulos descargados. Hay que sincronizar otra vez si se cambia el modo o llegan mensajes nuevos.

## Qué incluye

- Carreras privadas por usuario; invitaciones renovables o cerrables.
- Grabación real en el navegador, escucha previa y subida con reintentos sin duplicar el mensaje.
- Validación de duración y formato en servidor. WAV PCM mono a 44,1 kHz y 16 bits, con ajuste de amplitud. No se sube el original con metadatos. Se usa WAV para evitar añadir un servicio externo de conversión; ocupa unos 5,3 MB por minuto. El silencio de espera sigue siendo MP3.
- Base de datos D1 y audios en R2. Ningún audio personal se guarda en GitHub. Claves de invitación y reloj almacenadas como hashes en el servidor.
- Vinculación temporal por código, autorizada por el propietario de la carrera.
- Cola por distancia, kilómetros coincidentes, progreso persistente por carrera e identificador de mensaje. Añadir mensajes y sincronizar no repite los ya completados.
- Finalización únicamente por `SONG_EVENT_COMPLETE` del archivo esperado. Interrupciones STOP/SKIP liberan la cola y permiten hasta tres intentos; los pendientes bloqueados se muestran en el reloj.
- Descarga con porcentaje nativo, estados de error visibles, registro persistente de archivos completados y reutilización por huella; los audios sustituidos se retiran de la caché tras confirmar el paquete nuevo. La primera actualización desde v4 vuelve a descargar el paquete una vez.
- Comparación por contenido de los textos recibidos por JSON, incluidos estado de carrera y formato del silencio MP3.
- Borrado de mensajes y carreras; borrar una carrera revoca también sus relojes.
- El mockup original se conserva sin modificar en `/concepto.html`, con su iframe aislado y su CSP.

## Límites de esta versión

Máximo inicial de 30 mensajes por carrera y 60 segundos por mensaje. La pista silenciosa se repite cada dos segundos; la precarga y transición pueden retrasar el disparo. Se sigue la distancia del reloj, no el poste kilométrico oficial.

El campo de datos muestra solo la distancia. No se comunica con el proveedor ni mantiene abierta la app. No se prometen contadores compartidos hasta comprobar un mecanismo fiable.

El login del corredor usa la identidad de Sites/ChatGPT, no correo mágico propio. Los invitados participan sin iniciar sesión. La retención es hasta borrado por el corredor. Solo se reciben mensajes antes de una nueva sincronización; no hay envíos en directo durante la carrera.

Pendientes de validación: micrófono en móviles reales, vinculación y WAV en el reloj, auriculares al desconectar/reconectar, avisos y navegación, carreras largas, memoria y batería. El altavoz y la convivencia con Playrun/Spotify quedan fuera de esta entrega. Detener el reproductor al terminar la actividad.

## Desarrollo y pruebas

- `garmin/provider`: proveedor v5 con web, caché nativa y recuperación de progreso.
- `garmin/field`: campo de distancia independiente.
- `garmin/shared`: cola y regresiones Monkey C.
- `web`: Vinext/React sobre Cloudflare Workers, D1 y R2; ver su README.

SDK oficial Garmin 9.3.0 y perfil `fr970`. SDK Manager se instaló como administrador en este equipo. La clave de desarrollo está en `.local/` y no se sube al repositorio.

```powershell
./scripts/build.ps1 -SdkPath 'RUTA_AL_SDK' -SigningKey 'RUTA_A_CLAVE.der'
./scripts/build.ps1 -SdkPath 'RUTA_AL_SDK' -SigningKey 'RUTA_A_CLAVE.der' -Tests
& 'RUTA_AL_SDK/bin/connectiq.bat'
& 'RUTA_AL_SDK/bin/monkeydo.bat' 'bin/tests/atulado-provider-fr970.prg' fr970 /t
```

Para obtener logs, crear `atulado-provider-fr970.txt` vacío en `GARMIN/Apps/Logs`. No se registran claves ni grabaciones. Las líneas `ATULADO` permiten localizar selección, finalización e interrupciones. Los binarios de test están separados en `bin/tests/`.

Verificación de desarrollo: once regresiones Monkey C en simulador (cola, recuperación, igualdad de textos y presencia de acciones en el menú), cuatro pruebas de audio, comprobación de tipos, integración local con D1/R2 y revisión en navegador de creación, invitación, conversión y envío. Esto no sustituye la nueva prueba física. La navegación visual del menú y una interrupción real de la red todavía requieren validación en el Forerunner.

## Publicación y recuperación

GitHub conserva el código. Sites conserva además su propio repositorio de despliegue y aplica las migraciones de `web/drizzle`. `.openai/hosting.json` declara el proyecto existente y los bindings `DB` y `BUCKET`. La audiencia pública se conserva; los datos privados se protegen en cada endpoint.

El despliegue anterior era el mockup estático, versión 1. Se conserva como versión de recuperación en Sites. Los cambios de esquema se añaden mediante nuevas migraciones; no modificar una migración ya aplicada. El proveedor v2 de prueba permanece recuperable desde el commit `94b7dd6` y su ZIP local anterior.

Referencias: [proveedor oficial de Garmin](https://github.com/garmin/connectiq-apps/tree/master/audio-provider/monkeymusic), [Media](https://developer.garmin.com/connect-iq/api-docs/Toybox/Media.html).
