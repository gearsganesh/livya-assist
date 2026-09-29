-- LIVYA workflow completion migration.
-- Applied to production on 2026-09-29. This file mirrors the production DDL.

ALTER TABLE public.ops_staff DROP CONSTRAINT IF EXISTS ops_staff_role_check;
ALTER TABLE public.ops_staff ADD CONSTRAINT ops_staff_role_check CHECK (role = ANY (ARRAY['SUPER_ADMIN','CENTER_MANAGER','COORDINATOR','CONCIERGE_AGENT','HOSPITAL_USER','PATIENT','Super admin','Coordinator','Finance','Center admin','Viewer']));
UPDATE public.ops_staff SET role='SUPER_ADMIN' WHERE role='Super admin';
UPDATE public.ops_staff SET role='CENTER_MANAGER' WHERE role='Center admin';
UPDATE public.ops_staff SET role='COORDINATOR' WHERE role='Coordinator';
UPDATE public.ops_staff SET role='CONCIERGE_AGENT' WHERE role='Finance';
ALTER TABLE public.ops_staff ADD COLUMN IF NOT EXISTS center_id uuid REFERENCES public.ops_centers(id) ON DELETE SET NULL, ADD COLUMN IF NOT EXISTS hospital_id uuid REFERENCES public.ops_hospitals(id) ON DELETE SET NULL, ADD COLUMN IF NOT EXISTS patient_id uuid REFERENCES public.ops_patients(id) ON DELETE SET NULL;

ALTER TABLE public.ops_centers ADD COLUMN IF NOT EXISTS code text, ADD COLUMN IF NOT EXISTS country text, ADD COLUMN IF NOT EXISTS currency text NOT NULL DEFAULT 'AED', ADD COLUMN IF NOT EXISTS phone text, ADD COLUMN IF NOT EXISTS address text, ADD COLUMN IF NOT EXISTS stage text NOT NULL DEFAULT 'ACTIVE';
UPDATE public.ops_centers SET code=CASE WHEN upper(name) LIKE '%ABU DHABI%' THEN 'AUH' WHEN upper(name) LIKE '%AL AIN%' THEN 'AAN' WHEN upper(name) LIKE '%DUBAI%' THEN 'DXB' WHEN upper(name) LIKE '%MANAMA%' THEN 'BAH' WHEN upper(name) LIKE '%MUSCAT%' THEN 'MCT' ELSE upper(regexp_replace(left(name,4),'[^A-Za-z]','','g')) END WHERE code IS NULL OR code='';
CREATE UNIQUE INDEX IF NOT EXISTS ops_centers_code_uidx ON public.ops_centers(code);

ALTER TABLE public.ops_hospitals ADD COLUMN IF NOT EXISTS country text, ADD COLUMN IF NOT EXISTS address text, ADD COLUMN IF NOT EXISTS phone text, ADD COLUMN IF NOT EXISTS email text, ADD COLUMN IF NOT EXISTS exclusivity_region text;
ALTER TABLE public.ops_referrers ADD COLUMN IF NOT EXISTS type text NOT NULL DEFAULT 'DOCTOR', ADD COLUMN IF NOT EXISTS email text, ADD COLUMN IF NOT EXISTS city text, ADD COLUMN IF NOT EXISTS country text;

CREATE TABLE IF NOT EXISTS public.ops_vendors(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),name text NOT NULL,category text,city text,country text,contact_phone text,contact_email text,rating numeric(3,2) NOT NULL DEFAULT 0 CHECK(rating between 0 and 5),active boolean NOT NULL DEFAULT true,created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now());
ALTER TABLE public.ops_vendors ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.ops_cases DROP CONSTRAINT IF EXISTS ops_cases_status_check;
ALTER TABLE public.ops_cases ADD CONSTRAINT ops_cases_status_check CHECK(status=ANY(ARRAY['ENQUIRY','ASSESSMENT','QUOTATION','ACCEPTED','TRAVEL_PLANNED','TRAVEL PLANNED','IN_TREATMENT','IN TREATMENT','DISCHARGED','FOLLOW_UP','FOLLOW UP','CLOSED','CANCELLED']));
ALTER TABLE public.ops_cases ADD COLUMN IF NOT EXISTS hospital_id uuid REFERENCES public.ops_hospitals(id) ON DELETE SET NULL, ADD COLUMN IF NOT EXISTS referrer_id uuid REFERENCES public.ops_referrers(id) ON DELETE SET NULL, ADD COLUMN IF NOT EXISTS currency text NOT NULL DEFAULT 'AED', ADD COLUMN IF NOT EXISTS closed_at timestamptz, ADD COLUMN IF NOT EXISTS cancelled_at timestamptz;
UPDATE public.ops_cases c SET hospital_id=h.id FROM public.ops_hospitals h WHERE c.hospital_id IS NULL AND c.hospital IS NOT NULL AND lower(h.name)=lower(c.hospital);
UPDATE public.ops_cases c SET referrer_id=r.id FROM public.ops_referrers r WHERE c.referrer_id IS NULL AND c.referred_by IS NOT NULL AND lower(r.name)=lower(c.referred_by);

ALTER TABLE public.ops_appointments DROP CONSTRAINT IF EXISTS ops_appointments_status_check;
ALTER TABLE public.ops_appointments ADD CONSTRAINT ops_appointments_status_check CHECK(status=ANY(ARRAY['SCHEDULED','CONFIRMED','COMPLETED','MISSED','CANCELLED','Scheduled','Confirmed','Completed','Cancelled']));
ALTER TABLE public.ops_appointments ADD COLUMN IF NOT EXISTS appointment_type text NOT NULL DEFAULT 'CONSULTATION';

ALTER TABLE public.ops_tasks DROP CONSTRAINT IF EXISTS ops_tasks_status_check;
ALTER TABLE public.ops_tasks ADD CONSTRAINT ops_tasks_status_check CHECK(status=ANY(ARRAY['OPEN','IN_PROGRESS','DONE','CANCELLED','Open','Completed','Cancelled']));

ALTER TABLE public.ops_concierge ADD COLUMN IF NOT EXISTS vendor_id uuid REFERENCES public.ops_vendors(id) ON DELETE SET NULL, ADD COLUMN IF NOT EXISTS price numeric(14,2) NOT NULL DEFAULT 0, ADD COLUMN IF NOT EXISTS currency text NOT NULL DEFAULT 'AED', ADD COLUMN IF NOT EXISTS category text, ADD COLUMN IF NOT EXISTS requested_at timestamptz NOT NULL DEFAULT now(), ADD COLUMN IF NOT EXISTS delivered_at timestamptz, ADD COLUMN IF NOT EXISTS cancelled_at timestamptz;
ALTER TABLE public.ops_concierge DROP CONSTRAINT IF EXISTS ops_concierge_status_check;
ALTER TABLE public.ops_concierge ADD CONSTRAINT ops_concierge_status_check CHECK(status=ANY(ARRAY['REQUESTED','QUOTED','CONFIRMED','IN_DELIVERY','DELIVERED','CANCELLED','Open']));

ALTER TABLE public.ops_billing ADD COLUMN IF NOT EXISTS type text NOT NULL DEFAULT 'CONCIERGE', ADD COLUMN IF NOT EXISTS hospital_id uuid REFERENCES public.ops_hospitals(id) ON DELETE SET NULL, ADD COLUMN IF NOT EXISTS gross_amount numeric(14,2) NOT NULL DEFAULT 0, ADD COLUMN IF NOT EXISTS rate_pct numeric(6,3), ADD COLUMN IF NOT EXISTS paid_amount numeric(14,2) NOT NULL DEFAULT 0, ADD COLUMN IF NOT EXISTS currency text NOT NULL DEFAULT 'AED', ADD COLUMN IF NOT EXISTS due_date date, ADD COLUMN IF NOT EXISTS paid_at timestamptz;
ALTER TABLE public.ops_billing DROP CONSTRAINT IF EXISTS ops_billing_status_check;
ALTER TABLE public.ops_billing ADD CONSTRAINT ops_billing_status_check CHECK(status=ANY(ARRAY['DUE','PARTIAL','PAID','CANCELLED','Due','Collected','Cancelled']));
CREATE TABLE IF NOT EXISTS public.ops_payments(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),invoice_id uuid NOT NULL REFERENCES public.ops_billing(id) ON DELETE CASCADE,amount numeric(14,2) NOT NULL CHECK(amount>0),payment_date date NOT NULL DEFAULT current_date,payment_method text,reference text,notes text,created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,created_at timestamptz NOT NULL DEFAULT now());
ALTER TABLE public.ops_payments ENABLE ROW LEVEL SECURITY;
CREATE TABLE IF NOT EXISTS public.ops_case_sequences(center_id uuid NOT NULL REFERENCES public.ops_centers(id) ON DELETE CASCADE,year integer NOT NULL,last_number integer NOT NULL DEFAULT 0,PRIMARY KEY(center_id,year));
CREATE SEQUENCE IF NOT EXISTS public.ops_invoice_number_seq START 1;

-- Workflow functions are intentionally SECURITY DEFINER and call the private authorization helpers.
-- Their production definitions are maintained in the Supabase project migration history.
