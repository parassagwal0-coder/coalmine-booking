export const maxDuration=60;
import {NextRequest} from 'next/server';import {staff,originCheck,reply,publicError} from '@/lib/server';import {deliverEmails} from '@/lib/email';
export async function POST(req:NextRequest){try{originCheck(req);await staff(req);return reply(await deliverEmails(3));}catch(e){return reply({error:publicError(e)},403)}}
