# LIVYA OPS - Patient Coordination & Concierge

LIVYA OPS is the operations workspace for patient coordination, concierge, cases, tasks, billing, hospitals, referrals, centers and staff administration.

## Current development stage
- Browser-testable frontend
- No dummy operational records
- Supabase production schema with RLS
- Supabase Auth architecture
- Secure admin user-management Edge Functions

## Local test
Open `index.html` with VS Code Live Server, or install dependencies and run `npm run dev`.

## Supabase
See `supabase/schema.sql` and `supabase-config.example.js`.

Never place a Supabase service-role key in the browser.
