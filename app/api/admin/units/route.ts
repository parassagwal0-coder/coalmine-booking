import {NextRequest} from 'next/server';import {staff,reply,publicError} from '@/lib/server';
export async function GET(req:NextRequest){try{const {client}=await staff(req);const {data,error}=await client.from('units').select('*').order('id');if(error)throw Error('Query failed');return reply({units:data});}catch(e){return reply({error:publicError(e)},403)}}
