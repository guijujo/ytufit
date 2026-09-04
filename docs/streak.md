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

change_member_streak_rule ends the current assignment at the next Monday boundary in the current snapshot timezone and creates the replacement assignment at that same boundary. The model still keeps exactly one ACTIVE assignment row per member.

## Projections And Ledger

member_streaks stores the current projection for a gym member. Initial assignment creates the projection and grants the configured freeze balance. Freeze grants are recorded in streak_freeze_transactions; future engine work should append CONSUME, RESTORE, and EXPIRE transactions instead of mutating history.

streak_periods stores weekly period state and snapshots the target and timezone used for that period. Periods and ledger entries enforce composite tenant/member foreign keys so rows cannot point at another member assignment or period.

## Security

All Streak tables have RLS enabled and forced. Authenticated users receive SELECT only; all writes are routed through RPCs or future server-side engine code. Gym Admins can manage tenant rules and read tenant member streak state. Members can read their own assignment history, periods, ledger, and projection. Trainers can read assignment history, periods, and projections only for members they are actively authorized to train; freeze ledger visibility remains member/admin only. Platform Admins do not receive implicit tenant Streak access.
