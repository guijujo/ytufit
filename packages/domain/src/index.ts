export const gymRoles = ['GYM_ADMIN', 'TRAINER', 'MEMBER'] as const;
export type GymRole = (typeof gymRoles)[number];

export const platformRoles = ['PLATFORM_ADMIN'] as const;
export type PlatformRole = (typeof platformRoles)[number];

export const memberStatuses = ['ACTIVE', 'SUSPENDED', 'INACTIVE'] as const;
export type MemberStatus = (typeof memberStatuses)[number];

export const exerciseScopes = ['GLOBAL', 'GYM'] as const;
export type ExerciseScope = (typeof exerciseScopes)[number];

export const exerciseStatuses = ['ACTIVE', 'INACTIVE'] as const;
export type ExerciseStatus = (typeof exerciseStatuses)[number];

export const exerciseTrackingTypes = [
  'WEIGHT_REPS',
  'REPS',
  'TIME',
  'DISTANCE_TIME',
  'WEIGHT_TIME',
  'WEIGHT_DISTANCE',
] as const;
export type ExerciseTrackingType = (typeof exerciseTrackingTypes)[number];

export const muscleInvolvements = ['PRIMARY', 'SECONDARY'] as const;
export type MuscleInvolvement = (typeof muscleInvolvements)[number];

export const exerciseCategories = [
  'STRENGTH',
  'CARDIO',
  'MOBILITY',
  'STRETCHING',
] as const;
export type ExerciseCategory = (typeof exerciseCategories)[number];

export const exerciseMovementPatterns = [
  'PUSH',
  'PULL',
  'SQUAT',
  'HINGE',
  'LUNGE',
  'CARRY',
  'ROTATION',
  'ISOMETRIC',
  'CARDIO',
] as const;
export type ExerciseMovementPattern = (typeof exerciseMovementPatterns)[number];

export const routineStatuses = ['ACTIVE', 'INACTIVE', 'ARCHIVED'] as const;
export type RoutineStatus = (typeof routineStatuses)[number];

export const routineAssignmentStatuses = [
  'ACTIVE',
  'COMPLETED',
  'CANCELLED',
] as const;
export type RoutineAssignmentStatus =
  (typeof routineAssignmentStatuses)[number];

export const trainerMemberAssignmentStatuses = ['ACTIVE', 'INACTIVE'] as const;
export type TrainerMemberAssignmentStatus =
  (typeof trainerMemberAssignmentStatuses)[number];

export const streakPeriodTypes = ['WEEK'] as const;
export type StreakPeriodType = (typeof streakPeriodTypes)[number];

export const streakRuleStatuses = ['ACTIVE', 'INACTIVE', 'ARCHIVED'] as const;
export type StreakRuleStatus = (typeof streakRuleStatuses)[number];

export const memberStreakRuleStatuses = ['ACTIVE', 'ENDED'] as const;
export type MemberStreakRuleStatus = (typeof memberStreakRuleStatuses)[number];

export const streakPeriodStatuses = [
  'OPEN',
  'COMPLETED',
  'FROZEN',
  'MISSED',
  'NOT_ELIGIBLE',
] as const;
export type StreakPeriodStatus = (typeof streakPeriodStatuses)[number];

export const streakFreezeTransactionTypes = [
  'GRANT',
  'CONSUME',
  'RESTORE',
  'EXPIRE',
] as const;
export type StreakFreezeTransactionType =
  (typeof streakFreezeTransactionTypes)[number];

export const streakPeriodEligibilityReasons = [
  'NO_ACTIVE_MEMBERSHIP',
  'PARTIAL_INITIAL_PERIOD',
  'STREAK_NOT_ENABLED',
] as const;
export type StreakPeriodEligibilityReason =
  (typeof streakPeriodEligibilityReasons)[number];

export const domainEvents = [
  'ATTENDANCE_CREATED',
  'WORKOUT_COMPLETED',
  'STREAK_COMPLETED',
  'STREAK_LOST',
  'FREEZE_USED',
  'ACHIEVEMENT_UNLOCKED',
  'MEMBERSHIP_EXPIRING',
  'BIRTHDAY',
  'REWARD_UNLOCKED',
] as const;
export type DomainEventName = (typeof domainEvents)[number];
