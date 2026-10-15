import {createServer} from 'node:http';
import {verify,validate,validPlan,Limiter} from './security.mjs';
import {teachingSchema,validateTeaching,validTeaching,teachingInstructions,teachingContext} from './teaching.mjs';
const secret=process.env.SESSION_SIGNING_SECRET;
if(!secret || secret.length<32) throw new Error('Set a server-only SESSION_SIGNING_SECRET with at least 32 characters.');
const limiter=new Limiter(); let dailyCount=0, day='';
const schema={type:'object',additionalProperties:false,properties:{title:{type:'string'},steps:{type:'array',items:{type:'string'}},caution:{type:'string'}},required:['title','steps','caution']};
const reply=(res,status,obj)=>{res.writeHead(status,{'Content-Type':'application/json','Cache-Control':'no-store'});res.end(JSON.stringify(obj));};
export const server=createServer(async(req,res)=>{
  if(req.url==='/health' && req.method==='GET') return reply(res,200,{ok:true});
  if(!['/coach','/teach'].includes(req.url) || req.method!=='POST') return reply(res,404,{error:'Not found'});
  const teaching=req.url==='/teach';
  const sub=verify(req.headers.authorization?.replace(/^Bearer /,''),secret);
  if(!sub) return reply(res,401,{error:'Valid session required'});
  if(!limiter.allow(sub)) return reply(res,429,{error:'Hourly session limit reached'});
  if(!req.headers['content-type']?.startsWith('application/json')) return reply(res,415,{error:'JSON required'});
  const today=new Date().toISOString().slice(0,10); if(today!==day){day=today;dailyCount=0;}
  if(dailyCount>=Number(process.env.DAILY_REQUEST_LIMIT??200)) return reply(res,429,{error:'Daily service budget reached'});
  try {
    let size=0,chunks=[];
    for await(const c of req){size+=c.length;if(size>(teaching?8192:4096)){reply(res,413,{error:'Request too large'});req.destroy();return;}chunks.push(c);}
    const body=JSON.parse(Buffer.concat(chunks));
    if(!(teaching?validateTeaching(body):validate(body))) return reply(res,400,{error:teaching?'Invalid teaching question':'Only local BPM/key and lesson mode accepted'});
    if(!process.env.OPENAI_API_KEY) return reply(res,503,{error:'Cloud AI is not configured'});
    dailyCount++;
    const upstream=await fetch('https://api.openai.com/v1/responses',{method:'POST',signal:AbortSignal.timeout(25000),headers:{Authorization:`Bearer ${process.env.OPENAI_API_KEY}`,'Content-Type':'application/json'},body:JSON.stringify({model:process.env.OPENAI_MODEL??'gpt-4.1-mini',store:false,max_output_tokens:teaching?900:1200,instructions:teaching?teachingInstructions:'You are a DJ teacher. Provide a practical 16-bar transition or mashup drill for permitted local audio on the DJ TUT iPad board. Teach these actual controls: Deck A/B play/pause, SYNC (estimated tempo and beat phase, not a continuous lock), EDIT GRID (BPM and beat-one origin), jog drag (seeks, not vinyl scratching), HOT CUES (tap set/launch; hold replace), LOOPS, BEAT JUMP, LOW/MID/HIGH EQ and KILL, FILTER (low/high pass), ECHO, REVERB, channel volume, equal-power crossfade, MASTER, and REC/Share WAV. Explain timing in beats and bars with a concrete 8-bar phrase entry. Choose a small subset of controls appropriate to the task, never invent stem separation, headphone cueing, or automatic phrase detection. Inputs are estimates, mention half/double-time and uncertain keys. Do not claim to listen to audio. No Spotify content. Never promise automatic beat alignment. Return 4-6 concise ordered steps and one caution. Avoid unsafe volume guidance.',input:JSON.stringify(teaching?teachingContext(body):body),text:{format:{type:'json_schema',name:teaching?'djay_teacher':'dj_plan',strict:true,schema:teaching?teachingSchema:schema}}})});
    if(!upstream.ok) return reply(res,502,{error:'AI provider unavailable'});
    const data=await upstream.json();
    if(data.status!=='completed') return reply(res,502,{error:'AI response incomplete'});
    const output=data.output?.flatMap(x=>x.content??[]).filter(x=>x.type==='output_text').map(x=>x.text).join('');
    const plan=JSON.parse(output);if(!(teaching?validTeaching(plan):validPlan(plan))) return reply(res,502,{error:'Invalid coaching response'});
    reply(res,200,plan);
  } catch {reply(res,502,{error:'Coach request failed'});}
});
server.requestTimeout=30000;server.headersTimeout=10000;
server.listen(Number(process.env.PORT??8787),process.env.HOST??'127.0.0.1',()=>console.log('DJ Tutor coach listening'));
