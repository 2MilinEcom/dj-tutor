import test from 'node:test';
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {once} from 'node:events';
import {mint} from './security.mjs';

test('HTTP service authenticates, rejects Spotify input and reports unconfigured AI',async()=>{
 const secret='integration-test-only'.repeat(3);
 const child=spawn(process.execPath,['server.mjs'],{cwd:new URL('.',import.meta.url),env:{PATH:process.env.PATH,SESSION_SIGNING_SECRET:secret,PORT:'18787',HOST:'127.0.0.1'},stdio:['ignore','pipe','pipe']});
 try {
  let timeout;
  try {await Promise.race([once(child.stdout,'data'),once(child,'exit').then(()=>{throw new Error('Server exited before ready')}),new Promise((_,reject)=>{timeout=setTimeout(()=>reject(new Error('Server did not start')),5000)})]);} finally {clearTimeout(timeout);}
  const base='http://127.0.0.1:18787';
  assert.equal((await fetch(base+'/health')).status,200);
  assert.equal((await fetch(base+'/coach',{method:'POST'})).status,401);
  const headers={'Authorization':'Bearer '+mint('tester',secret),'Content-Type':'application/json'};
  const body={source:'spotify',a:{bpm:120,key:'C major'},b:{bpm:124,key:'A minor'},mode:'transition'};
  assert.equal((await fetch(base+'/coach',{method:'POST',headers,body:JSON.stringify(body)})).status,400);
  body.source='local';
  assert.equal((await fetch(base+'/coach',{method:'POST',headers,body:JSON.stringify(body)})).status,503);
  assert.equal((await fetch(base+'/teach',{method:'POST'})).status,401);
  const teaching={question:'Explain cue points',topic:'controls',step:0,feedback:'question',history:[]};
  assert.equal((await fetch(base+'/teach',{method:'POST',headers,body:JSON.stringify({...teaching,audio:'forbidden'})})).status,400);
  assert.equal((await fetch(base+'/teach',{method:'POST',headers,body:JSON.stringify(teaching)})).status,503);
 } finally {if(child.exitCode===null){const exited=once(child,'exit');child.kill();await exited;}}
});
