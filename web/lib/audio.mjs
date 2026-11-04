export const MAX_BYTES = 5_400_044;
export class AudioError extends Error {}
// Se normaliza y reconstruye un WAV PCM canónico; no se conserva metadato externo.
export function prepareWav(buffer) {
  if (buffer.byteLength > MAX_BYTES || buffer.byteLength < 46) throw new AudioError('El audio debe durar entre 1 y 60 segundos.');
  const v = new DataView(buffer), tag = (p) => String.fromCharCode(...new Uint8Array(buffer,p,4));
  if (tag(0) !== 'RIFF' || tag(8) !== 'WAVE' || v.getUint32(4,true)+8 !== buffer.byteLength) throw new AudioError('Archivo WAV no válido.');
  let data=-1, size=0, format=false;
  for (let p=12;p+8<=buffer.byteLength;) {
    const n=v.getUint32(p+4,true); if(p+8+n>buffer.byteLength) throw new AudioError('Audio incompleto.');
    if(tag(p)==='fmt ') {
      if(n<16 || v.getUint16(p+8,true)!==1 || v.getUint16(p+10,true)!==1 || v.getUint32(p+12,true)!==44100 || v.getUint32(p+16,true)!==88200 || v.getUint16(p+20,true)!==2 || v.getUint16(p+22,true)!==16) throw new AudioError('Usa la grabadora o convierte el archivo desde esta página.');
      format=true;
    }
    if(tag(p)==='data') { if(data!==-1) throw new AudioError('Audio no válido.'); data=p+8;size=n; }
    p+=8+n+(n%2);
  }
  if(!format || data<0 || size%2 || size<88200 || size>60*88200) throw new AudioError('El audio debe durar entre 1 y 60 segundos.');
  const out=new ArrayBuffer(size+44), w=new DataView(out);
  for(const [p,s] of [[0,'RIFF'],[8,'WAVE'],[12,'fmt '],[36,'data']]) for(let i=0;i<4;i++) w.setUint8(p+i,s.charCodeAt(i));
  w.setUint32(4,size+36,true);w.setUint32(16,16,true);w.setUint16(20,1,true);w.setUint16(22,1,true);w.setUint32(24,44100,true);w.setUint32(28,88200,true);w.setUint16(32,2,true);w.setUint16(34,16,true);w.setUint32(40,size,true);
  let peak=0;for(let p=0;p<size;p+=2)peak=Math.max(peak,Math.abs(v.getInt16(data+p,true)));
  if(peak<20)throw new AudioError('No se detecta voz. Graba de nuevo más cerca del micrófono.');
  const gain=Math.min(4,26000/peak);
  for(let p=0;p<size;p+=2)w.setInt16(p+44,Math.max(-32768,Math.min(32767,Math.round(v.getInt16(data+p,true)*gain))),true);
  return {buffer:out,duration:Math.round(size/88.2)};
}
