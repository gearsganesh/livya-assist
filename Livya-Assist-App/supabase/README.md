# New LIVYA Supabase backend

This folder belongs to the standalone LIVYA Client + Admin project. It does **not** use the existing Livya HIMS Supabase project.

Project URL: `https://ekyvogemusxmgeefrqmc.supabase.co`

## Setup
1. Create/open the new Supabase project.
2. Open SQL Editor.
3. Run `schema.sql` in full.
4. Enable the authentication providers you want to use. The client UI supports email/password and phone OTP.
5. Create the first staff account in Supabase Auth, then change its `profiles.role` to `super_admin` using the SQL editor.
6. Create client Auth users and link them to `metabolic_clients.client_user_id`.
7. Add Storage buckets and storage policies when document upload is enabled in production.

The publishable key is intentionally used only by browser applications. Never put a service-role/secret key in either app.
