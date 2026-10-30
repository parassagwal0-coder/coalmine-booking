import {createClient} from '@supabase/supabase-js';
export function browserClient(){const url=process.env.NEXT_PUBLIC_SUPABASE_URL,key=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;if(!url||!key)throw Error('Supabase public configuration is missing. Configure the hosting environment and rebuild.');return createClient(url,key);}
