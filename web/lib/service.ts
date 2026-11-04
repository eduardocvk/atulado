import { env } from 'cloudflare:workers';
import { prepareWav, MAX_BYTES, AudioError } from './audio.mjs';
class HttpError extends Error {
    constructor(public status: number, message: string) { super(message); }
}
const db = () => { if (!env.DB)
    throw new HttpError(503, 'El servicio de datos no está disponible.'); return env.DB; };
const bucket = () => { if (!env.BUCKET)
    throw new HttpError(503, 'El almacenamiento no está disponible.'); return env.BUCKET; };
const json = (v: unknown, status = 200) => Response.json(v, { status, headers: { 'Cache-Control': 'no-store', 'Referrer-Policy': 'no-referrer' } });
const random = () => Array.from(crypto.getRandomValues(new Uint8Array(32)), b => b.toString(16).padStart(2, '0')).join('');
export async function hash(value: string | ArrayBuffer) { return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', typeof value === 'string' ? new TextEncoder().encode(value) : value)), b => b.toString(16).padStart(2, '0')).join(''); }
const token = (r: Request) => r.headers.get('authorization')?.replace(/^Bearer /, '') || '';
const identity = (r: Request) => { const id = r.headers.get('oai-authenticated-user-id'); if (!id)
    throw new HttpError(401, 'Inicia sesión para gestionar tus carreras.'); return id; };
async function rate(r: Request, scope: string, max: number) {
    await db().prepare('DELETE FROM request_limits WHERE expires<?').bind(Date.now()).run();
    const period = Math.floor(Date.now() / 60000), key = scope + ':' + period + ':' + await hash(r.headers.get('cf-connecting-ip') || 'local');
    const row = await db().prepare('INSERT INTO request_limits(key,count,expires) VALUES(?,1,?) ON CONFLICT(key) DO UPDATE SET count=count+1 RETURNING count').bind(key, Date.now() + 120000).first<{
        count: number;
    }>();
    if (row!.count > max)
        throw new HttpError(429, 'Demasiados intentos. Espera un minuto.');
}
async function body(r: Request) { if (Number(r.headers.get('content-length')) > 8192)
    throw new HttpError(413, 'Solicitud demasiado grande.'); const b = await bounded(r, 8192); try {
    const data = JSON.parse(new TextDecoder().decode(b));
    if (!data || typeof data !== 'object' || Array.isArray(data))
        throw new Error();
    return data;
}
catch {
    throw new HttpError(400, 'Solicitud no válida.');
} }
async function bounded(r: Request, max: number) { const reader = r.body?.getReader(); if (!reader)
    throw new HttpError(400, 'Falta contenido.'); let total = 0; const chunks: Uint8Array[] = []; for (;;) {
    const { done, value } = await reader.read();
    if (done)
        break;
    total += value.length;
    if (total > max) {
        await reader.cancel();
        throw new HttpError(413, 'Archivo demasiado grande.');
    }
    chunks.push(value);
} const bytes = new Uint8Array(total); let p = 0; for (const c of chunks) {
    bytes.set(c, p);
    p += c.length;
} return bytes.buffer; }
function text(v: unknown, min: number, max: number) { if (typeof v !== 'string' || v.trim().length < min || v.trim().length > max)
    throw new HttpError(400, 'Revisa los campos del formulario.'); return v.trim(); }
async function owned(r: Request, id: string) { const row = await db().prepare('SELECT * FROM races WHERE id=? AND owner=?').bind(id, identity(r)).first<any>(); if (!row)
    throw new HttpError(404, 'Carrera no encontrada.'); return row; }
async function invitation(r: Request) { const t = token(r); if (!/^[a-f0-9]{64}$/.test(t))
    throw new HttpError(404, 'Invitación no disponible.'); const race = await db().prepare('SELECT * FROM races WHERE invite_hash=? AND open=1').bind(await hash(t)).first<any>(); if (!race)
    throw new HttpError(404, 'La invitación está cerrada o ha cambiado.'); return race; }
async function device(r: Request) { const t = token(r); if (!/^[a-f0-9]{64}$/.test(t))
    throw new HttpError(401, 'Vincula el reloj desde la web.'); const d = await db().prepare('SELECT * FROM devices WHERE token_hash=? AND expires>?').bind(await hash(t), Date.now()).first<any>(); if (!d)
    throw new HttpError(401, 'La vinculación ha caducado. Vincula de nuevo el reloj.'); return d; }
async function audio(key: string) { const object = await bucket().get(key); if (!object)
    throw new HttpError(404, 'Audio no disponible.'); return new Response(object.body, { headers: { 'Content-Type': 'audio/wav', 'Content-Length': String(object.size), 'Cache-Control': 'private, no-store', 'X-Content-Type-Options': 'nosniff' } }); }
export async function handle(r: Request) {
    try {
        const u = new URL(r.url), p = u.pathname, m = r.method;
        if (m !== 'GET' && r.headers.get('origin') && r.headers.get('origin') !== u.origin)
            throw new HttpError(403, 'Origen no autorizado.');
        if (p === '/api/me' && m === 'GET')
            return json({ signedIn: !!r.headers.get('oai-authenticated-user-id') });
        if (p === '/api/races' && m === 'GET')
            return json((await db().prepare('SELECT id,name,date,meters,version,open,surprise,created FROM races WHERE owner=? ORDER BY created DESC').bind(identity(r)).all()).results);
        if (p === '/api/races' && m === 'POST') {
            const owner = identity(r);
            await rate(r, 'race', 20);
            const b = await body(r), name = text(b.name, 2, 100), date = text(b.date, 10, 10), meters = Math.round(Number(b.km) * 1000);
            if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || !Number.isFinite(Date.parse(date)) || new Date(date).toISOString().slice(0, 10) !== date || !Number.isInteger(meters) || meters < 200 || meters > 1000000)
                throw new HttpError(400, 'Fecha o distancia no válida (0,2 a 1.000 km).');
            const id = crypto.randomUUID();
            await db().prepare('INSERT INTO races(id,owner,name,date,meters,created) VALUES(?,?,?,?,?,?)').bind(id, owner, name, date, meters, Date.now()).run();
            return json({ id }, 201);
        }
        const raceRoute = p.match(/^\/api\/races\/([a-f0-9-]+)(?:\/(invite|messages|close|surprise|device))?$/);
        if (raceRoute) {
            const [, id, action] = raceRoute;
            const race = await owned(r, id);
            if (!action && m === 'GET')
                return json({ id: race.id, name: race.name, date: race.date, meters: race.meters, version: race.version, open: race.open, surprise: race.surprise });
            if (!action && m === 'DELETE') {
                await db().prepare('UPDATE races SET open=0,invite_hash=NULL WHERE id=?').bind(id).run();
                const keys = (await db().prepare('SELECT object_key FROM messages WHERE race=?').bind(id).all<{
                    object_key: string;
                }>()).results.map(x => x.object_key);
                await db().batch([db().prepare('DELETE FROM devices WHERE race=?').bind(id), db().prepare('DELETE FROM messages WHERE race=?').bind(id), db().prepare('DELETE FROM races WHERE id=?').bind(id)]);
                if (keys.length)
                    await bucket().delete(keys);
                return json({ ok: true });
            }
            if (action === 'messages' && m === 'GET')
                return json((await db().prepare('SELECT id,name,meters,duration,ready,created FROM messages WHERE race=? ORDER BY meters,created,id').bind(id).all()).results);
            if (action === 'invite' && m === 'POST') {
                const secret = random();
                await db().prepare('UPDATE races SET invite_hash=?,open=1 WHERE id=?').bind(await hash(secret), id).run();
                return json({ url: u.origin + '/enviar#' + secret });
            }
            if (action === 'close' && m === 'POST') {
                await db().prepare('UPDATE races SET open=0,invite_hash=NULL WHERE id=?').bind(id).run();
                return json({ ok: true });
            }
            if (action === 'surprise' && m === 'POST') {
                const b = await body(r);
                await db().prepare('UPDATE races SET surprise=?,version=version+1 WHERE id=?').bind(b.enabled ? 1 : 0, id).run();
                return json({ ok: true });
            }
            if (action === 'device' && m === 'POST') {
                const b = await body(r);
                await rate(r, 'claim', 10);
                const code = text(b.code, 8, 8);
                if (!/^\d{8}$/.test(code))
                    throw new HttpError(400, 'El código tiene ocho cifras.');
                const result = await db().prepare('UPDATE devices SET owner=?,race=?,code_hash=NULL,expires=? WHERE code_hash=? AND owner IS NULL AND expires>?').bind(race.owner, id, Date.now() + 180 * 86400000, await hash(code), Date.now()).run();
                if (!result.meta.changes)
                    throw new HttpError(400, 'Código caducado o no disponible.');
                return json({ ok: true });
            }
        }
        const msgRoute = p.match(/^\/api\/messages\/([a-f0-9-]+)(?:\/(audio))?$/);
        if (msgRoute) {
            const msg = await db().prepare('SELECT * FROM messages WHERE id=?').bind(msgRoute[1]).first<any>();
            if (!msg)
                throw new HttpError(404, 'Mensaje no encontrado.');
            await owned(r, msg.race);
            if (msgRoute[2] === 'audio' && m === 'GET')
                return audio(msg.object_key);
            if (!msgRoute[2] && m === 'DELETE') {
                await db().batch([db().prepare('DELETE FROM messages WHERE id=?').bind(msg.id), db().prepare('UPDATE races SET version=version+1 WHERE id=?').bind(msg.race)]);
                await bucket().delete(msg.object_key);
                return json({ ok: true });
            }
        }
        if (p === '/api/invitation' && m === 'GET') {
            await rate(r, 'invite', 120);
            const race = await invitation(r);
            return json({ name: race.name, date: race.date, meters: race.meters });
        }
        if (p === '/api/invitation/messages' && m === 'POST') {
            await rate(r, 'upload', 10);
            const race = await invitation(r), name = text(decodeURIComponent(r.headers.get('x-sender-name') || ''), 1, 60), meters = Number(r.headers.get('x-meters'));
            if (!Number.isInteger(meters) || meters < 0 || meters > race.meters || r.headers.get('x-consent') !== 'yes')
                throw new HttpError(400, 'Revisa el kilómetro y la autorización para compartir el audio.');
            const proposed = r.headers.get('x-upload-id');
            const id = proposed && /^[a-f0-9-]{36}$/.test(proposed) ? proposed : crypto.randomUUID(), key = 'audio/' + race.id + '/' + id + '.wav';
            const existing = await db().prepare('SELECT race,ready FROM messages WHERE id=?').bind(id).first<any>();
            if (existing) {
                if (existing.race === race.id && existing.ready)
                    return json({ ok: true, id });
                throw new HttpError(409, 'El envío sigue en curso. Espera unos segundos y vuelve a intentarlo.');
            }
            const prepared = prepareWav(await bounded(r, MAX_BYTES));
            const sha = await hash(prepared.buffer);
            // Límite conservador para validar primero la memoria del proveedor del reloj.
            const result = await db().prepare('INSERT INTO messages(id,race,name,meters,duration,bytes,object_key,sha,created) SELECT ?,?,?,?,?,?,?,?,? WHERE (SELECT count(*) FROM messages WHERE race=?)<30 AND EXISTS(SELECT 1 FROM races WHERE id=? AND open=1 AND invite_hash=?)').bind(id, race.id, name, meters, prepared.duration, prepared.buffer.byteLength, key, sha, Date.now(), race.id, race.id, await hash(token(r))).run();
            if (!result.meta.changes)
                throw new HttpError(409, 'La invitación está cerrada o la carrera ya tiene 30 mensajes.');
            try {
                await bucket().put(key, prepared.buffer, { httpMetadata: { contentType: 'audio/wav' } });
                const commit = await db().prepare('UPDATE messages SET ready=1 WHERE id=? AND EXISTS(SELECT 1 FROM races WHERE id=? AND open=1 AND invite_hash=?)').bind(id, race.id, await hash(token(r))).run();
                if (!commit.meta.changes)
                    throw new HttpError(409, 'La invitación se ha cerrado durante el envío.');
                await db().prepare('UPDATE races SET version=version+1 WHERE id=?').bind(race.id).run();
            }
            catch (error) {
                await db().prepare('DELETE FROM messages WHERE id=?').bind(id).run();
                await bucket().delete(key);
                throw error;
            }
            return json({ ok: true, id }, 201);
        }
        if (p === '/api/device/pair' && m === 'POST') {
            await rate(r, 'pair', 5);
            await db().prepare('DELETE FROM devices WHERE expires<?').bind(Date.now()).run();
            const secret = random(), code = String(crypto.getRandomValues(new Uint32Array(1))[0] % 100000000).padStart(8, '0');
            await db().prepare('INSERT INTO devices(id,token_hash,code_hash,expires) VALUES(?,?,?,?)').bind(crypto.randomUUID(), await hash(secret), await hash(code), Date.now() + 600000).run();
            return json({ token: secret, code, expiresIn: 600 });
        }
        if (p === '/api/device/package' && m === 'GET') {
            const d = await device(r);
            if (!d.race)
                return json({ status: 'pending' });
            const race = await db().prepare('SELECT * FROM races WHERE id=? AND owner=?').bind(d.race, d.owner).first<any>();
            if (!race)
                throw new HttpError(404, 'La carrera ya no está disponible.');
            const rows = (await db().prepare('SELECT id,name,meters,duration,sha FROM messages WHERE race=? AND ready=1 ORDER BY meters,created,id').bind(race.id).all<any>()).results;
            if (!rows.length)
                return json({ status: 'empty', name: race.name });
            return json({ status: 'ready', raceId: race.id, name: race.name, version: race.version, files: [{ id: 'wait', url: u.origin + '/wait.mp3', encoding: 'mp3', meters: 0 }, ...rows.map(row => ({ id: row.id, url: u.origin + '/api/device/audio/' + row.id, encoding: 'wav', meters: row.meters, sha: row.sha, title: race.surprise ? 'Una voz de los tuyos' : row.name }))] });
        }
        const deviceAudio = p.match(/^\/api\/device\/audio\/([a-f0-9-]+)$/);
        if (deviceAudio && m === 'GET') {
            const d = await device(r);
            const row = await db().prepare('SELECT m.object_key FROM messages m JOIN races r ON m.race=r.id WHERE m.id=? AND m.race=? AND r.owner=? AND m.ready=1').bind(deviceAudio[1], d.race, d.owner).first<any>();
            if (!row)
                throw new HttpError(404, 'Audio no disponible.');
            return audio(row.object_key);
        }
        throw new HttpError(404, 'No encontrado.');
    }
    catch (error) {
        if (error instanceof HttpError)
            return json({ error: error.message }, error.status);
        if (error instanceof AudioError)
            return json({ error: error.message }, 400);
        console.error('ATULADO API failure', error instanceof Error ? error.name : 'unknown');
        return json({ error: 'No se pudo completar la operación. Inténtalo de nuevo.' }, 500);
    }
}
