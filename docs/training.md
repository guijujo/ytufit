# Training

YtuFit Training is split into small stages so the data model can preserve tenant isolation and history before any UI or workout result capture exists.

## Exercise Library

The exercise library is the source catalog. Exercises can be `GLOBAL`, owned by YtuFit with `gym_id IS NULL`, or `GYM`, owned by a single gym tenant. Exercise muscles and equipment are normalized catalogs and relation tables. Application writes go through command RPCs; direct authenticated DML remains revoked.

## Routine

A routine is always owned by one gym. There are no global routines in this MVP. Gym Admins and Trainers can manage routines for their own gym. Members can only read routines that are connected to their own routine assignments.

## Routine Exercise

A routine exercise is a prescription row inside a routine. It stores order through an explicit `position`, not `created_at`. The row snapshots the exercise `tracking_type` so a future workout session can copy the prescription into historical workout rows without depending on later edits to the exercise catalog.

A routine can use an active global exercise or an active gym exercise from the same gym. A database trigger enforces this invariant and rejects private exercises from other tenants.

## Assignment

A routine assignment connects a routine to a gym member. Routine, target member, and assignment all carry the same `gym_id` and use composite tenant foreign keys where applicable. Multiple active assignments per member are allowed in this MVP. Completing or cancelling an assignment changes status and keeps the row for history.

## Trainer-Member Authorization

The repo did not yet include trainer-member authorization, so Training adds `trainer_member_assignments` as the minimal relation. Both gym members must belong to the same tenant; the trainer side must have the `TRAINER` role and the member side must have the `MEMBER` role. Gym Admins can create these assignments. Trainers can assign routines only to members currently assigned to them.

## Prescription vs Result

`routine_exercises` stores intended work only: sets, reps, target load, duration, distance, rest and notes. It does not store actual workout performance. Future workout sessions should copy the prescription into session/workout exercise/workout set tables so routine edits never alter historical results.

## Tenant Isolation

Training tables use explicit `gym_id`, composite foreign keys, RLS with `FORCE ROW LEVEL SECURITY`, and command RPC authorization based on `auth.uid()`. Platform admin status does not grant implicit cross-tenant routine or assignment access in this stage.

## Workout Session

A workout session is the historical execution of a routine assignment. Only the assigned Member can start a workout, and `start_workout` resolves the member and tenant from `auth.uid()` plus the routine assignment. The client does not provide `gym_id` or `gym_member_id`.

Only `ACTIVE` routine assignments whose `starts_at` is not in the future can start a workout. The MVP enforces one `IN_PROGRESS` workout per gym member with a partial unique index, so accidental double starts cannot create two active sessions.

## Workout Exercise Snapshot

`workout_exercises` are immutable historical snapshots of the prescription at workout start. They copy the source exercise name, slug, scope, tracking type, targets, rest and notes. Historical workout screens must read these snapshot fields, not join back to mutable routine or exercise rows for display-critical data.

This keeps the distinction clear: a routine is the current mutable prescription for future work; a workout exercise is what the member actually started from at that point in time.

## Workout Sets

`workout_sets` store actual member performance. When a routine exercise has `sets_target`, `start_workout` creates that many `PLANNED` sets. `record_workout_set` can update a planned set or create a new set during an `IN_PROGRESS` session.

`COMPLETED` sets require metrics that match the workout exercise tracking snapshot: `WEIGHT_REPS`, `REPS`, `TIME`, `DISTANCE_TIME`, `WEIGHT_TIME`, or `WEIGHT_DISTANCE`. `SKIPPED` sets do not require metrics and reject performance values.

## Workout Completion And Cancellation

Only the owner Member can complete or cancel their own `IN_PROGRESS` workout. Gym Admins and Trainers can read according to tenant and current trainer-member authorization, but they cannot record or forge member performance through workout commands.

Completing a workout leaves any remaining `PLANNED` sets as planned, representing prescribed sets that were not recorded. It does not auto-complete or auto-skip them. Once a workout is `COMPLETED` or `CANCELLED`, workout performance is immutable through the MVP RPCs and database guards prevent privileged accidental mutation of finalized sessions, snapshots and sets.

## Hardening Invariants

Workout sessions carry a database invariant tying `routine_assignment_id`, `gym_id`, `gym_member_id` and `routine_id` to the exact same routine assignment. Snapshot source ids are checked together while present, so a workout exercise cannot be deliberately pointed at a routine exercise and an unrelated source exercise. Source ids may still become `NULL` through allowed deletes without destroying historical snapshot fields.

Workout identity fields and set identity fields are immutable after insert. Members can finish an already-started workout even if the routine assignment is later completed or cancelled, or if the routine is archived after the workout began; terminal assignments still cannot start new workouts.

Trainer workout visibility is intentionally current-authorization based: deactivating a trainer-member assignment removes Trainer read access to that member's workout sessions, exercise snapshots and sets. The Member history remains, and Gym Admins keep same-tenant visibility.

## Attendance Boundary

Workout sessions do not call `register_attendance` and do not insert attendance rows in v2.0.3-D. Workout-driven attendance remains a later hardening step because it needs explicit anti-abuse rules before a member can generate attendance from workout activity.
