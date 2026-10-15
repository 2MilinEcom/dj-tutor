import { createHmac, timingSafeEqual } from 'node:crypto';
export function mint(subject, secret, now = Date.now()) {
  const body = Buffer.from(JSON.stringify({sub:subject,exp:Math.floor(now/1000)+3600})).toString('base64url');
  return body+'.'+createHmac('sha256',secret).update(body).digest('base64url');
}
export function verify(token, secret, now = Date.now()) {
  if (!secret || secret.length<32 || typeof token!=='string') return null;
  const parts=token.split('.'); if(parts.length!==2) return null;
  const expected=createHmac('sha256',secret).update(parts[0]).digest();
  const actual=Buffer.from(parts[1],'base64url');
  if(actual.length!==expected.length || !timingSafeEqual(actual,expected)) return null;
  try {const p=JSON.parse(Buffer.from(parts[0],'base64url'));return typeof p.sub==='string' && p.sub.length<=100 && Number.isFinite(p.exp) && p.exp>now/1000 && p.exp<=now/1000+3660 ? p.sub : null;}catch{return null;}
}
const keys=new Set(['Unknown', ...['C','C♯','D','E♭','E','F','F♯','G','A♭','A','B♭','B'].flatMap(k=>[k+' major',k+' minor'])]);
export function validate(body) {
  if(!body || Object.keys(body).sort().join(',')!=='a,b,mode,source' || body.source!=='local' || !['transition','mashup'].includes(body.mode)) return false;
  return [body.a,body.b].every(t=>t && Object.keys(t).sort().join(',')==='bpm,key' && Number.isFinite(t.bpm) && t.bpm>=40 && t.bpm<=240 && keys.has(t.key));
}
export function validPlan(p) {return p && typeof p.title==='string' && p.title.length<200 && Array.isArray(p.steps) && p.steps.length>=1 && p.steps.length<=8 && p.steps.every(s=>typeof s==='string' && s.length<1200) && typeof p.caution==='string' && p.caution.length<1200;}
export class Limiter {
  constructor(){this.buckets=new Map();}
  allow(subject, now=Date.now()) {
    for(const [k,v] of this.buckets) if(now-v.start>=3600000) this.buckets.delete(k);
    const b=this.buckets.get(subject)??{start:now,count:0}; b.count++; this.buckets.set(subject,b); return b.count<=20;
  }
}
