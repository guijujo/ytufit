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

export type CreateGymExerciseInput = z.infer<typeof createGymExerciseSchema>;
export type UpdateGymExerciseInput = z.infer<typeof updateGymExerciseSchema>;
export type ArchiveGymExerciseInput = z.infer<typeof archiveGymExerciseSchema>;
