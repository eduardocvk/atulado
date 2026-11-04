'use client';
import { useEffect, useRef, useState, type FormEvent } from 'react';
type Race = {
    id: string;
    name: string;
    date: string;
    meters: number;
    version: number;
    open: number;
    surprise: number;
};
type Message = {
    id: string;
    name: string;
    meters: number;
    duration: number;
    ready: number;
};
async function api(path: string, options: RequestInit = {}): Promise<any> { const response = await fetch(path, { ...options, cache: 'no-store' }); const body: any = await response.json(); if (!response.ok)
    throw new Error(body.error || 'No se pudo completar la operación.'); return body; }
const post = (body?: unknown) => ({ method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body || {}) });
const km = (meters: number) => (meters / 1000).toLocaleString('es-ES', { maximumFractionDigits: 3 });
function Chrome({ children }: {
    children: React.ReactNode;
}) { return <><header><a className="brand" href="/">a tu lado.</a><nav><a href="/">Mis carreras</a><a href="/downloads/atulado-fr970-v5.zip">Descargar Garmin</a><a href="/concepto.html">Ver el concepto</a></nav></header><main className="shell">{children}</main><footer>Las voces de los tuyos, kilómetro a kilómetro. Primera versión para pruebas de entrenamiento.<br />Los audios se guardan hasta que el corredor los borra. Solo compártelos mediante una invitación de confianza.</footer></>; }
export default function Dashboard({ signedIn }: {
    signedIn: boolean;
}) {
    const [races, setRaces] = useState<Race[]>([]), [selected, setSelected] = useState<Race | null>(null), [messages, setMessages] = useState<Message[]>([]), [error, setError] = useState(''), [notice, setNotice] = useState(''), [busy, setBusy] = useState(false), [link, setLink] = useState(''), [revealed, setRevealed] = useState<Record<string, boolean>>({});
    const selection = useRef(0);
    async function load() { const data = await api('/api/races'); setRaces(data); return data; }
    useEffect(() => { if (signedIn)
        load().catch(e => setError(e.message)); }, [signedIn]);
    async function choose(race: Race) { const seq = ++selection.current; setSelected(race); setMessages([]); setLink(''); setRevealed({}); setError(''); try {
        const list = await api('/api/races/' + race.id + '/messages');
        if (seq === selection.current)
            setMessages(list);
    }
    catch (e: any) {
        if (seq === selection.current)
            setError(e.message);
    } }
    async function act(fn: () => Promise<void>) { setBusy(true); setError(''); setNotice(''); try {
        await fn();
    }
    catch (e: any) {
        setError(e.message);
    }
    finally {
        setBusy(false);
    } }
    async function create(e: FormEvent<HTMLFormElement>) { e.preventDefault(); const f = new FormData(e.currentTarget); await act(async () => { const result = await api('/api/races', post({ name: f.get('name'), date: f.get('date'), km: f.get('km') })); const list = await load(); await choose(list.find((r: Race) => r.id === result.id)); setNotice('Carrera creada. Ya puedes invitar a tu gente.'); }); }
    async function refreshSelected() { if (!selected)
        return; await choose(await api('/api/races/' + selected.id)); await load(); }
    if (!signedIn)
        return <Chrome><div className="eyebrow">Tu próxima línea de salida</div><h1>Los kilómetros son tuyos.<br />El ánimo, de los tuyos.</h1><p className="intro">Recibe las voces de amigos y familia. Elige una carrera y llévalas contigo en el Garmin, incluso sin cobertura.</p><a className="primary" href="/signin-with-chatgpt?return_to=%2F" target="_top">Entrar con ChatGPT</a><div className="hero-art"><div><b>Antes de salir</b><span>Comparte tu enlace. Ellos graban su voz y eligen el kilómetro.</span></div><div><b>Durante la carrera</b><span>Escucha sus mensajes en los auriculares conectados al reloj.</span></div></div></Chrome>;
    return <Chrome><div className="row"><div><div className="eyebrow">Tu equipo de ánimo</div><h1>Una carrera. Muchas voces.</h1></div><a href="/signout-with-chatgpt?return_to=%2F" target="_top">Cerrar sesión</a></div>{error && <p className="error" role="alert">{error}</p>}{notice && <p className="notice" role="status">{notice}</p>}<div className="grid"><aside className="stack"><section className="panel"><h2>Mis carreras</h2>{races.length ? races.map(r => <button className="race-link" key={r.id} aria-pressed={selected?.id === r.id} onClick={() => choose(r)}>{r.name}<span>{r.date} · {km(r.meters)} km</span></button>) : <p className="muted">Tu primera carrera empieza aquí.</p>}</section><section className="panel"><h2>Crear una carrera</h2><form onSubmit={create}><label htmlFor="race-name">Nombre</label><input id="race-name" name="name" minLength={2} maxLength={100} placeholder="Mi próxima maratón" required/><label htmlFor="race-date">Fecha</label><input id="race-date" name="date" type="date" required/><label htmlFor="race-km">Distancia en kilómetros</label><input id="race-km" name="km" type="number" min="0.2" max="1000" step="0.001" defaultValue="42.195" required/><div className="actions"><button disabled={busy}>Crear carrera</button></div></form></section></aside><section className="panel">{selected ? <><div className="row"><h2>{selected.name}</h2><span className="badge">{km(selected.meters)} km</span></div><p className="muted">{messages.length} mensajes recibidos · versión {selected.version}</p><label className="check"><input type="checkbox" checked={!!selected.surprise} disabled={busy} onChange={e => { const enabled = e.target.checked; act(async () => { await api('/api/races/' + selected.id + '/surprise', post({ enabled })); setSelected({ ...selected, surprise: enabled ? 1 : 0 }); }); }}/>Modo sorpresa: ocultar las voces y sus kilómetros</label><div className="actions"><button disabled={busy} onClick={() => act(async () => { const result = await api('/api/races/' + selected.id + '/invite', post()); setLink(result.url); setSelected({ ...selected, open: 1 }); })}>Crear / renovar invitación</button><button className="secondary" disabled={busy} onClick={() => act(refreshSelected)}>Actualizar</button></div><p className="thin muted">Renovar invalida el enlace anterior. Cerrar impide nuevos envíos y conserva los mensajes recibidos.</p>{link && <div className="notice"><a className="linkbox" href={link}>{link}</a><button className="secondary" onClick={() => act(async () => { await navigator.clipboard.writeText(link); setNotice('Enlace copiado.'); })}>Copiar enlace</button></div>}<div className="actions"><button className="secondary" disabled={busy || !selected.open} onClick={() => act(async () => { await api('/api/races/' + selected.id + '/close', post()); setSelected({ ...selected, open: 0 }); setLink(''); setNotice('Invitación cerrada.'); })}>{selected.open ? 'Cerrar invitación' : 'Invitación cerrada'}</button></div><details><summary>Vincular esta carrera al Garmin</summary><p>Abre el proveedor en el reloj y pulsa START para obtener su código. Introdúcelo aquí y vuelve al reloj para sincronizar.</p><form onSubmit={e => { e.preventDefault(); const code = new FormData(e.currentTarget).get('code'); act(async () => { await api('/api/races/' + selected.id + '/device', post({ code })); setNotice('Reloj vinculado. Sincroniza los mensajes desde el Garmin.'); }); }}><label htmlFor="device-code">Código de ocho cifras</label><input id="device-code" name="code" pattern="[0-9]{8}" inputMode="numeric" maxLength={8} minLength={8} required/><div className="actions"><button disabled={busy}>Vincular reloj</button></div></form><p className="thin muted">El código caduca a los diez minutos. La conexión se autoriza solo para esta carrera.</p></details><div className="actions"><button className="danger" disabled={busy} onClick={() => { if (window.confirm("¿Borrar esta carrera, sus mensajes y la vinculación de sus relojes?"))
        act(async () => { await api("/api/races/" + selected.id, { method: "DELETE" }); selection.current++; setSelected(null); setMessages([]); setLink(""); await load(); setNotice("Carrera y mensajes borrados."); }); }}>Borrar carrera</button></div><h3 style={{ marginTop: 28 }}>Voces que te esperan</h3>{!messages.length && <p className="empty">Comparte una invitación para recibir el primer mensaje.</p>}{messages.map(message => <article className="message" key={message.id}><div className="row"><div><h3>{selected.surprise && !revealed[message.id] ? 'Una voz de los tuyos' : message.name}</h3><small>{selected.surprise && !revealed[message.id] ? 'Kilómetro sorpresa' : 'Km ' + km(message.meters)} · {(message.duration / 1000).toFixed(0)} s · {message.ready ? 'Preparado' : 'Procesando'}</small></div><button className="secondary" disabled={busy || !message.ready} onClick={() => setRevealed({ ...revealed, [message.id]: !revealed[message.id] })}>{revealed[message.id] ? 'Ocultar' : 'Escuchar'}</button></div>{revealed[message.id] && <audio controls preload="none" src={'/api/messages/' + message.id + '/audio'}/>}<button className="danger" disabled={busy} onClick={() => { if (window.confirm('¿Borrar definitivamente este mensaje?'))
        act(async () => { await api('/api/messages/' + message.id, { method: 'DELETE' }); await refreshSelected(); }); }}>Borrar mensaje</button></article>)}</> : <div className="empty">Selecciona una carrera o crea la primera.</div>}</section></div></Chrome>;
}
async function toWav(blob: Blob) { const audio = new AudioContext(); try {
    const decoded = await audio.decodeAudioData(await blob.arrayBuffer());
    if (decoded.duration < 1 || decoded.duration > 60)
        throw new Error('El mensaje debe durar entre 1 y 60 segundos.');
    const offline = new OfflineAudioContext(1, Math.ceil(decoded.duration * 44100), 44100);
    const source = offline.createBufferSource();
    source.buffer = decoded;
    source.connect(offline.destination);
    source.start();
    const rendered = await offline.startRendering();
    const samples = rendered.getChannelData(0), data = new ArrayBuffer(44 + samples.length * 2), v = new DataView(data);
    for (const [offset, tag] of [[0, 'RIFF'], [8, 'WAVE'], [12, 'fmt '], [36, 'data']] as [
        number,
        string
    ][])
        for (let i = 0; i < 4; i++)
            v.setUint8(offset + i, tag.charCodeAt(i));
    v.setUint32(4, data.byteLength - 8, true);
    v.setUint32(16, 16, true);
    v.setUint16(20, 1, true);
    v.setUint16(22, 1, true);
    v.setUint32(24, 44100, true);
    v.setUint32(28, 88200, true);
    v.setUint16(32, 2, true);
    v.setUint16(34, 16, true);
    v.setUint32(40, samples.length * 2, true);
    samples.forEach((s, i) => v.setInt16(44 + i * 2, Math.round(Math.max(-1, Math.min(1, s)) * 32767), true));
    return new Blob([data], { type: 'audio/wav' });
}
finally {
    await audio.close();
} }
export function Sender() {
    const [race, setRace] = useState<{
        name: string;
        date: string;
        meters: number;
    } | null>(null), [error, setError] = useState(''), [status, setStatus] = useState(''), [recording, setRecording] = useState(false), [seconds, setSeconds] = useState(0), [busy, setBusy] = useState(false), [preview, setPreview] = useState(''), [audio, setAudio] = useState<Blob | null>(null), [sent, setSent] = useState(false);
    const secret = useRef(''), recorder = useRef<MediaRecorder | null>(null), stream = useRef<MediaStream | null>(null), stopTimer = useRef<ReturnType<typeof setTimeout> | null>(null), counter = useRef<ReturnType<typeof setInterval> | null>(null), uploadId = useRef('');
    function stop() { if (recorder.current?.state === 'recording')
        recorder.current.stop(); if (stopTimer.current)
        clearTimeout(stopTimer.current); if (counter.current)
        clearInterval(counter.current); stream.current?.getTracks().forEach(t => t.stop()); setRecording(false); }
    useEffect(() => { secret.current = location.hash.slice(1); api('/api/invitation', { headers: { Authorization: 'Bearer ' + secret.current } }).then(setRace).catch(e => setError(e.message)); return () => { if (stopTimer.current)
        clearTimeout(stopTimer.current); if (counter.current)
        clearInterval(counter.current); stream.current?.getTracks().forEach(t => t.stop()); }; }, []);
    useEffect(() => () => { if (preview)
        URL.revokeObjectURL(preview); }, [preview]);
    async function prepare(blob: Blob) { setBusy(true); setError(''); setStatus('Preparando tu voz…'); setSent(false); try {
        const wav = await toWav(blob);
        setAudio(wav);
        uploadId.current = crypto.randomUUID();
        setPreview(URL.createObjectURL(wav));
        setStatus('Escúchalo antes de enviarlo.');
    }
    catch (e: any) {
        setError(e.message);
        setAudio(null);
        setPreview('');
        setStatus('');
    }
    finally {
        setBusy(false);
    } }
    async function record() { setError(''); try {
        if (!navigator.mediaDevices?.getUserMedia || typeof MediaRecorder === 'undefined')
            throw new Error('Este navegador no permite grabar. Puedes subir un archivo de audio.');
        stream.current = await navigator.mediaDevices.getUserMedia({ audio: true });
        const rec = new MediaRecorder(stream.current);
        recorder.current = rec;
        const chunks: Blob[] = [];
        rec.ondataavailable = e => { if (e.data.size)
            chunks.push(e.data); };
        rec.onstop = () => { stream.current?.getTracks().forEach(t => t.stop()); prepare(new Blob(chunks, { type: rec.mimeType })); };
        rec.start();
        setSeconds(0);
        setRecording(true);
        setAudio(null);
        setPreview('');
        setStatus('Grabando. Se detendrá a los 60 segundos.');
        counter.current = setInterval(() => setSeconds(s => s + 1), 1000);
        stopTimer.current = setTimeout(stop, 60000);
    }
    catch (e: any) {
        stream.current?.getTracks().forEach(t => t.stop());
        setError(e.name === 'NotAllowedError' ? 'Activa el permiso de micrófono o sube un archivo de audio.' : e.message);
    } }
    async function send(e: FormEvent<HTMLFormElement>) { e.preventDefault(); if (!audio)
        return; const f = new FormData(e.currentTarget); setBusy(true); setError(''); setStatus('Enviando tu mensaje…'); try {
        await api('/api/invitation/messages', { method: 'POST', headers: { Authorization: 'Bearer ' + secret.current, 'Content-Type': 'audio/wav', 'X-Sender-Name': encodeURIComponent(String(f.get('name'))), 'X-Meters': String(Math.round(Number(f.get('km')) * 1000)), 'X-Consent': f.get('consent') ? 'yes' : 'no', 'X-Upload-Id': uploadId.current }, body: audio });
        setSent(true);
        setStatus('Tu mensaje está guardado y preparado para la carrera.');
    }
    catch (e: any) {
        setError(e.message);
        setStatus('No se ha confirmado el envío. Puedes volver a intentarlo.');
    }
    finally {
        setBusy(false);
    } }
    return <Chrome><div className="sender"><div className="eyebrow">Tu voz. Su momento.</div><h1>Un poco de ti.<br />Mucho ánimo.</h1>{race ? <><p className="intro">Acompaña a tu gente en <strong>{race.name}</strong>.</p><span className="badge">{km(race.meters)} km · {race.date}</span><form className="panel" onSubmit={send} style={{ marginTop: 24 }}><label htmlFor="sender-name">Tu nombre o apodo</label><input id="sender-name" name="name" required maxLength={60} autoComplete="given-name" disabled={sent}/><label htmlFor="sender-km">¿En qué kilómetro quieres sonar?</label><input id="sender-km" name="km" type="number" min="0" max={race.meters / 1000} step="0.001" placeholder="Por ejemplo, 30" required disabled={sent}/><div className="record"><h3>Graba hasta un minuto</h3><div className="timer">{recording ? '00:' + String(seconds).padStart(2, '0') : audio ? 'Tu voz está lista' : '00:00'}</div><button type="button" disabled={busy || sent} onClick={recording ? stop : record}>{recording ? 'Detener grabación' : audio ? 'Grabar de nuevo' : 'Grabar mi mensaje'}</button>{preview && <audio controls src={preview} style={{ width: '100%', marginTop: 15 }}/>}</div><label htmlFor="audio-file">También puedes subir un audio</label><input id="audio-file" type="file" accept="audio/*" disabled={busy || recording || sent} onChange={e => { const file = e.target.files?.[0]; if (file) {
        if (file.size > 20 * 1024 * 1024)
            setError('El archivo no puede superar 20 MB.');
        else
            prepare(file);
    } }}/><label className="check"><input type="checkbox" name="consent" required disabled={sent}/>Quiero compartir esta grabación con el corredor para su carrera. Podrá escucharla, descargarla y borrarla.</label><button disabled={busy || recording || !audio || sent}>{sent ? 'Mensaje enviado' : busy ? 'Preparando…' : 'Enviar mi ánimo'}</button><p className="thin muted">No necesitas una cuenta. La grabación se guarda hasta que el corredor la borra. Evita incluir información sensible.</p></form></> : !error && <p role="status">Abriendo invitación…</p>}{error && <p className="error" role="alert">{error}</p>}{status && <p className="notice" role="status">{status}</p>}</div></Chrome>;
}
