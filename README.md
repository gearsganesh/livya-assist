# LIVYA OPS

LIVYA OPS is the patient coordination and concierge operations application.

## Repository
This repository is the development source for the LIVYA OPS app.

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
3. Run `npm install` and then `npm run dev`, or open `index.html` with Live Server.
4. The first local launch creates a Super Admin account.
5. Operational records are not seeded with dummy patients, cases, appointments, billing or concierge data.
6. Create the required centers in **Team & Centers** before creating patients and cases.

## Supabase production
`supabase/schema.sql` defines the production tables, authentication relationships and RLS policies. Supabase Auth is the source of truth for production users. The service-role key must only be used by Edge Functions and must never be placed in frontend code.

The production RLS model is center-aware:
- Super Admin: all centers.
- Global-scope staff: all centers.
- Center-scoped staff: only their assigned center.
- Related appointments, tasks, concierge and billing records inherit access from their patient/case.
- Hospital and referral directories are shared reference data.
- User creation is handled by the Edge Function, with Center Admin creation restricted to the administrator's own center.

### Supabase setup
1. Create the dedicated LIVYA OPS Supabase project.
2. Run `supabase/schema.sql` in the SQL Editor.
3. Deploy `supabase/functions/admin-create-user` and `supabase/functions/admin-delete-user`.
4. Create the first Super Admin in Supabase Auth and add its ID to `ops_staff` with role `Super admin` and scope `All centers`.
5. Add the project URL and publishable key to the frontend configuration.
6. Wire the frontend data layer to Supabase Auth/Postgres and remove localStorage as the production source of truth.

## Deployment
The project is structured for Vercel deployment.

```bash
npm install
npm run build
```

Connect the GitHub repository `gearsganesh/livya-assist` to Vercel. Every push to `main` can then trigger a new deployment.

## Security
Do not commit `.env` files, service-role keys, real patient data, or real credentials. Only use the Supabase publishable/anon key in browser code. Keep the service-role key inside Supabase Edge Functions.
