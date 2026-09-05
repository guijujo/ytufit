# Streak

YtuFit v2.0.4-1 introduces the schema and management commands for weekly streaks. This slice stores tenant-scoped rule definitions, immutable member rule snapshots, weekly period rows, freeze ledger transactions, and member streak projections.

## Scope

This is intentionally only the Streak schema and rule-management layer. It does not calculate streaks from Attendance, run scheduled period closing, update achievements, emit notifications, award points, or expose Training UI. Future engine work should write through server-side routines that preserve the invariants introduced here.

## Rules

Streak rules belong to one gym and currently support weekly periods only. Weeks start on Monday, target_days is constrained to 1..7, and max_freezes is constrained to 0..2. Rules are created and edited by Gym Admins through SECURITY DEFINER RPCs:

- create_streak_rule
- update_streak_rule
- archive_streak_rule
- assign_member_streak_rule
- change_member_streak_rule

CamelCase aliases exist for clients that use RPC names matching application command names.

## Assignment Snapshots

When a rule is assigned to a member, the relevant rule configuration is copied into member_streak_rules. Historical rows keep their snapshot even if the source rule is later edited or archived.

Assignment lifecycle:

- ACTIVE: currently effective. starts_at is in the past or present, and ends_at is either null or the future boundary where a scheduled successor takes over.
- SCHEDULED: future successor. starts_at is the future boundary where it may become active; ends_at is null.
- ENDED: historical assignment whose effective interval has ended.

change_member_streak_rule keeps the current ACTIVE assignment effective until the next Monday boundary in the current snapshot timezone, sets its ends_at to that boundary, and creates one SCHEDULED replacement assignment whose starts_at is the same boundary. SCHEDULED assignments are not currently effective; v2.0.4-2 is expected to activate them when the boundary is reached.

## Projections And Ledger

member_streaks stores the current projection for a gym member. Initial enrollment creates the projection and grants the configured freeze balance once. Rule changes preserve current_streak, best_streak, and freezes_available, and create no new GRANT transaction. Freeze grants are recorded in streak_freeze_transactions; future engine work should append CONSUME, RESTORE, and EXPIRE transactions instead of mutating history.

streak_periods stores weekly period state and snapshots the target and timezone used for that period. Periods and ledger entries enforce composite tenant/member foreign keys so rows cannot point at another member assignment or period.

## Security

All Streak tables have RLS enabled and forced. Authenticated users receive SELECT only; all writes are routed through RPCs or future server-side engine code. Gym Admins can manage tenant rules and read tenant member streak state. Members can read their own assignment history, periods, ledger, and projection. Trainers can read assignment history, periods, and projections only for members they are actively authorized to train; freeze ledger visibility remains member/admin only. Platform Admins do not receive implicit tenant Streak access.

## v2.0.4-2 Membership eligibility history

The Core Streak engine evaluates membership entitlement at `period_start_at` (Monday local midnight converted to an exact `TIMESTAMPTZ`). The audit follow-up adds `public.membership_status_history` in a new migration; the released v2.0.2 migrations remain unchanged.

The immutable ledger stores `id`, `gym_id`, `membership_id`, `from_status`, `to_status`, `effective_at`, `reason`, `changed_by`, `created_at`, and a generated `event_sequence` for deterministic ordering of equal-time transitions. Its composite `(membership_id, gym_id)` foreign key prevents cross-tenant references. `changed_by` is an actor UUID snapshot so removing an auth user cannot rewrite history.

### Authoritative coverage and transitions

`history_coverage_start` is derived as `MIN(effective_at)` over the membership's authoritative ledger entries. It is not inferred from contract dates or current row status.

- Existing memberships receive one migration-time baseline with `from_status = NULL` and their known status. The migration locks Membership writes and installs the baseline and command instrumentation in one transaction. This baseline says nothing about earlier states.
- Creating a membership records `NULL -> ACTIVE` at server execution time, including new contracts created by renewal or plan replacement. A backdated `starts_at` does not backdate coverage. A future `starts_at` still prevents entitlement before the contract begins.
- Suspension records `ACTIVE -> SUSPENDED`; successful resume records `SUSPENDED -> ACTIVE`, both at server execution time.
- Cancellation records `ACTIVE/SUSPENDED -> CANCELLED` at the exact `cancelled_at` assigned by the command, with the cancellation reason. Plan replacement records cancellation of the old contract and the initial event for the new one.
- Normalization in create/renew records `ACTIVE -> EXPIRED` at normalization time. The contractual `ends_at` independently ends entitlement; the event is not backdated to it. The existing expired-resume error rolls back its attempted normalization and ledger insertion together, preserving Membership business rules.

Every successful command appends its transition in the same transaction as the membership mutation, with `auth.uid()` as actor. A rejected command leaves no event. The recorder serializes on the membership row, checks the previous status and chronological order, and is callable only by the owner-executed commands. No public history-writing RPC or client-controlled timestamp is added.

### Historical eligibility algorithm

For the requested tenant/member, select contracts satisfying `starts_at <= period_start_at AND ends_at > period_start_at`. For each candidate, read the last event ordered by `effective_at DESC, event_sequence DESC` with `effective_at <= period_start_at`.

If any candidate has no event at or before that instant, raise SQLSTATE `55000`, message `Insufficient membership status history`, with membership and period details. This includes an empty history or a period before its baseline. Do not infer a state or return `NOT_ELIGIBLE`; inspect all candidates even if another contract is known to be active. Contract dates can prove absence outside their interval without status history. No covering contracts returns false.

With sufficient history for every candidate, eligibility is true if at least one reconstructed status is `ACTIVE`. `memberships.status`, `updated_at`, and legacy `cancelled_at` are never used as historical status truth. The historical event for a new cancellation uses the command's exact timestamp, not a legacy inference.

Transitions are inclusive at their instant: `effective_at <= period_start_at` is already effective. Suspension exactly Monday is ineligible; suspension one second later preserves that week's eligibility. When transitions share an instant, the later `event_sequence` wins. Contract ends are exclusive, so expiration before or exactly Monday is ineligible, while expiration Wednesday preserves Monday entitlement.

The private engine propagates insufficient-history errors atomically when eligibility is evaluated at closing/replay. Current weeks remain `OPEN` before `period_end_at`; partial initial rule weeks retain their existing independent eligibility rule. Known lack of membership becomes terminal `NOT_ELIGIBLE` only at the end boundary. Later suspension/cancellation leaves earlier covered weeks unchanged, including during freeze replay and projection rebuild.

### Security and test fixtures

History has forced RLS and inherits Membership SELECT visibility through its parent row. Members can read their own contracts, Gym Admins their tenant, and Platform Admins retain existing Membership visibility. This adds no Platform Admin Streak access or permission to execute the private engine. Client and service-role direct history DML is revoked; UPDATE, DELETE, and TRUNCATE also have immutable guards. Private SECURITY DEFINER helpers have a fixed search path and no PUBLIC EXECUTE.

Seed and pgTAP fixtures explicitly insert authoritative historical sequences as the privileged test owner. These synthetic events are not a production backfill algorithm. Legacy periods without such evidence are rejected.

This follow-up changes no access limits, pricing, plan/renewal rules, or Attendance semantics. Streak continues to read Attendance only. There is no Attendance-to-Streak trigger, cron, or v2.0.4-3 integration.

## Historical rule resolution

Rule assignment lifecycle (`SCHEDULED`, `ACTIVE`, `ENDED`) is operational state. It is not used to choose the assignment for a historical week. `private.resolve_streak_rule_for_period` derives the member's tenant from its Streak projection and evaluates every assignment against that assignment's timezone: `starts_at < next Monday 00:00 local` and `ends_at IS NULL OR ends_at > Monday 00:00 local`. These exact `TIMESTAMPTZ` boundaries preserve DST behavior.

Exactly one matching interval is required. No match raises `P0002`; multiple matches raise `23514` with the candidate IDs. Current uniqueness constraints only limit present lifecycle states, so the explicit ambiguity failure also protects malformed overlapping historical `ENDED` rows.

`ensure_streak_period` first returns an existing period, preserving its `member_streak_rule_id`, `timezone_snapshot`, and `target_days_snapshot`. For a new period it calls the temporal resolver without activating lifecycle state. Therefore asking for an old week has no `SCHEDULED -> ACTIVE -> ENDED` side effect. Operational activation remains in `activate_due_streak_rule`, including its normal call from projection recalculation. A new week can be resolved from a due `SCHEDULED` interval before that lifecycle bookkeeping runs; replay of an existing week never re-resolves its snapshots.
