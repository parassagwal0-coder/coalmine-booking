-- Run once in a NEW Supabase project. Never use this to overwrite existing data.
begin;
create extension if not exists btree_gist;
create table public.staff_members(user_id uuid primary key references auth.users(id) on delete cascade);
create table public.settings(id integer primary key check(id=1),accepting_bookings boolean not null default false,season_start date,season_end date,tax_bps integer check(tax_bps between 0 and 10000),tax_confirmed boolean not null default false,policy text not null default '',timezone text not null default 'America/Whitehorse',check_in text not null default '',check_out text not null default '',check(season_end is null or season_end>season_start));
insert into public.settings(id) values(1);
create table public.units(id text primary key,label text not null,type text not null check(type in('powered','unpowered','tent','cabin')),nightly_cents integer not null check(nightly_cents>=0),active boolean not null default true);
insert into public.units(id,label,type,nightly_cents)
 select 'P'||lpad(n::text,2,'0'),'Powered RV '||n,'powered',4700 from generate_series(1,5)n union all
 select 'U'||lpad(n::text,2,'0'),'Unpowered RV '||n,'unpowered',3000 from generate_series(1,5)n union all
 select 'T'||lpad(n::text,2,'0'),'Tent '||n,'tent',3100 from generate_series(1,30)n union all
 select 'C'||lpad(n::text,2,'0'),'Cabin '||n,'cabin',13695 from generate_series(1,5)n;
create table public.bookings(id uuid primary key default gen_random_uuid(),reference text not null unique default 'CM-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,12)),request_id uuid not null unique,unit_id text not null references public.units(id),type text not null,guest_name text not null check(length(guest_name) between 1 and 100),email text not null check(length(email)<=254),arrival date not null,departure date not null,nightly_cents integer not null check(nightly_cents>=0),tax_bps integer not null check(tax_bps between 0 and 10000),subtotal_cents integer not null,tax_cents integer not null,total_cents integer not null,status text not null default 'confirmed' check(status in('confirmed','cancelled')),payment_status text not null default 'unpaid' check(payment_status='unpaid'),version integer not null default 1,policy_snapshot text not null,created_at timestamptz not null default now(),check(departure>arrival and departure-arrival<=60),check(subtotal_cents=nightly_cents*(departure-arrival)),check(tax_cents=round(subtotal_cents::numeric*tax_bps/10000)::integer),check(total_cents=subtotal_cents+tax_cents),exclude using gist(unit_id with =,daterange(arrival,departure,'[)') with &&) where(status='confirmed'));
create index bookings_arrival_idx on public.bookings(arrival);
create table public.audit_log(id bigint generated always as identity primary key,booking_id uuid not null references public.bookings(id),actor uuid references auth.users(id),event text not null,old_record jsonb,new_record jsonb,created_at timestamptz not null default now());
create table public.email_outbox(id uuid primary key default gen_random_uuid(),booking_id uuid not null references public.bookings(id),version integer not null,event text not null,payload jsonb not null,status text not null default 'pending' check(status in('pending','processing','sent','failed')),attempts integer not null default 0,next_attempt_at timestamptz not null default now(),lease_until timestamptz,claim_token uuid,provider_id text,last_error text,created_at timestamptz not null default now(),sent_at timestamptz,unique(booking_id,version,event));
create table public.rate_limits(key text not null,window_start timestamptz not null,count integer not null,primary key(key,window_start));
alter table public.staff_members enable row level security;alter table public.settings enable row level security;alter table public.units enable row level security;alter table public.bookings enable row level security;alter table public.audit_log enable row level security;alter table public.email_outbox enable row level security;alter table public.rate_limits enable row level security;
-- No direct browser read/write policies: all operations go through guarded server routes.
revoke all on public.staff_members,public.settings,public.units,public.bookings,public.audit_log,public.email_outbox,public.rate_limits from anon,authenticated;
grant all on public.staff_members,public.settings,public.units,public.bookings,public.audit_log,public.email_outbox,public.rate_limits to service_role;
grant usage,select on sequence public.audit_log_id_seq to service_role;
create function public.take_rate_limit(p_key text,p_limit integer) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare n integer;begin
 delete from rate_limits where window_start<now()-interval '1 day';
 insert into rate_limits(key,window_start,count) values(p_key,date_bin(interval '10 minutes',now(),'2020-01-01'::timestamptz),1) on conflict(key,window_start) do update set count=rate_limits.count+1 returning count into n;return n<=p_limit;end;$$;
create function public.queue_booking_email(p_booking bookings,p_event text) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare s settings;begin select * into s from settings where id=1;
 insert into email_outbox(booking_id,version,event,payload) values(p_booking.id,p_booking.version,p_event,to_jsonb(p_booking)||jsonb_build_object('event',p_event,'policy',p_booking.policy_snapshot,'check_in',s.check_in,'check_out',s.check_out,'timezone',s.timezone));end;$$;
create function public.reserve_booking(p_request_id uuid,p_unit_id text,p_arrival date,p_departure date,p_name text,p_email text,p_expected_total integer,p_expected_policy text) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare s settings;u units;b bookings;sub integer;tax integer;begin
 perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));
 select * into b from bookings where request_id=p_request_id;
 if found then
 if b.unit_id<>p_unit_id or b.arrival<>p_arrival or b.departure<>p_departure or b.guest_name<>trim(p_name) or b.email<>lower(trim(p_email)) then raise exception 'Idempotency key was already used for different details.';end if;
 return jsonb_build_object('reference',b.reference,'arrival',b.arrival,'departure',b.departure,'unit_id',b.unit_id,'total_cents',b.total_cents,'subtotal_cents',b.subtotal_cents,'tax_cents',b.tax_cents,'status',b.status,'payment_status',b.payment_status);end if;
 select * into s from settings where id=1 for share;
 if not s.accepting_bookings or not s.tax_confirmed or s.tax_bps is null or length(s.policy)<10 or s.season_start is null or s.season_end is null or s.check_in='' or s.check_out='' then raise exception 'Online booking is not open yet.';end if;
 if p_arrival<(now() at time zone s.timezone)::date or p_arrival<s.season_start or p_departure>s.season_end or p_departure<=p_arrival or p_departure-p_arrival>60 or p_arrival>(now() at time zone s.timezone)::date+730 then raise exception 'Stay dates are outside the booking window_start.';end if;
 if length(trim(p_name)) not between 1 and 100 or length(p_email)>254 or p_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'Enter a valid guest name and email.';end if;
 select * into u from units where id=p_unit_id and active for share;if not found then raise exception 'Accommodation unavailable.';end if;
 sub=u.nightly_cents*(p_departure-p_arrival);tax=round(sub::numeric*s.tax_bps/10000)::integer;
 if sub+tax<>p_expected_total or s.policy<>p_expected_policy then raise exception 'Pricing or policy changed. Refresh availability and review again.';end if;
 insert into bookings(request_id,unit_id,type,guest_name,email,arrival,departure,nightly_cents,tax_bps,subtotal_cents,tax_cents,total_cents,policy_snapshot) values(p_request_id,u.id,u.type,trim(p_name),lower(trim(p_email)),p_arrival,p_departure,u.nightly_cents,s.tax_bps,sub,tax,sub+tax,s.policy) returning * into b;
 insert into audit_log(booking_id,event,new_record) values(b.id,'created',to_jsonb(b));perform queue_booking_email(b,'confirmed');
 return jsonb_build_object('reference',b.reference,'arrival',b.arrival,'departure',b.departure,'unit_id',b.unit_id,'total_cents',b.total_cents,'subtotal_cents',b.subtotal_cents,'tax_cents',b.tax_cents,'status',b.status,'payment_status',b.payment_status);
 exception when exclusion_violation then raise exception using errcode='23P01',message='This site was just booked. Please choose another site or dates.';end;$$;
create function public.change_booking(p_actor uuid,p_id uuid,p_version integer,p_action text,p_unit_id text default null,p_arrival date default null,p_expected_total integer default null) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare b bookings;old_b bookings;u units;s settings;n integer;rate integer;begin
 if not exists(select 1 from staff_members where user_id=p_actor) then raise exception 'Staff access required.';end if;
 select * into b from bookings where id=p_id for update;if not found or b.version<>p_version then raise exception 'Booking changed. Refresh and try again.';end if;if b.status<>'confirmed' then raise exception 'Only active reservations can change.';end if;old_b=b;
 if p_action='cancel' then update bookings set status='cancelled',version=version+1 where id=b.id returning * into b;
 elsif p_action='move' then
 select * into s from settings where id=1 for share;select * into u from units where id=p_unit_id and active for share;if not found then raise exception 'Choose an active site.';end if;
 n=b.departure-b.arrival;if s.season_start is null or s.season_end is null or p_arrival is null or p_arrival<(now() at time zone s.timezone)::date or p_arrival<s.season_start or p_arrival+n>s.season_end or p_arrival>(now() at time zone s.timezone)::date+730 then raise exception 'Destination is outside the booking window_start.';end if;
 if b.unit_id=u.id and b.arrival=p_arrival then return to_jsonb(b);end if;
 rate=case when b.type=u.type then b.nightly_cents else u.nightly_cents end;
 if p_expected_total is null or p_expected_total<>rate*n+round(rate::numeric*n*b.tax_bps/10000)::integer then raise exception 'Destination price changed. Refresh and review again.';end if;
 update bookings set unit_id=u.id,type=u.type,arrival=p_arrival,departure=p_arrival+n,nightly_cents=rate,subtotal_cents=rate*n,tax_cents=round(rate::numeric*n*b.tax_bps/10000)::integer,total_cents=rate*n+round(rate::numeric*n*b.tax_bps/10000)::integer,version=version+1 where id=b.id returning * into b;
 else raise exception 'Unknown action.';end if;
 insert into audit_log(booking_id,actor,event,old_record,new_record) values(b.id,p_actor,p_action,to_jsonb(old_b),to_jsonb(b));perform queue_booking_email(b,case when p_action='cancel' then 'cancelled' else 'moved' end);return to_jsonb(b);
 exception when exclusion_violation then raise exception using errcode='23P01',message='Destination overlaps another reservation. Nothing was moved.';end;$$;
create function public.claim_email(p_reference text default null) returns setof email_outbox language plpgsql security definer set search_path=public,pg_temp as $$
declare job email_outbox;begin
 update email_outbox e set status='failed',last_error='Superseded by a newer booking version, retry window_start expired, or maximum attempts reached.' where (e.status='pending' or (e.status='processing' and e.lease_until<now())) and (e.created_at<now()-interval '23 hours' or e.attempts>=5 or not exists(select 1 from bookings b where b.id=e.booking_id and b.version=e.version));
 select * into job from email_outbox where status in('pending','processing') and (status='pending' or lease_until<now()) and next_attempt_at<=now() and (p_reference is null or payload->>'reference'=p_reference) order by created_at for update skip locked limit 1;
 if not found then return;end if;update email_outbox set status='processing',attempts=attempts+1,claim_token=gen_random_uuid(),lease_until=now()+interval '2 minutes' where id=job.id returning * into job;return next job;end;$$;
create function public.finish_email(p_id uuid,p_claim_token uuid,p_provider_id text,p_error text) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$declare affected integer;begin
 update email_outbox set status=case when p_provider_id is not null then 'sent' when attempts>=5 then 'failed' else 'pending' end,provider_id=p_provider_id,last_error=p_error,sent_at=case when p_provider_id is not null then now() else null end,lease_until=null,claim_token=null,next_attempt_at=now()+interval '5 minutes' where id=p_id and status='processing' and claim_token=p_claim_token;get diagnostics affected=row_count;return affected=1;end;$$;
-- All RPC functions are server-only. RLS bypass/service key must NEVER be exposed to browser.
revoke execute on function public.take_rate_limit(text,integer),public.queue_booking_email(bookings,text),public.reserve_booking(uuid,text,date,date,text,text,integer,text),public.change_booking(uuid,uuid,integer,text,text,date,integer),public.claim_email(text),public.finish_email(uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function public.take_rate_limit(text,integer),public.queue_booking_email(bookings,text),public.reserve_booking(uuid,text,date,date,text,text,integer,text),public.change_booking(uuid,uuid,integer,text,text,date,integer),public.claim_email(text),public.finish_email(uuid,uuid,text,text) to service_role;
commit;
