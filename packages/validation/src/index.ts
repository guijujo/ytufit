import { z } from 'zod';

export { z };

export const exerciseTrackingTypeSchema = z.enum([
  'WEIGHT_REPS',
  'REPS',
  'TIME',
  'DISTANCE_TIME',
  'WEIGHT_TIME',
  'WEIGHT_DISTANCE',
]);

export const exerciseStatusSchema = z.enum(['ACTIVE', 'INACTIVE']);
export const muscleInvolvementSchema = z.enum(['PRIMARY', 'SECONDARY']);
export const exerciseCategorySchema = z.enum([
  'STRENGTH',
  'CARDIO',
  'MOBILITY',
  'STRETCHING',
]);
export const exerciseMovementPatternSchema = z.enum([
  'PUSH',
  'PULL',
  'SQUAT',
  'HINGE',
  'LUNGE',
  'CARRY',
  'ROTATION',
  'ISOMETRIC',
  'CARDIO',
]);

export const routineStatusSchema = z.enum(['ACTIVE', 'INACTIVE', 'ARCHIVED']);
export const routineAssignmentStatusSchema = z.enum([
  'ACTIVE',
  'COMPLETED',
  'CANCELLED',
]);
export const workoutStatusSchema = z.enum([
  'IN_PROGRESS',
  'COMPLETED',
  'CANCELLED',
]);
export const workoutSetStatusSchema = z.enum([
  'PLANNED',
  'COMPLETED',
  'SKIPPED',
]);

const nullableTrimmedTextSchema = z
  .string()
  .trim()
  .transform((value) => (value.length > 0 ? value : null))
  .nullable()
  .optional();

const instructionsSchema = z
  .array(z.string().trim().min(1))
  .min(1)
  .nullable()
  .optional();

const nonNegativeNumberSchema = z.number().nonnegative().nullable().optional();
const nonNegativeIntegerSchema = z
  .number()
  .int()
  .nonnegative()
  .nullable()
  .optional();
const positiveIntegerSchema = z.number().int().positive();

export const exerciseSlugSchema = z
  .string()
  .regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/);

export const createGymExerciseSchema = z.object({
  gymId: z.uuid(),
  name: z.string().trim().min(1),
  slug: exerciseSlugSchema,
  description: nullableTrimmedTextSchema,
  instructions: instructionsSchema,
  trackingType: exerciseTrackingTypeSchema,
  category: exerciseCategorySchema,
  movementPattern: exerciseMovementPatternSchema,
  imageUrl: z.url().nullable().optional(),
  animationUrl: z.url().nullable().optional(),
});

export const updateGymExerciseSchema = createGymExerciseSchema
  .omit({ gymId: true })
  .extend({
    exerciseId: z.uuid(),
    status: exerciseStatusSchema,
  });

export const archiveGymExerciseSchema = z.object({
  exerciseId: z.uuid(),
});

export const setExerciseMusclesSchema = z
  .object({
    exerciseId: z.uuid(),
    muscles: z.array(
      z.object({
        muscleId: z.uuid(),
        involvement: muscleInvolvementSchema,
      }),
    ),
  })
  .refine(
    (value) =>
      new Set(value.muscles.map((muscle) => muscle.muscleId)).size ===
      value.muscles.length,
    'A muscle can only appear once per exercise',
  );

export const setExerciseEquipmentSchema = z
  .object({
    exerciseId: z.uuid(),
    equipmentIds: z.array(z.uuid()),
  })
  .refine(
    (value) => new Set(value.equipmentIds).size === value.equipmentIds.length,
    'Equipment can only appear once per exercise',
  );

export const createRoutineSchema = z.object({
  gymId: z.uuid(),
  name: z.string().trim().min(1),
  description: nullableTrimmedTextSchema,
});

export const updateRoutineSchema = createRoutineSchema
  .omit({ gymId: true })
  .extend({
    routineId: z.uuid(),
    status: routineStatusSchema,
  });

export const archiveRoutineSchema = z.object({
  routineId: z.uuid(),
});

export const routinePrescriptionSchema = z
  .object({
    exerciseId: z.uuid(),
    position: positiveIntegerSchema,
    setsTarget: positiveIntegerSchema.nullable().optional(),
    repsMin: nonNegativeIntegerSchema,
    repsMax: nonNegativeIntegerSchema,
    weightTarget: nonNegativeNumberSchema,
    durationSecondsTarget: nonNegativeIntegerSchema,
    distanceMetersTarget: nonNegativeNumberSchema,
    restSeconds: nonNegativeIntegerSchema,
    notes: nullableTrimmedTextSchema,
  })
  .refine(
    (value) =>
      value.repsMin == null ||
      value.repsMax == null ||
      value.repsMin <= value.repsMax,
    'repsMin must be less than or equal to repsMax',
  );

export const addRoutineExerciseSchema = routinePrescriptionSchema.extend({
  routineId: z.uuid(),
});

export const updateRoutineExerciseSchema = routinePrescriptionSchema.extend({
  routineExerciseId: z.uuid(),
});

export const removeRoutineExerciseSchema = z.object({
  routineExerciseId: z.uuid(),
});

export const reorderRoutineExercisesSchema = z
  .object({
    routineId: z.uuid(),
    order: z.array(
      z.object({
        id: z.uuid(),
        position: positiveIntegerSchema,
      }),
    ),
  })
  .refine(
    (value) =>
      new Set(value.order.map((item) => item.id)).size === value.order.length,
    'Routine exercise ids must be unique',
  )
  .refine(
    (value) =>
      new Set(value.order.map((item) => item.position)).size ===
      value.order.length,
    'Routine exercise positions must be unique',
  );

export const assignRoutineSchema = z.object({
  routineId: z.uuid(),
  gymMemberId: z.uuid(),
  startsAt: z.iso.datetime().nullable().optional(),
  notes: nullableTrimmedTextSchema,
});

export const completeRoutineAssignmentSchema = z.object({
  assignmentId: z.uuid(),
  endsAt: z.iso.datetime().nullable().optional(),
});

export const cancelRoutineAssignmentSchema =
  completeRoutineAssignmentSchema.extend({
    notes: nullableTrimmedTextSchema,
  });

export const createTrainerMemberAssignmentSchema = z.object({
  gymId: z.uuid(),
  trainerGymMemberId: z.uuid(),
  memberGymMemberId: z.uuid(),
});

export const deactivateTrainerMemberAssignmentSchema = z.object({
  assignmentId: z.uuid(),
});

export const startWorkoutSchema = z.object({
  routineAssignmentId: z.uuid(),
});

export const recordWorkoutSetSchema = z
  .object({
    workoutExerciseId: z.uuid(),
    setNumber: positiveIntegerSchema,
    trackingType: exerciseTrackingTypeSchema,
    status: workoutSetStatusSchema.default('COMPLETED'),
    reps: nonNegativeIntegerSchema,
    weight: nonNegativeNumberSchema,
    durationSeconds: nonNegativeIntegerSchema,
    distanceMeters: nonNegativeNumberSchema,
    notes: nullableTrimmedTextSchema,
  })
  .superRefine((value, ctx) => {
    const addIssue = (message: string) =>
      ctx.addIssue({ code: 'custom', message });

    if (value.status === 'PLANNED') {
      addIssue('recordWorkoutSet cannot write PLANNED status');
      return;
    }

    const hasReps = value.reps != null;
    const hasWeight = value.weight != null;
    const hasDuration = value.durationSeconds != null;
    const hasDistance = value.distanceMeters != null;

    if (value.status === 'SKIPPED') {
      if (hasReps || hasWeight || hasDuration || hasDistance) {
        addIssue('Skipped sets cannot include performance metrics');
      }
      return;
    }

    const requirements: Record<
      z.infer<typeof exerciseTrackingTypeSchema>,
      { reps: boolean; weight: boolean; duration: boolean; distance: boolean }
    > = {
      WEIGHT_REPS: {
        reps: true,
        weight: true,
        duration: false,
        distance: false,
      },
      REPS: { reps: true, weight: false, duration: false, distance: false },
      TIME: { reps: false, weight: false, duration: true, distance: false },
      DISTANCE_TIME: {
        reps: false,
        weight: false,
        duration: true,
        distance: true,
      },
      WEIGHT_TIME: {
        reps: false,
        weight: true,
        duration: true,
        distance: false,
      },
      WEIGHT_DISTANCE: {
        reps: false,
        weight: true,
        duration: false,
        distance: true,
      },
    };

    const expected = requirements[value.trackingType];
    if (
      hasReps !== expected.reps ||
      hasWeight !== expected.weight ||
      hasDuration !== expected.duration ||
      hasDistance !== expected.distance
    ) {
      addIssue(`${value.trackingType} metrics do not match tracking type`);
    }
  });

export const streakPeriodTypeSchema = z.enum(['WEEK']);
export const streakRuleStatusSchema = z.enum([
  'ACTIVE',
  'INACTIVE',
  'ARCHIVED',
]);
export const editableStreakRuleStatusSchema = z.enum(['ACTIVE', 'INACTIVE']);
export const memberStreakRuleStatusSchema = z.enum([
  'ACTIVE',
  'SCHEDULED',
  'ENDED',
]);
export const streakPeriodStatusSchema = z.enum([
  'OPEN',
  'COMPLETED',
  'FROZEN',
  'MISSED',
  'NOT_ELIGIBLE',
]);
export const streakFreezeTransactionTypeSchema = z.enum([
  'GRANT',
  'CONSUME',
  'RESTORE',
  'EXPIRE',
]);
export const streakPeriodEligibilityReasonSchema = z.enum([
  'NO_ACTIVE_MEMBERSHIP',
  'PARTIAL_INITIAL_PERIOD',
  'STREAK_NOT_ENABLED',
]);

export const createStreakRuleSchema = z.object({
  gymId: z.uuid(),
  name: z.string().trim().min(1),
  targetDays: z.number().int().min(1).max(7),
  maxFreezes: z.number().int().min(0).max(2).default(2),
  timezone: z.string().trim().min(1).nullable().optional(),
});

export const updateStreakRuleSchema = createStreakRuleSchema
  .omit({ gymId: true })
  .extend({
    streakRuleId: z.uuid(),
    status: editableStreakRuleStatusSchema.default('ACTIVE'),
  });

export const archiveStreakRuleSchema = z.object({
  streakRuleId: z.uuid(),
});

export const assignMemberStreakRuleSchema = z.object({
  gymId: z.uuid(),
  gymMemberId: z.uuid(),
  streakRuleId: z.uuid(),
});

export const changeMemberStreakRuleSchema = z.object({
  gymId: z.uuid(),
  gymMemberId: z.uuid(),
  newStreakRuleId: z.uuid(),
});

export const completeWorkoutSchema = z.object({
  workoutSessionId: z.uuid(),
});

export const cancelWorkoutSchema = completeWorkoutSchema.extend({
  reason: nullableTrimmedTextSchema,
});

export type CreateGymExerciseInput = z.infer<typeof createGymExerciseSchema>;
export type UpdateGymExerciseInput = z.infer<typeof updateGymExerciseSchema>;
export type ArchiveGymExerciseInput = z.infer<typeof archiveGymExerciseSchema>;
export type SetExerciseMusclesInput = z.infer<typeof setExerciseMusclesSchema>;
export type SetExerciseEquipmentInput = z.infer<
  typeof setExerciseEquipmentSchema
>;
export type CreateRoutineInput = z.infer<typeof createRoutineSchema>;
export type UpdateRoutineInput = z.infer<typeof updateRoutineSchema>;
export type ArchiveRoutineInput = z.infer<typeof archiveRoutineSchema>;
export type AddRoutineExerciseInput = z.infer<typeof addRoutineExerciseSchema>;
export type UpdateRoutineExerciseInput = z.infer<
  typeof updateRoutineExerciseSchema
>;
export type RemoveRoutineExerciseInput = z.infer<
  typeof removeRoutineExerciseSchema
>;
export type ReorderRoutineExercisesInput = z.infer<
  typeof reorderRoutineExercisesSchema
>;
export type AssignRoutineInput = z.infer<typeof assignRoutineSchema>;
export type CompleteRoutineAssignmentInput = z.infer<
  typeof completeRoutineAssignmentSchema
>;
export type CancelRoutineAssignmentInput = z.infer<
  typeof cancelRoutineAssignmentSchema
>;
export type CreateTrainerMemberAssignmentInput = z.infer<
  typeof createTrainerMemberAssignmentSchema
>;
export type DeactivateTrainerMemberAssignmentInput = z.infer<
  typeof deactivateTrainerMemberAssignmentSchema
>;
export type StartWorkoutInput = z.infer<typeof startWorkoutSchema>;
export type RecordWorkoutSetInput = z.infer<typeof recordWorkoutSetSchema>;

export type CreateStreakRuleInput = z.infer<typeof createStreakRuleSchema>;
export type UpdateStreakRuleInput = z.infer<typeof updateStreakRuleSchema>;
export type ArchiveStreakRuleInput = z.infer<typeof archiveStreakRuleSchema>;
export type AssignMemberStreakRuleInput = z.infer<
  typeof assignMemberStreakRuleSchema
>;
export type ChangeMemberStreakRuleInput = z.infer<
  typeof changeMemberStreakRuleSchema
>;

export type CompleteWorkoutInput = z.infer<typeof completeWorkoutSchema>;
export type CancelWorkoutInput = z.infer<typeof cancelWorkoutSchema>;
