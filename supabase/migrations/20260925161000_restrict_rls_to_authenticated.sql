-- Restrict operational RLS policies to signed-in application users.
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT schemaname, tablename, policyname
    FROM pg_policies
    WHERE schemaname='public' AND tablename LIKE 'ops_%'
  LOOP
    EXECUTE format('ALTER POLICY %I ON %I.%I TO authenticated',r.policyname,r.schemaname,r.tablename);
  END LOOP;
END $$;

DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname='storage' AND tablename='objects'
      AND policyname IN ('staff read case document files','staff upload case document files','super admins delete case document files','patients read visible case document files')
  LOOP
    EXECUTE format('ALTER POLICY %I ON storage.objects TO authenticated',r.policyname);
  END LOOP;
END $$;
