CREATE EXTENSION IF NOT EXISTS pgtap;
CREATE EXTENSION IF NOT EXISTS dblink WITH SCHEMA extensions;

SELECT no_plan();
SET ROLE postgres;
RESET "request.jwt.claims";

BEGIN;

-- Remove only this test's committed fixture if a previous interrupted run left it.
DROP SCHEMA IF EXISTS streak_concurrency_test CASCADE;
DROP ROLE IF EXISTS ytufit_streak_concurrency_login;
DELETE FROM public.streak_freeze_transactions
WHERE id = '79400000-0000-0000-0000-000000000001'
   OR streak_period_id IN (
     '79200000-0000-0000-0000-000000000001',
     '79200000-0000-0000-0000-000000000002'
   );
UPDATE public.member_streaks
SET current_period_id = NULL
WHERE id = '79300000-0000-0000-0000-000000000001';
DELETE FROM public.streak_periods
WHERE id IN (
  '79200000-0000-0000-0000-000000000001',
  '79200000-0000-0000-0000-000000000002'
);
DELETE FROM public.member_streaks
WHERE id = '79300000-0000-0000-0000-000000000001';
DELETE FROM public.member_streak_rules
WHERE id = '79100000-0000-0000-0000-000000000001';
DELETE FROM public.streak_rules
WHERE id = '79000000-0000-0000-0000-000000000001';
DELETE FROM public.attendances
WHERE id = '79500000-0000-0000-0000-000000000001';

CREATE SCHEMA streak_concurrency_test;

CREATE TEMP TABLE streak_concurrency_connection AS
SELECT encode(gen_random_bytes(18), 'hex') AS password;

DO $$
DECLARE
  v_password TEXT := (SELECT password FROM pg_temp.streak_concurrency_connection);
BEGIN
  EXECUTE format(
    'CREATE ROLE ytufit_streak_concurrency_login LOGIN PASSWORD %L',
    v_password
  );
END;
$$;

CREATE FUNCTION streak_concurrency_test.run_finalize(
  p_period_id UUID,
  p_as_of TIMESTAMPTZ
) RETURNS TABLE(result UUID, error_sqlstate TEXT, error_message TEXT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  BEGIN
    result := private.finalize_streak_period(p_period_id, p_as_of);
    error_sqlstate := NULL;
    error_message := NULL;
  EXCEPTION WHEN OTHERS THEN
    result := NULL;
    error_sqlstate := SQLSTATE;
    error_message := SQLERRM;
  END;
  RETURN NEXT;
END;
$$;

CREATE FUNCTION streak_concurrency_test.run_recalculate(
  p_gym_member_id UUID,
  p_from_period_start DATE,
  p_as_of TIMESTAMPTZ
) RETURNS TABLE(result UUID, error_sqlstate TEXT, error_message TEXT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  BEGIN
    result := private.recalculate_member_streak(
      p_gym_member_id,
      p_from_period_start,
      p_as_of
    );
    error_sqlstate := NULL;
    error_message := NULL;
  EXCEPTION WHEN OTHERS THEN
    result := NULL;
    error_sqlstate := SQLSTATE;
    error_message := SQLERRM;
  END;
  RETURN NEXT;
END;
$$;

REVOKE ALL ON SCHEMA streak_concurrency_test FROM PUBLIC;
REVOKE ALL ON FUNCTION streak_concurrency_test.run_finalize(UUID, TIMESTAMPTZ)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION streak_concurrency_test.run_recalculate(UUID, DATE, TIMESTAMPTZ)
  FROM PUBLIC;
GRANT USAGE ON SCHEMA streak_concurrency_test TO ytufit_streak_concurrency_login;
GRANT EXECUTE ON FUNCTION streak_concurrency_test.run_finalize(UUID, TIMESTAMPTZ)
  TO ytufit_streak_concurrency_login;
GRANT EXECUTE ON FUNCTION streak_concurrency_test.run_recalculate(UUID, DATE, TIMESTAMPTZ)
  TO ytufit_streak_concurrency_login;

CREATE TEMP TABLE concurrency_worker_results (
  phase TEXT NOT NULL,
  worker TEXT NOT NULL,
  result UUID NULL,
  error_sqlstate TEXT NULL,
  error_message TEXT NULL,
  PRIMARY KEY (phase, worker)
);

CREATE FUNCTION pg_temp.wait_for_streak_workers(p_expected INTEGER)
RETURNS BOOLEAN LANGUAGE plpgsql
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_attempt INTEGER;
  v_waiting INTEGER;
  v_diagnostics JSONB;
BEGIN
  FOR v_attempt IN 1..200 LOOP
    PERFORM pg_catalog.pg_stat_clear_snapshot();

    WITH RECURSIVE lock_chain(worker_pid, blocker_pid) AS (
      SELECT activity.pid, blocker.pid
      FROM pg_catalog.pg_stat_activity activity
      CROSS JOIN LATERAL unnest(
        pg_catalog.pg_blocking_pids(activity.pid)
      ) AS blocker(pid)
      WHERE activity.application_name IN (
        'ytufit_streak_worker_a',
        'ytufit_streak_worker_b'
      )

      UNION

      SELECT lock_chain.worker_pid, blocker.pid
      FROM lock_chain
      CROSS JOIN LATERAL unnest(
        pg_catalog.pg_blocking_pids(lock_chain.blocker_pid)
      ) AS blocker(pid)
    )
    SELECT count(DISTINCT activity.pid)::INTEGER
    INTO v_waiting
    FROM pg_catalog.pg_stat_activity activity
    WHERE application_name IN ('ytufit_streak_worker_a', 'ytufit_streak_worker_b')
      AND state = 'active'
      AND wait_event_type = 'Lock'
      AND EXISTS (
        SELECT 1
        FROM lock_chain
        WHERE lock_chain.worker_pid = activity.pid
          AND lock_chain.blocker_pid = pg_catalog.pg_backend_pid()
      );

    IF v_waiting = p_expected THEN
      RETURN TRUE;
    END IF;
    PERFORM pg_catalog.pg_sleep(0.025);
  END LOOP;

  SELECT jsonb_agg(
    jsonb_build_object(
      'pid', activity.pid,
      'application_name', activity.application_name,
      'state', activity.state,
      'wait_event_type', activity.wait_event_type,
      'blocking_pids', pg_catalog.pg_blocking_pids(activity.pid),
      'gate_pid', pg_catalog.pg_backend_pid()
    ) ORDER BY activity.application_name
  )
  INTO v_diagnostics
  FROM pg_catalog.pg_stat_activity activity
  WHERE activity.application_name IN (
    'ytufit_streak_worker_a',
    'ytufit_streak_worker_b'
  );
  RAISE NOTICE 'streak worker wait diagnostics: %', v_diagnostics;
  RETURN FALSE;
END;
$$;

CREATE FUNCTION pg_temp.collect_streak_worker(p_phase TEXT, p_worker TEXT)
RETURNS VOID LANGUAGE plpgsql
SET search_path = pg_catalog, public, extensions
AS $$
DECLARE
  v_result UUID;
  v_error_sqlstate TEXT;
  v_error_message TEXT;
  v_found BOOLEAN;
BEGIN
  SELECT remote.result, remote.error_sqlstate, remote.error_message
  INTO v_result, v_error_sqlstate, v_error_message
  FROM extensions.dblink_get_result(p_worker, false)
    AS remote(result UUID, error_sqlstate TEXT, error_message TEXT);
  v_found := FOUND;

  -- dblink requires one additional empty read before reusing an async
  -- connection for another command.
  PERFORM 1
  FROM extensions.dblink_get_result(p_worker, false)
    AS drained(result UUID, error_sqlstate TEXT, error_message TEXT);

  IF NOT v_found THEN
    v_error_sqlstate := '08000';
    v_error_message := extensions.dblink_error_message(p_worker);
  END IF;

  INSERT INTO pg_temp.concurrency_worker_results (
    phase, worker, result, error_sqlstate, error_message
  ) VALUES (
    p_phase, p_worker, v_result, v_error_sqlstate, v_error_message
  );
END;
$$;

INSERT INTO public.streak_rules (
  id, gym_id, name, target_days, max_freezes, timezone, created_by
) VALUES (
  '79000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  'Concurrency lock ordering fixture',
  2,
  1,
  'America/Montevideo',
  '11111111-1111-1111-1111-111111111111'
);

INSERT INTO public.member_streak_rules (
  id, gym_id, gym_member_id, streak_rule_id, target_days, max_freezes,
  period_type, week_starts_on, timezone, starts_at, status, assigned_by
) VALUES (
  '79100000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  '79000000-0000-0000-0000-000000000001',
  2,
  1,
  'WEEK',
  1,
  'America/Montevideo',
  '2026-08-03 03:00:00+00',
  'ACTIVE',
  '11111111-1111-1111-1111-111111111111'
);

INSERT INTO public.member_streaks (
  id, gym_id, gym_member_id, freezes_available
) VALUES (
  '79300000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  1
);

INSERT INTO public.streak_freeze_transactions (
  id, gym_id, gym_member_id, transaction_type, amount, reason, metadata
) VALUES (
  '79400000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  'GRANT',
  1,
  'Concurrency fixture initial grant',
  '{"fixture":"streak_lock_ordering"}'::jsonb
);

INSERT INTO public.attendances (
  id, gym_id, gym_member_id, membership_id, attendance_date, occurred_at,
  method, status, created_by
) VALUES (
  '79500000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  '30000000-0000-0000-0000-000000000001',
  '2026-08-03',
  '2026-08-03 13:00:00+00',
  'MANUAL',
  'VALID',
  '11111111-1111-1111-1111-111111111111'
);

INSERT INTO public.streak_periods (
  id, gym_id, gym_member_id, member_streak_rule_id,
  period_start, period_end, period_start_at, period_end_at,
  timezone_snapshot, target_days_snapshot
) VALUES
  (
    '79200000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000001',
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    '79100000-0000-0000-0000-000000000001',
    '2026-08-03',
    '2026-08-09',
    '2026-08-03 03:00:00+00',
    '2026-08-10 03:00:00+00',
    'America/Montevideo',
    2
  ),
  (
    '79200000-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000001',
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    '79100000-0000-0000-0000-000000000001',
    '2026-08-10',
    '2026-08-16',
    '2026-08-10 03:00:00+00',
    '2026-08-17 03:00:00+00',
    'America/Montevideo',
    2
  );

-- Commit fixtures so the two independent PostgreSQL connections can see them.
COMMIT;

SELECT is(
  extensions.dblink_connect(
    'worker_a',
    format(
      'host=host.docker.internal port=54322 dbname=%s user=ytufit_streak_concurrency_login password=%s connect_timeout=5 application_name=ytufit_streak_worker_a',
      current_database(),
      (SELECT password FROM pg_temp.streak_concurrency_connection)
    )
  ),
  'OK',
  'First PostgreSQL worker connection is available'
);
SELECT is(
  extensions.dblink_connect(
    'worker_b',
    format(
      'host=host.docker.internal port=54322 dbname=%s user=ytufit_streak_concurrency_login password=%s connect_timeout=5 application_name=ytufit_streak_worker_b',
      current_database(),
      (SELECT password FROM pg_temp.streak_concurrency_connection)
    )
  ),
  'OK',
  'Second PostgreSQL worker connection is available'
);

-- Holding the canonical mutex makes both calls begin concurrently. Before the
-- fix they each retained a different period while waiting here, guaranteeing
-- the period -> projection deadlock after release.
BEGIN;
DO $$
BEGIN
  PERFORM ms.id
  FROM public.member_streaks ms
  WHERE ms.id = '79300000-0000-0000-0000-000000000001'
  FOR UPDATE;
END;
$$;
SELECT is(
  extensions.dblink_send_query(
    'worker_a',
    $$ SELECT * FROM streak_concurrency_test.run_finalize(
      '79200000-0000-0000-0000-000000000001',
      '2026-08-17 03:00:00+00'
    ) $$
  ),
  1,
  'First distinct-period finalization starts asynchronously'
);
SELECT is(
  extensions.dblink_send_query(
    'worker_b',
    $$ SELECT * FROM streak_concurrency_test.run_finalize(
      '79200000-0000-0000-0000-000000000002',
      '2026-08-17 03:00:00+00'
    ) $$
  ),
  1,
  'Second distinct-period finalization starts asynchronously'
);
SELECT ok(
  pg_temp.wait_for_streak_workers(2),
  'Both distinct-period finalizations wait on the same member mutex'
);
COMMIT;

SELECT lives_ok(
  $$ SELECT pg_temp.collect_streak_worker('distinct_finalize', 'worker_a') $$,
  'First distinct-period worker returns'
);
SELECT lives_ok(
  $$ SELECT pg_temp.collect_streak_worker('distinct_finalize', 'worker_b') $$,
  'Second distinct-period worker returns'
);
SELECT results_eq(
  $$
    SELECT worker, result IS NOT NULL, error_sqlstate, error_message
    FROM pg_temp.concurrency_worker_results
    WHERE phase = 'distinct_finalize'
    ORDER BY worker
  $$,
  $$ VALUES
    ('worker_a'::text, true, NULL::text, NULL::text),
    ('worker_b'::text, true, NULL::text, NULL::text)
  $$,
  'Concurrent finalizations of distinct periods both succeed without 40P01'
);
SELECT results_eq(
  $$
    SELECT period_start, status, valid_days, freeze_applied, finalized_at IS NOT NULL
    FROM public.streak_periods
    WHERE id IN (
      '79200000-0000-0000-0000-000000000001',
      '79200000-0000-0000-0000-000000000002'
    )
    ORDER BY period_start
  $$,
  $$ VALUES
    ('2026-08-03'::date, 'COMPLETED'::public.streak_period_status, 2::smallint, false, true),
    ('2026-08-10'::date, 'FROZEN'::public.streak_period_status, 0::smallint, true, true)
  $$,
  'Distinct-period finalization leaves both weekly truth rows coherent'
);
SELECT results_eq(
  $$
    SELECT current_streak, best_streak, freezes_available, current_period_id,
      last_completed_period_start, calculated_through
    FROM public.member_streaks
    WHERE id = '79300000-0000-0000-0000-000000000001'
  $$,
  $$ VALUES (
    1, 1, 0::smallint, NULL::uuid, '2026-08-03'::date, '2026-08-10'::date
  ) $$,
  'Distinct-period finalization does not increment the streak twice'
);
SELECT results_eq(
  $$
    SELECT transaction_type, count(*)::bigint
    FROM public.streak_freeze_transactions
    WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
      AND (
        id = '79400000-0000-0000-0000-000000000001'
        OR streak_period_id IN (
          '79200000-0000-0000-0000-000000000001',
          '79200000-0000-0000-0000-000000000002'
        )
      )
    GROUP BY transaction_type
    ORDER BY transaction_type
  $$,
  $$ VALUES
    ('GRANT'::public.streak_freeze_transaction_type, 1::bigint),
    ('CONSUME'::public.streak_freeze_transaction_type, 1::bigint)
  $$,
  'Distinct-period finalization records one grant and one consume only'
);

CREATE TEMP TABLE expected_concurrency_periods AS
SELECT id, status, valid_days, freeze_applied, finalized_at
FROM public.streak_periods
WHERE id IN (
  '79200000-0000-0000-0000-000000000001',
  '79200000-0000-0000-0000-000000000002'
);
CREATE TEMP TABLE expected_concurrency_projection AS
SELECT current_streak, best_streak, freezes_available, current_period_id,
  last_completed_period_start, calculated_through
FROM public.member_streaks
WHERE id = '79300000-0000-0000-0000-000000000001';
CREATE TEMP TABLE expected_concurrency_ledger AS
SELECT transaction_type, amount, streak_period_id, source_transaction_id,
  reversed_by_transaction_id
FROM public.streak_freeze_transactions
WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
  AND (
    id = '79400000-0000-0000-0000-000000000001'
    OR streak_period_id IN (
      '79200000-0000-0000-0000-000000000001',
      '79200000-0000-0000-0000-000000000002'
    )
  );

-- Queue recalculate first. With the old finalize order, recalculate acquired
-- the projection after release and waited on P1 retained by finalize, while
-- finalize waited on the projection: a deterministic 40P01 cycle.
BEGIN;
DO $$
BEGIN
  PERFORM ms.id
  FROM public.member_streaks ms
  WHERE ms.id = '79300000-0000-0000-0000-000000000001'
  FOR UPDATE;
END;
$$;
SELECT is(
  extensions.dblink_send_query(
    'worker_a',
    $$ SELECT * FROM streak_concurrency_test.run_recalculate(
      'cccccccc-cccc-cccc-cccc-cccccccccccc',
      '2026-08-03',
      '2026-08-17 03:00:00+00'
    ) $$
  ),
  1,
  'Recalculation starts asynchronously before concurrent finalization'
);
SELECT ok(
  pg_temp.wait_for_streak_workers(1),
  'Recalculation is first in the member mutex wait queue'
);
SELECT is(
  extensions.dblink_send_query(
    'worker_b',
    $$ SELECT * FROM streak_concurrency_test.run_finalize(
      '79200000-0000-0000-0000-000000000001',
      '2026-08-17 03:00:00+00'
    ) $$
  ),
  1,
  'Finalization starts concurrently with recalculation'
);
SELECT ok(
  pg_temp.wait_for_streak_workers(2),
  'Recalculation and finalization wait on the same member mutex'
);
COMMIT;

SELECT lives_ok(
  $$ SELECT pg_temp.collect_streak_worker('finalize_recalculate', 'worker_a') $$,
  'Concurrent recalculation worker returns'
);
SELECT lives_ok(
  $$ SELECT pg_temp.collect_streak_worker('finalize_recalculate', 'worker_b') $$,
  'Concurrent finalization worker returns'
);
SELECT results_eq(
  $$
    SELECT worker, result IS NOT NULL, error_sqlstate, error_message
    FROM pg_temp.concurrency_worker_results
    WHERE phase = 'finalize_recalculate'
    ORDER BY worker
  $$,
  $$ VALUES
    ('worker_a'::text, true, NULL::text, NULL::text),
    ('worker_b'::text, true, NULL::text, NULL::text)
  $$,
  'Concurrent finalize plus recalculate both succeed without 40P01'
);
SELECT results_eq(
  $$
    SELECT id, status, valid_days, freeze_applied, finalized_at
    FROM public.streak_periods
    WHERE id IN (
      '79200000-0000-0000-0000-000000000001',
      '79200000-0000-0000-0000-000000000002'
    )
    ORDER BY id
  $$,
  $$
    SELECT id, status, valid_days, freeze_applied, finalized_at
    FROM pg_temp.expected_concurrency_periods
    ORDER BY id
  $$,
  'Concurrent finalize plus recalculate preserves period truth'
);
SELECT results_eq(
  $$
    SELECT current_streak, best_streak, freezes_available, current_period_id,
      last_completed_period_start, calculated_through
    FROM public.member_streaks
    WHERE id = '79300000-0000-0000-0000-000000000001'
  $$,
  $$ SELECT * FROM pg_temp.expected_concurrency_projection $$,
  'Concurrent finalize plus recalculate preserves the logical projection'
);
SELECT results_eq(
  $$
    SELECT transaction_type, amount, streak_period_id, source_transaction_id,
      reversed_by_transaction_id
    FROM public.streak_freeze_transactions
    WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
      AND (
        id = '79400000-0000-0000-0000-000000000001'
        OR streak_period_id IN (
          '79200000-0000-0000-0000-000000000001',
          '79200000-0000-0000-0000-000000000002'
        )
      )
    ORDER BY transaction_type, streak_period_id, source_transaction_id
  $$,
  $$
    SELECT * FROM pg_temp.expected_concurrency_ledger
    ORDER BY transaction_type, streak_period_id, source_transaction_id
  $$,
  'Concurrent finalize plus recalculate does not duplicate consume or restore'
);

-- Two real sessions finalizing the same period serialize on the same mutex and
-- retain logical idempotency.
BEGIN;
DO $$
BEGIN
  PERFORM ms.id
  FROM public.member_streaks ms
  WHERE ms.id = '79300000-0000-0000-0000-000000000001'
  FOR UPDATE;
END;
$$;
SELECT is(
  extensions.dblink_send_query(
    'worker_a',
    $$ SELECT * FROM streak_concurrency_test.run_finalize(
      '79200000-0000-0000-0000-000000000001',
      '2026-08-17 03:00:00+00'
    ) $$
  ),
  1,
  'First same-period finalization starts asynchronously'
);
SELECT is(
  extensions.dblink_send_query(
    'worker_b',
    $$ SELECT * FROM streak_concurrency_test.run_finalize(
      '79200000-0000-0000-0000-000000000001',
      '2026-08-17 03:00:00+00'
    ) $$
  ),
  1,
  'Second same-period finalization starts asynchronously'
);
SELECT ok(
  pg_temp.wait_for_streak_workers(2),
  'Both same-period finalizations wait on the same member mutex'
);
COMMIT;

SELECT lives_ok(
  $$ SELECT pg_temp.collect_streak_worker('same_finalize', 'worker_a') $$,
  'First same-period worker returns'
);
SELECT lives_ok(
  $$ SELECT pg_temp.collect_streak_worker('same_finalize', 'worker_b') $$,
  'Second same-period worker returns'
);
SELECT results_eq(
  $$
    SELECT worker, result IS NOT NULL, error_sqlstate, error_message
    FROM pg_temp.concurrency_worker_results
    WHERE phase = 'same_finalize'
    ORDER BY worker
  $$,
  $$ VALUES
    ('worker_a'::text, true, NULL::text, NULL::text),
    ('worker_b'::text, true, NULL::text, NULL::text)
  $$,
  'Concurrent finalization of the same period succeeds without duplicate effects'
);
SELECT results_eq(
  $$
    SELECT current_streak, best_streak, freezes_available, current_period_id,
      last_completed_period_start, calculated_through
    FROM public.member_streaks
    WHERE id = '79300000-0000-0000-0000-000000000001'
  $$,
  $$ SELECT * FROM pg_temp.expected_concurrency_projection $$,
  'Same-period finalization preserves the logical projection'
);
SELECT results_eq(
  $$
    SELECT transaction_type, amount, streak_period_id, source_transaction_id,
      reversed_by_transaction_id
    FROM public.streak_freeze_transactions
    WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
      AND (
        id = '79400000-0000-0000-0000-000000000001'
        OR streak_period_id IN (
          '79200000-0000-0000-0000-000000000001',
          '79200000-0000-0000-0000-000000000002'
        )
      )
    ORDER BY transaction_type, streak_period_id, source_transaction_id
  $$,
  $$
    SELECT * FROM pg_temp.expected_concurrency_ledger
    ORDER BY transaction_type, streak_period_id, source_transaction_id
  $$,
  'Same-period finalization does not duplicate freeze ledger entries'
);

SELECT lives_ok(
  $$ SELECT private.recalculate_member_streak(
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    '2026-08-03',
    '2026-08-17 03:00:00+00'
  ) $$,
  'A repeated recalculation succeeds'
);
SELECT lives_ok(
  $$ SELECT private.recalculate_member_streak(
    'cccccccc-cccc-cccc-cccc-cccccccccccc',
    '2026-08-03',
    '2026-08-17 03:00:00+00'
  ) $$,
  'A second repeated recalculation succeeds'
);
SELECT results_eq(
  $$
    SELECT current_streak, best_streak, freezes_available, current_period_id,
      last_completed_period_start, calculated_through
    FROM public.member_streaks
    WHERE id = '79300000-0000-0000-0000-000000000001'
  $$,
  $$ SELECT * FROM pg_temp.expected_concurrency_projection $$,
  'Repeated recalculation preserves the logical projection'
);
SELECT results_eq(
  $$
    SELECT transaction_type, amount, streak_period_id, source_transaction_id,
      reversed_by_transaction_id
    FROM public.streak_freeze_transactions
    WHERE gym_member_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'
      AND (
        id = '79400000-0000-0000-0000-000000000001'
        OR streak_period_id IN (
          '79200000-0000-0000-0000-000000000001',
          '79200000-0000-0000-0000-000000000002'
        )
      )
    ORDER BY transaction_type, streak_period_id, source_transaction_id
  $$,
  $$
    SELECT * FROM pg_temp.expected_concurrency_ledger
    ORDER BY transaction_type, streak_period_id, source_transaction_id
  $$,
  'Repeated recalculation does not duplicate consume or restore'
);

SELECT is(
  extensions.dblink_disconnect('worker_a'),
  'OK',
  'First PostgreSQL worker disconnects cleanly'
);
SELECT is(
  extensions.dblink_disconnect('worker_b'),
  'OK',
  'Second PostgreSQL worker disconnects cleanly'
);

DROP SCHEMA streak_concurrency_test CASCADE;
DROP ROLE ytufit_streak_concurrency_login;
DELETE FROM public.streak_freeze_transactions
WHERE id = '79400000-0000-0000-0000-000000000001'
   OR streak_period_id IN (
     '79200000-0000-0000-0000-000000000001',
     '79200000-0000-0000-0000-000000000002'
   );
UPDATE public.member_streaks
SET current_period_id = NULL
WHERE id = '79300000-0000-0000-0000-000000000001';
DELETE FROM public.streak_periods
WHERE id IN (
  '79200000-0000-0000-0000-000000000001',
  '79200000-0000-0000-0000-000000000002'
);
DELETE FROM public.member_streaks
WHERE id = '79300000-0000-0000-0000-000000000001';
DELETE FROM public.member_streak_rules
WHERE id = '79100000-0000-0000-0000-000000000001';
DELETE FROM public.streak_rules
WHERE id = '79000000-0000-0000-0000-000000000001';
DELETE FROM public.attendances
WHERE id = '79500000-0000-0000-0000-000000000001';

SELECT * FROM finish();
