import {mint} from './security.mjs';
if(!process.env.SESSION_SIGNING_SECRET || process.env.SESSION_SIGNING_SECRET.length<32) throw new Error('Configure server signing secret first');
const subject=process.argv[2]; if(!subject || subject.length>100) throw new Error('Pass a user identifier');
console.log(mint(subject,process.env.SESSION_SIGNING_SECRET));
