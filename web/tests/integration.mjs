import assert from 'node:assert/strict';
import {wav as fixture} from './fixtures.mjs';
const origin='http://127.0.0.1:5173';
const auth=await fetch(origin+'/signin-with-chatgpt?return_to=/',{redirect:'manual'});
const cookie=auth.headers.get('set-cookie')?.split(';')[0];
assert.ok(cookie,'El preview debe proporcionar el acceso local de pruebas');
let count=0,raceId;
async function request(path,{status=200,owner=false,token,method='GET',data,body,headers={}}={}){
 const r=await fetch(origin+path,{method,headers:{...(owner?{Cookie:cookie}:{}),...(token?{Authorization:'Bearer '+token}:{}),...(data?{'Content-Type':'application/json'}:{}),...headers},body:data?JSON.stringify(data):body});
 assert.equal(r.status,status,`${method} ${path}: ${await r.clone().text()}`);count++;return r;
}
try{
 await request('/api/races',{status:401});
 const race=await (await request('/api/races',{owner:true,method:'POST',status:201,data:{name:'Prueba local desechable',date:'2026-11-04',km:.5}})).json();raceId=race.id;
 await request('/api/races/'+raceId,{status:401});
 await request('/api/races',{owner:true,method:'POST',status:400,data:{name:'Fecha inválida',date:'2026-02-31',km:42}});
 const invitation=await (await request('/api/races/'+raceId+'/invite',{owner:true,method:'POST'})).json();const invite=invitation.url.split('#')[1];
 await request('/api/invitation',{token:invite});
 const wav=new Uint8Array(fixture(2));const uploadId=crypto.randomUUID();
 const headers={'Content-Type':'audio/wav','X-Sender-Name':'Prueba','X-Meters':'200','X-Consent':'yes','X-Upload-Id':uploadId};
 await request('/api/invitation/messages',{token:invite,method:'POST',headers:{...headers,'X-Meters':'501'},body:wav,status:400});
 await request('/api/invitation/messages',{token:invite,method:'POST',headers,body:wav,status:201});
 await request('/api/invitation/messages',{token:invite,method:'POST',headers,body:wav});
 const messages=await (await request('/api/races/'+raceId+'/messages',{owner:true})).json();assert.equal(messages.length,1);assert.equal(messages[0].meters,200);
 await request('/api/messages/'+uploadId+'/audio',{status:401});
 const audio=await request('/api/messages/'+uploadId+'/audio',{owner:true});assert.equal(audio.headers.get('content-type'),'audio/wav');assert.ok((await audio.arrayBuffer()).byteLength>44);
 const pair=await (await request('/api/device/pair',{method:'POST'})).json();
 const pending=await (await request('/api/device/package',{token:pair.token})).json();assert.equal(pending.status,'pending');
 await request('/api/races/'+raceId+'/device',{owner:true,method:'POST',data:{code:pair.code}});
 const manifest=await (await request('/api/device/package',{token:pair.token})).json();assert.equal(manifest.files.length,2);assert.equal(manifest.files[1].meters,200);
 await request('/api/device/audio/'+uploadId,{token:pair.token});
 await request('/api/device/package',{token:'f'.repeat(64),status:401});
 await request('/api/races/'+raceId+'/close',{owner:true,method:'POST'});
 await request('/api/invitation',{token:invite,status:404});
 await request('/api/messages/'+uploadId,{owner:true,method:'DELETE'});
 await request('/api/device/audio/'+uploadId,{token:pair.token,status:404});
 console.log(`Integración local: ${count} respuestas verificadas; autenticación, carga real, idempotencia, caché, vinculación, cierre y borrado correctos.`);
}finally{if(raceId)await request('/api/races/'+raceId,{owner:true,method:'DELETE'});}
