# Validation report

Build date: October 30, 2026.

## Passed

- TypeScript static type check: npm run typecheck.
- Next.js 16.4.3 optimized production build: npm run build.
- 22 automated Node tests: npm test. Covers inventory/rates, invalid dates, UTC/DST/leap-day arithmetic, checkout turnover, cents/tax rounding, stay bounds, move conflicts, repricing, cancellation, immutability and a static schema access-control check.
- 30 embedded PostgreSQL checks: full SQL migration executed in PGlite with btree_gist. Tested 45-unit seed, server-computed totals, unpaid status, idempotent reserve, overlapping-reservation rejection, same-day turnover, tampered quote rejection, move repricing, stale versions, failed-move atomicity, cancellation, staff allowlist, rate limiting, email claiming/completion deny-by-default browser grants, stale-worker lease fencing, and active fifth-attempt completion. Found and fixed an SQL reserved-column-name issue during this test.
- 9 production-server HTTP smoke checks: public pages return 200, staff APIs reject unauthenticated requests, email cron rejects unauthenticated calls, missing configuration fails closed, foreign-origin booking request is rejected, and security headers are present.
- npm audit --omit=dev: 0 reported vulnerabilities at build time. This is a point-in-time package advisory check, not a security certification.

## Not validated / still required

- Live Supabase service integration, Auth provisioning, real concurrent connections/load, hosted PostgreSQL permissions/schema-extension placement and backups.
- Resend credentials/domain/DNS, actual email inbox delivery, scheduler deployment, bounces and realistic failure/retry scenarios.
- Turnstile on a configured production hostname.
- Real browser drag gestures, keyboard/screen-reader accessibility, mobile layout and complete browser E2E.
- Production hosting, custom domain, costs/quotas, existing booking migration and actual campground policies/tax rules.

The application deliberately starts with online booking disabled. Successful compilation and local tests do not make it production-ready or prove real email delivery.

## Post-review fixes

The final package includes per-claim email lease tokens and checked completion results, protection against expiring an active fifth attempt, five-minute worker scheduling (requires a compatible hosting plan), reviewed-total validation for staff moves, the SQL reserved-word fix, and documented limits to reload-safe guest booking recovery. Reviewer findings from an earlier snapshot were checked against the final code.
