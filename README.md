# Coal Mine Campground Booking System

Standalone Next.js application · pay at the campground · CAD

## Status — read this first

This is a build-tested source-code starter, NOT a deployed or independently certified production service. No hosting, Supabase project, email domain or DNS records have been created. No existing campground website or prototype reservations are modified or imported. Never use fictional prototype bookings as real reservations.

The guest website, staff dashboard, database migration, booking API, drag-to-move calendar, cancellation flow and email outbox are included. Online booking is CLOSED by default. You must configure services and policies and complete the launch checklist below before opening it.

### Confirmed inventory

| Type | Units | Nightly CAD before tax |
| --- | ---: | ---: |
| Powered RV | 5 | 47.00 |
| Unpowered RV | 5 | 30.00 |
| Tent site | 30 | 31.00 |
| Cabin | 5 | 136.95 |

Labels P01–P05, U01–U05, T01–T30 and C01–C05 are provisional, not a physical map. Check actual unit labels and accommodation rules before launch. No campground contact information, address, policies or tax rates have been invented. America/Whitehorse is a provisional default; staff must verify it.

## What is included

- Public guest booking page at /, availability by date, unit choice, guest name/email, policy acceptance and a server-recalculated tax-inclusive quote.
- No credit-card collection, payment processing or payment-received claims. All reservations remain unpaid and payment is due at the campground.
- Staff password sign-in at /admin, explicit database staff allowlist, reservation register, CSV export and site calendar.
- Calendar dragging changes site and arrival while retaining stay length. Review the old/new amount before confirming. Same type retains the booked rate; different type uses destination rate. No drag-to-copy or resizing.
- Transactional PostgreSQL exclusion constraint prevents overlapping confirmed reservations for the same unit. Checkout is exclusive; same-day turnover is permitted.
- Optimistic versions prevent stale staff edits overwriting another staff edit.
- Atomic booking/email-outbox write, fenced per-attempt email leases, bounded retries and provider idempotency keys. Confirmation/update/cancellation emails are submitted immediately when possible, otherwise queued.
- Service-only database APIs; public requests never return guest names or emails.
- Turnstile server-side verification, exact origin checks and database-backed public request limits.
- Opening season, check-in/out times, tax and policy configuration. Booking checks enforce opening dates and a 1–60 night stay limit, up to 730 days ahead.

### Lost-response safety

The booking request key is retained while the booking page stays open. If a response is ambiguous, retry on that same page with the same details. Reload-safe booking recovery is not implemented. After a reload, check your inbox or contact staff before trying another unit; a new request on another unit can create a second reservation. Same-site overlapping requests remain database-protected.

## What is NOT included

No existing reservation import, online payments, cash-payment ledger, deposits, refunds, guest self-service cancellation, accounting integration, campground map, multi-property access, occupancy/guest-count rules, RV-length/pet filters, tax exemptions, seasonal pricing or staff account recovery UI. These can be added later. Real-time cross-tab updates are not provided: staff use Refresh, while the database remains authoritative for writes. Staff list/CSV only cover the displayed date window and up to 1000 reservations; a warning appears at the limit.

## Simplest deployment path (no terminal needed)

Use a NEW project/repository so nothing existing gets overwritten.

### 1. Create a NEW Supabase project

1. Create your own Supabase account/project and choose an appropriate database region. Review privacy/data-residency requirements for guest data.
2. Open its SQL Editor. Paste and run db/001_initial.sql ONCE. This creates new tables and seeds the 45 units; do not run it on an existing booking database.
3. In Authentication, create your staff user with your own email. Set its password privately through the service UI; do not send it in chat. Disable public signup if you do not need it.
4. Add that existing user to the staff allowlist in SQL Editor, substituting your staff email if needed:

    insert into public.staff_members(user_id)
    select id from auth.users where lower(email) = lower('parassagwal0@gmail.com')
    on conflict do nothing;

   Confirm one row exists for the intended staff user. Authentication alone is not enough: the allowlist is required.
5. Copy the project's URL and publishable/anon key into the public hosting variables listed below. Keep its service-role key strictly server-only.
6. Configure Supabase authentication rate limits and the production Site URL. For staff password resets/invitations, configure Supabase custom SMTP separately; the booking email service does not automatically configure Auth email.

### 2. Set up transactional email

1. Create a Resend account and add a domain/subdomain you own.
2. Add the provider's required DNS records and wait for successful verification.
3. Set EMAIL_FROM to a verified address, for example: Coal Mine Campground <bookings@YOUR-VERIFIED-DOMAIN>.
4. EMAIL_REPLY_TO may be parassagwal0@gmail.com.

IMPORTANT: Resend cannot send as parassagwal0@gmail.com because you do not control gmail.com's DNS. The Gmail integration used in the prototype is NOT part of this standalone application. A verified domain sender is required. Do not claim automatic emails work until you have tested actual inbox delivery.

### 3. Configure Cloudflare Turnstile

Create a widget for the exact hostname you will deploy to. Set the site key, secret key and expected hostname. Verification checks hostname and action='booking' on the server, not just the widget. The site key is public; the secret is server-only. Use official test keys only on a test deployment, then replace them before opening real bookings.

### 4. Upload source to a NEW private GitHub repository

Extract the ZIP. Upload the files INSIDE the coal-mine-campground-booking folder to the repository root. package.json, app, lib and db must be at the root. Never upload node_modules, .next, actual .env files, or any secret values. The ZIP contains no credentials.

### 5. Import that repository into Vercel

Select the Next.js framework and let it build using the included package-lock.json. Set environment variables in the hosting dashboard. Node 22 or newer supported by Next.js is recommended.

This is a server application: a plain static-folder drag-and-drop upload will NOT run its booking or admin APIs. Vercel/Git deploy is recommended. Netlify is an alternative with its Next.js/OpenNext integration and an authenticated external email scheduler; netlify.toml is included, but Netlify deployment has not been tested.

### Required hosting environment variables

| Variable | Public? | Purpose |
| --- | --- | --- |
| NEXT_PUBLIC_SUPABASE_URL | Yes | Your Supabase project URL |
| NEXT_PUBLIC_SUPABASE_ANON_KEY | Yes | Publishable/anon key, never service-role key |
| SUPABASE_SERVICE_ROLE_KEY | NO | Database access, bypasses RLS; server only |
| APP_URL | Yes | Exact deployed origin, e.g. https://your-deployment-domain; no trailing slash |
| NEXT_PUBLIC_TURNSTILE_SITE_KEY | Yes | Widget site key; present before the production build |
| TURNSTILE_SECRET_KEY | NO | Server-side verification secret |
| TURNSTILE_HOSTNAME | Yes | Exact hostname only, no scheme/path |
| RATE_LIMIT_SECRET | NO | Separate strong random secret for hashing IP-based rate keys |
| CRON_SECRET | NO | Separate strong random secret for authenticated queue processing |
| RESEND_API_KEY | NO | Email provider API key |
| EMAIL_FROM | Yes | Verified domain sender |
| EMAIL_REPLY_TO | Yes | Your contact/reply address |

Generate strong secrets through a password manager or the service UI and enter them directly into the host's secure environment-variable fields. Do not paste them in chat. Changes to NEXT_PUBLIC_* variables require a rebuild. Use separate test and production databases and secrets.

Set APP_URL and TURNSTILE_HOSTNAME to the actual deployment first; use the final booking domain when you attach it. Guests must use that configured origin. Configure a subdomain only if you control its DNS; nothing in this ZIP modifies your current site.

### 6. Configure email retries — required

The included vercel.json requests a cron job EVERY FIVE MINUTES to /api/cron/email. Confirm your hosting plan supports this schedule; do NOT assume a free plan supports five-minute cron. If your host rejects it, use a supported scheduler or appropriate hosting plan. On Netlify, vercel.json does nothing: you MUST provision a separate scheduler.

The scheduler must send Authorization: Bearer <CRON_SECRET> to the HTTPS endpoint. Never put the secret in a public URL. Most emails are attempted immediately on booking/move/cancellation; the schedule handles due retry jobs.

Retries wait at least five minutes; up to five attempts within 23 hours are allowed. The 23-hour cutoff is deliberate to remain inside the email provider's 24-hour idempotency window. Failed/expired entries require staff review rather than blind resend, because an earlier delivery may have succeeded even if its acknowledgement was lost. Staff can click Process due queued emails. This does not resend already sent, expired or superseded entries.

A provider receipt means accepted/submitted, not confirmed delivery to the inbox. Monitor provider bounces, spam complaints and logs. A booking can be confirmed even when its email is queued or fails. A reservation update queues a new-version email and supersedes unsent old versions; an already in-flight email cannot be recalled. This is not a guarantee of exactly-once inbox delivery.

### 7. Finish staff launch settings

Open /admin and sign in. In Settings, configure season dates, verify the IANA time zone, set check-in/out times, enter the correct tax rate (including explicitly confirmed zero if applicable), and write your real booking/cancellation policy with guest contact information. Confirm policies with appropriate business/legal advice. Leave Accept online reservations OFF until the checklist below passes.

### 8. Connect your existing website

Only after launch testing, point its Book Now button to the standalone booking domain. The existing campground website content, contact information and separate pages need not change. This package does not make that change for you.

## Launch checklist — do not skip

- [ ] Run the migration in a fresh TEST Supabase project, then repeat setup in production only after tests pass.
- [ ] Verify the 45 unit IDs, real accommodation rules and rates against the campground.
- [ ] Verify taxes, date/time zone, season, cancellation/no-show policies, contact details and privacy notice.
- [ ] Test the guest flow on desktop/mobile; no failed/expired CAPTCHA can book.
- [ ] A non-staff account and logged-out requests cannot read/edit bookings or settings.
- [ ] Test two simultaneous requests for the same site/dates against your actual hosted database: only one can succeed.
- [ ] Retry the SAME request key after a lost response: no second booking is created.
- [ ] Confirm the old quote is rejected if tax/rate/policy changes before submission.
- [ ] Test calendar drag and the Move-button alternative, full-stay conflicts, cancellation, stale staff edits and CSV export.
- [ ] Verify actual confirmation, move and cancellation emails, sender DNS, replies, spam behavior, retry scheduling and failed-delivery follow-up.
- [ ] Set provider rate limits, staff account recovery, backups and retention/deletion procedures. Guest information is in bookings, audit snapshots and email snapshots; deletion must cover all three where legally appropriate.
- [ ] Configure monitoring, budget/usage limits and test backups/restoration. Costs depend on the provider/plan; no free-tier capacity guarantee is made.
- [ ] Arrange an independent security/accessibility review and operational acceptance testing.
- [ ] Only then enable Accept online reservations and link the real Book Now button.

## Code structure

- app/page.tsx: guest flow; app/admin/page.tsx: staff UI/calendar.
- app/api: guarded server routes; no keys in browser code.
- lib/domain.mjs: pure date/price/move rules; tests/domain.test.mjs: unit tests.
- lib/server.ts: server-only Supabase client, staff validation, rate limit, CAPTCHA and origin checks.
- lib/email.ts: bounded queue delivery and Resend calls.
- db/001_initial.sql: one-time schema, RLS deny-by-default grants, booking RPCs, exclusion constraint, audit and outbox.
- .env.example: configuration names only; README and TEST-REPORT.md: deployment and test details.

## Running on your own computer (optional developer instructions)

If a developer uses a local terminal: npm ci, copy .env.example to .env.local and configure it privately, npm test, npm run test:db, npm run typecheck, npm run build, npm run start. npm run dev runs local development. Do not use real customer data in development. Database connections use Supabase HTTPS, not an embedded local database.

## Official references

- Next.js static-export limitations: https://nextjs.org/docs/app/guides/static-exports
- Supabase password sign-in: https://supabase.com/docs/guides/auth/passwords
- Supabase security/RLS: https://supabase.com/docs/guides/database/postgres/row-level-security
- Resend domain verification: https://resend.com/docs/add-a-domain
- Resend idempotency: https://resend.com/docs/dashboard/emails/idempotency-keys
- Cloudflare server verification: https://developers.cloudflare.com/turnstile/get-started/server-side-validation/
- Vercel cron management: https://vercel.com/docs/cron-jobs/manage-cron-jobs
- Netlify Next.js hosting: https://docs.netlify.com/integrations/frameworks/next-js/overview/
