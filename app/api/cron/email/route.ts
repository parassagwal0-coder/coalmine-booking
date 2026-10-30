import {NextRequest} from 'next/server';import {timingSafeEqual} from 'node:crypto';import {deliverEmails} from '@/lib/email';import {reply} from '@/lib/server';
export const maxDuration=60;
export async function GET(req:NextRequest){const secret=process.env.CRON_SECRET,a=Buffer.from(req.headers.get('authorization')||''),b=Buffer.from(`Bearer ${secret}`);if(!secret||a.length!==b.length||!timingSafeEqual(a,b))return reply({error:'Unauthorized'},401);try{return reply(await deliverEmails(3));}catch{return reply({error:'Email queue processing failed.'},503)}}
