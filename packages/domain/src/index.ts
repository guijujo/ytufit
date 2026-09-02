export const gymRoles = ['GYM_ADMIN', 'TRAINER', 'MEMBER'] as const;
export type GymRole = (typeof gymRoles)[number];

export const platformRoles = ['PLATFORM_ADMIN'] as const;
export type PlatformRole = (typeof platformRoles)[number];

export const memberStatuses = ['ACTIVE', 'SUSPENDED', 'INACTIVE'] as const;
export type MemberStatus = (typeof memberStatuses)[number];

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
