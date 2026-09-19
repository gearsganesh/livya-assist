# LIVYA Smart App

Fresh Client + Admin healthcare web application for the new LIVYA Smart App Supabase project.

## Production domains

- Client: `https://app.livyacurehub.com`
- Admin: `https://admin.livyacurehub.com`

## Apps

- `client/` - mobile-first LIVYA client experience matching the supplied dark mobile reference screens.
- `admin/` - desktop-first LIVYA care operations dashboard matching the supplied warm-light reference screens.
- `supabase/` - database schema, RLS policies, storage policy and seed catalogue data.

## Local setup

Create `.env.local` in each app from `.env.example`:

```env
VITE_SUPABASE_URL=https://ekyvogemusxmgeefrqmc.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=YOUR_SUPABASE_PUBLISHABLE_KEY
```

Never put a Supabase service-role key in a browser app.

## Supabase

Apply `supabase/migrations/001_livya_initial.sql` to the new project. The migration is safe to re-run for policies, triggers and seed catalogue rows.

Create an Auth user for the first admin, then set its `profiles.role` to `super_admin` in the Supabase SQL editor. Client Auth users must be linked to `metabolic_clients.client_user_id`.

The schema includes RLS, a private `livya-records` storage bucket and policies for client-owned clinical documents.

## Vercel

Deploy two Vercel projects from the same GitHub repository:

- Project `livya-client`, root directory `client`, domain `app.livyacurehub.com`
- Project `livya-admin`, root directory `admin`, domain `admin.livyacurehub.com`

Set the same Supabase environment variables in both projects.
