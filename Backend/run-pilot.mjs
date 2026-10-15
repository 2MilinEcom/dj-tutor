// Development only: keep provider credentials in the parent environment.
import {readFileSync,writeFileSync} from 'node:fs';
import {randomBytes} from 'node:crypto';
import {mint} from './security.mjs';
const statePath='/private/tmp/djtut-coach-session.json';
let state;
try{state=JSON.parse(readFileSync(statePath,'utf8'));}catch{state={secret:randomBytes(48).toString('base64url')};}
state.token=mint('djtut-private-pilot',state.secret);
writeFileSync(statePath,JSON.stringify(state),{mode:0o600});
process.env.SESSION_SIGNING_SECRET=state.secret;
process.env.DAILY_REQUEST_LIMIT='50';
if(!process.env.OPENAI_API_KEY){throw new Error('The existing API key is not available to this process.');}
await import('./server.mjs');
