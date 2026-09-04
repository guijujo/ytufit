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
