# LIVYA OPS

LIVYA OPS is the patient coordination and concierge operations application.

## Repository
This repository is now the development source for the LIVYA OPS app.

## Modules
- Dashboard
- Patients
- Cases with Board/List workflow
- Appointments
- Concierge
- Tasks
- Billing
- Hospitals
- Referral network
- Team & Centers

## Local testing
1. Clone this repository.
2. Open it in VS Code.
3. Run `npm install` then `npm run dev`, or open `index.html` with Live Server.
4. The first local launch creates a Super Admin account.
5. No dummy patient/case/billing records are seeded.

## Supabase production
`supabase/schema.sql` defines the production tables and RLS policies. Supabase Auth is the source of truth for production users. The service-role key must only be used by Edge Functions and must never be placed in frontend code.

1. Create the dedicated LIVYA OPS Supabase project.
2. Run `supabase/schema.sql`.
3. Deploy `supabase/functions/admin-create-user` and `supabase/functions/admin-delete-user`.
4. Create the first Super Admin in Auth and add its ID to `ops_staff`.
5. Add the project URL and publishable key to the frontend configuration.
6. Replace localStorage data access with Supabase queries and enforce role/center permissions through RLS.

## Deployment
The project is structured for Vercel deployment. Connect this GitHub repository to Vercel and use the standard Vite build command.

## Security
Do not commit `.env` files, service-role keys, real patient data, or real credentials.
