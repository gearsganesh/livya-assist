# LIVYA OPS

LIVYA OPS is the patient coordination and concierge operations application.

## Production architecture
- Vite static frontend
- Supabase Auth
- Supabase PostgreSQL + Row Level Security
- Supabase Edge Functions for privileged user administration
- Vercel deployment from GitHub

The browser is no longer the operational database. Patients, cases, appointments, concierge services, tasks, billing, hospitals, referral data, staff and centers are stored in Supabase.

## Modules
- Dashboard
- Patients
- Cases with Board/List workflow
- Concierge
- Tasks
- Billing
- Hospitals
- Referral network
- Team & Centers

## Supabase setup
1. Open the dedicated LIVYA OPS Supabase project.
2. Run `supabase/schema.sql` in the SQL Editor.
3. Deploy:
   - `supabase/functions/bootstrap-admin`
   - `supabase/functions/admin-create-user`
   - `supabase/functions/admin-delete-user`
4. The login screen has a **First-time setup** action. The bootstrap function only creates an administrator when `ops_staff` is empty.
5. Configure Vercel environment variables:
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_PUBLISHABLE_KEY`
6. Never put a Supabase secret/service-role key in browser code. Supabase publishable keys are intended for browser applications when RLS protects the database.

The bootstrap Edge Function is intentionally public at the platform layer and performs its own one-time empty-database check. Its JWT verification is disabled in `supabase/config.toml`, which is required for a signed-out browser to call it.

## Security model
- Super Admin: all centers and staff administration.
- Center Admin: center-scoped operational access and user creation inside their own center.
- Coordinator / Finance / Viewer: access is controlled by role and center scope.
- Related appointments, tasks, concierge and billing records inherit access from patient/case.
- Hospital and referral directories are shared reference data.
- RLS is enabled on every operational table.

## Deployment
Connect `gearsganesh/livya-assist` to Vercel and set the two `VITE_SUPABASE_*` variables. The repository contains Vite SPA routing and a Vercel rewrite so direct application routes resolve correctly.

## Important
Do not commit real patient data, passwords, Supabase secret keys, or `.env` files. The publishable key may be bundled into browser code, but authorization still comes from Supabase Auth and RLS.
