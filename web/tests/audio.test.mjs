import {test} from 'node:test';
import assert from 'node:assert/strict';
import {prepareWav} from '../lib/audio.mjs';
import {wav} from './fixtures.mjs';

test('normaliza y conserva duración verificable',()=>{const r=prepareWav(wav(2));assert.equal(r.duration,2000);assert.equal(r.buffer.byteLength,176444);assert.equal(new DataView(r.buffer).getUint16(22,true),1);});
test('rechaza duración demasiado corta o larga',()=>{assert.throws(()=>prepareWav(wav(.5)));assert.throws(()=>prepareWav(wav(61)));});
test('rechaza silencio y cabecera truncada',()=>{const b=wav();new Uint8Array(b).fill(0,44);assert.throws(()=>prepareWav(b));assert.throws(()=>prepareWav(wav().slice(0,80)));});
test('rechaza frecuencia falsa, estéreo y chunks corruptos',()=>{for(const [offset,value] of [[24,48000],[22,2],[40,0xffffffff]]){const b=wav();new DataView(b).setUint32(offset,value,true);assert.throws(()=>prepareWav(b));}});
