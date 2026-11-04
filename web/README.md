# Web A tu lado

Vinext/React, Cloudflare Workers, D1 (`DB`) y R2 (`BUCKET`). Las fuentes se mantienen en este directorio; el sitio conserva el proyecto `appgprj_6aeaee9b50b48191a6d70b1603f66960`.

## Ejecutar

Node >=22.13.0. Instalar usando el helper de Sites `install-dependencies.mjs`. El perfil portable conserva la configuración del ordenador.

```powershell
npm run dev -- --hostname 127.0.0.1 --port 5173
node --test tests/audio.test.mjs
node node_modules/typescript/bin/tsc --noEmit
node tests/integration.mjs
```

La integración se ejecuta únicamente contra `127.0.0.1:5173` con autenticación simulada del starter local. Usa tonos sintéticos y registros desechables, y borra su carrera al terminar. No ejecuta envíos de correo ni toca producción. El mock de identidad es exclusivo del preview; en producción Sites inyecta la identidad autenticada.

## Base de datos

Declarar los bindings en `.openai/hosting.json`. Tras modificar `db/schema.ts`:

```powershell
npm run db:generate
npm run build
node --import ./scripts/sites-env.mjs ./node_modules/wrangler/bin/wrangler.js d1 execute DB --local --config dist/server/wrangler.json --persist-to .wrangler/state --file drizzle/0000_wet_captain_midlands.sql
```

Ese último comando es para la primera instalación local; no repetir migraciones aplicadas. Sites aplica las migraciones de producción durante la publicación. No se crean tablas al atender solicitudes.

## Acceso y archivos

Los endpoints de propietario exigen la identidad de Sites y verifican el dueño en SQL. Las invitaciones y los relojes utilizan tokens aleatorios; el servidor guarda solo el hash. El enlace de invitación lleva el token en el fragmento, y el navegador lo envía en Authorization. No se envían grabaciones por email ni a GitHub.

El navegador convierte el audio en WAV; el servidor verifica la cabecera completa, duración, frecuencia, canales y muestras y reconstruye un WAV normalizado. El cuerpo se lee con límite antes de guardarlo. La subida usa un identificador de reintento; cerrar una invitación o borrar una carrera durante la carga impide confirmar un mensaje huérfano.

El perfil del reloj se obtiene de `/api/device/package` con autorización propia. La descarga privada de WAV requiere la misma credencial y carrera vinculada. El silencio `/wait.mp3` es público y no contiene información personal.

## Publicar

Usar el flujo de Sites con el proyecto existente, compilar mediante `build-site.mjs`, subir la fuente exacta y desplegar la versión guardada. No cambiar la audiencia pública para resolver errores. El mockup original se conserva en `public/concepto.html` sin alterar su contenido.
