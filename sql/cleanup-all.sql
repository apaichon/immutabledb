-- First list all tables
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
    AND table_type = 'BASE TABLE';
-- Drop all triggers in the database
DO $$
DECLARE trigger_rec RECORD;
BEGIN FOR trigger_rec IN (
    SELECT DISTINCT trigger_name,
        event_object_table
    FROM information_schema.triggers
    WHERE trigger_schema = 'public'
) LOOP EXECUTE 'DROP TRIGGER IF EXISTS ' || trigger_rec.trigger_name || ' ON ' || trigger_rec.event_object_table || ' CASCADE';
END LOOP;
END $$;
-- Drop all functions
DO $$
DECLARE func_rec RECORD;
BEGIN FOR func_rec IN (
    SELECT 'DROP FUNCTION IF EXISTS ' || ns.nspname || '.' || p.proname || '(' || oidvectortypes(p.proargtypes) || ') CASCADE;' as drop_statement
    FROM pg_proc p
        INNER JOIN pg_namespace ns ON p.pronamespace = ns.oid
    WHERE ns.nspname = 'public'
) LOOP EXECUTE func_rec.drop_statement;
END LOOP;
END $$;
-- Drop all tables
DO $$
DECLARE table_rec RECORD;
BEGIN FOR table_rec IN (
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = 'public'
) LOOP EXECUTE 'DROP TABLE IF EXISTS ' || table_rec.tablename || ' CASCADE';
END LOOP;
END $$;
-- Verify all tables are dropped
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
    AND table_type = 'BASE TABLE';