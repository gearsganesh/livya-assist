# LIVYA Assist

LIVYA Assist is the patient coordination and concierge operations platform.

## Production architecture

- Vite SPA frontend
- Supabase Auth
- Supabase PostgreSQL with Row Level Security
- Supabase Edge Functions for privileged Auth/account administration
- Supabase Storage for case documents
- Vercel deployment from GitHub `main`

The browser is the UI layer. Authorization, lifecycle rules, record linkage and protected writes are enforced in Supabase so the frontend cannot bypass the workflow by sending a different request.

## Current roles

- `SUPER_ADMIN`
- `CENTER_MANAGER`
- `COORDINATOR`
- `CONCIERGE_AGENT`
- `HOSPITAL_USER`
- `PATIENT`

## Core workflow

Case lifecycle:

`ENQUIRY -> ASSESSMENT -> QUOTATION -> ACCEPTED -> TRAVEL_PLANNED -> IN_TREATMENT -> DISCHARGED -> FOLLOW_UP -> CLOSED`

Cancellation is supported from the workflow where permitted.

Quotation acceptance is performed by the `ops_accept_quotation` RPC. It updates the quotation and case atomically, rejects competing draft/sent quotations, and creates the hospital commission invoice.

Case status changes are performed by `ops_transition_case`. Direct browser updates cannot change the case lifecycle status.

## Database source of truth

**Do not use `supabase/schema.sql` as a production schema dump.** It is intentionally a no-op contract now. The ordered files under `supabase/migrations/` are the authoritative database definition.

Fresh environments should use the Supabase CLI migration flow:

1. Link the intended LIVYA Supabase project.
2. Apply the migration history in `supabase/migrations/`.
3. Deploy the Edge Functions under `supabase/functions/`.
4. Configure the frontend with the project URL and publishable key.

This repository and the production project currently use Supabase project ref:

`maewvwdjxdlcbwsrshlp`

## Edge Functions

- `bootstrap-admin`
- `admin-create-user`
- `admin-delete-user`
- `admin-patient-account`
- `ops-api`

Service-role/secret credentials must remain server-side. The browser only receives the Supabase publishable key.

## Frontend and backend contract

The frontend calls database workflow RPCs for protected operations and uses normal table access only for fields that are safe to edit directly.

Backend enforcement currently covers:

- case patient/center linkage
- case lifecycle transitions
- post-acceptance hospital/value locking
- quotation lifecycle and commercial-field locking
- hospital quotation restrictions
- appointment case/patient linkage
- hospital appointment scope
- document uploader ownership
- case-message sender ownership
- invoice patient/hospital linkage
- protected case-number sequence access
- patient self-service profile updates

RLS remains the authorization boundary. Database triggers provide a second layer so a direct API request cannot silently bypass the same workflow rules.

## PWA

LIVYA is installable as a web app on supported iOS and Android browsers.

- standalone display mode
- service worker with versioned cache
- iOS `apple-touch-icon`
- responsive staff, hospital and patient surfaces

## Build

```bash
npm install
npm run build
```

GitHub Actions builds `main` using Node 22 with current `checkout` and `setup-node` actions.

## Deployment

Vercel is connected to the GitHub `main` branch. Configure:

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_PUBLISHABLE_KEY`

Never commit patient data, passwords, service-role keys, secret keys, or `.env` files.
