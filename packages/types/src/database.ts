export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

export type Database = {
  graphql_public: {
    Tables: {
      [_ in never]: never;
    };
    Views: {
      [_ in never]: never;
    };
    Functions: {
      graphql: {
        Args: {
          extensions?: Json;
          operationName?: string;
          query?: string;
          variables?: Json;
        };
        Returns: Json;
      };
    };
    Enums: {
      [_ in never]: never;
    };
    CompositeTypes: {
      [_ in never]: never;
    };
  };
  public: {
    Tables: {
      attendances: {
        Row: {
          attendance_date: string;
          cancellation_reason: string | null;
          cancelled_at: string | null;
          cancelled_by: string | null;
          created_at: string;
          created_by: string | null;
          gym_id: string;
          gym_member_id: string;
          id: string;
          membership_id: string | null;
          method: Database['public']['Enums']['attendance_method'];
          occurred_at: string;
          source_reference: string | null;
          status: Database['public']['Enums']['attendance_status'];
          updated_at: string;
        };
        Insert: {
          attendance_date: string;
          cancellation_reason?: string | null;
          cancelled_at?: string | null;
          cancelled_by?: string | null;
          created_at?: string;
          created_by?: string | null;
          gym_id: string;
          gym_member_id: string;
          id?: string;
          membership_id?: string | null;
          method: Database['public']['Enums']['attendance_method'];
          occurred_at: string;
          source_reference?: string | null;
          status?: Database['public']['Enums']['attendance_status'];
          updated_at?: string;
        };
        Update: {
          attendance_date?: string;
          cancellation_reason?: string | null;
          cancelled_at?: string | null;
          cancelled_by?: string | null;
          created_at?: string;
          created_by?: string | null;
          gym_id?: string;
          gym_member_id?: string;
          id?: string;
          membership_id?: string | null;
          method?: Database['public']['Enums']['attendance_method'];
          occurred_at?: string;
          source_reference?: string | null;
          status?: Database['public']['Enums']['attendance_status'];
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'attendances_gym_id_fkey';
            columns: ['gym_id'];
            isOneToOne: false;
            referencedRelation: 'gyms';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'attendances_gym_member_fk';
            columns: ['gym_member_id', 'gym_id'];
            isOneToOne: false;
            referencedRelation: 'gym_members';
            referencedColumns: ['id', 'gym_id'];
          },
          {
            foreignKeyName: 'attendances_membership_fk';
            columns: ['membership_id', 'gym_id'];
            isOneToOne: false;
            referencedRelation: 'memberships';
            referencedColumns: ['id', 'gym_id'];
          },
        ];
      };
      equipment: {
        Row: {
          code: string;
          created_at: string;
          id: string;
          name: string;
          updated_at: string;
        };
        Insert: {
          code: string;
          created_at?: string;
          id?: string;
          name: string;
          updated_at?: string;
        };
        Update: {
          code?: string;
          created_at?: string;
          id?: string;
          name?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      exercise_equipment: {
        Row: {
          created_at: string;
          equipment_id: string;
          exercise_id: string;
        };
        Insert: {
          created_at?: string;
          equipment_id: string;
          exercise_id: string;
        };
        Update: {
          created_at?: string;
          equipment_id?: string;
          exercise_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'exercise_equipment_equipment_id_fkey';
            columns: ['equipment_id'];
            isOneToOne: false;
            referencedRelation: 'equipment';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'exercise_equipment_exercise_id_fkey';
            columns: ['exercise_id'];
            isOneToOne: false;
            referencedRelation: 'exercises';
            referencedColumns: ['id'];
          },
        ];
      };
      exercise_muscles: {
        Row: {
          created_at: string;
          exercise_id: string;
          involvement: Database['public']['Enums']['muscle_involvement'];
          muscle_id: string;
        };
        Insert: {
          created_at?: string;
          exercise_id: string;
          involvement: Database['public']['Enums']['muscle_involvement'];
          muscle_id: string;
        };
        Update: {
          created_at?: string;
          exercise_id?: string;
          involvement?: Database['public']['Enums']['muscle_involvement'];
          muscle_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'exercise_muscles_exercise_id_fkey';
            columns: ['exercise_id'];
            isOneToOne: false;
            referencedRelation: 'exercises';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'exercise_muscles_muscle_id_fkey';
            columns: ['muscle_id'];
            isOneToOne: false;
            referencedRelation: 'muscles';
            referencedColumns: ['id'];
          },
        ];
      };
      exercises: {
        Row: {
          animation_url: string | null;
          category: Database['public']['Enums']['exercise_category'];
          created_at: string;
          created_by: string | null;
          deleted_at: string | null;
          description: string | null;
          gym_id: string | null;
          id: string;
          image_url: string | null;
          instructions: string[] | null;
          movement_pattern: Database['public']['Enums']['exercise_movement_pattern'];
          name: string;
          scope: Database['public']['Enums']['exercise_scope'];
          slug: string;
          status: Database['public']['Enums']['exercise_status'];
          tracking_type: Database['public']['Enums']['exercise_tracking_type'];
          updated_at: string;
        };
        Insert: {
          animation_url?: string | null;
          category: Database['public']['Enums']['exercise_category'];
          created_at?: string;
          created_by?: string | null;
          deleted_at?: string | null;
          description?: string | null;
          gym_id?: string | null;
          id?: string;
          image_url?: string | null;
          instructions?: string[] | null;
          movement_pattern: Database['public']['Enums']['exercise_movement_pattern'];
          name: string;
          scope: Database['public']['Enums']['exercise_scope'];
          slug: string;
          status?: Database['public']['Enums']['exercise_status'];
          tracking_type: Database['public']['Enums']['exercise_tracking_type'];
          updated_at?: string;
        };
        Update: {
          animation_url?: string | null;
          category?: Database['public']['Enums']['exercise_category'];
          created_at?: string;
          created_by?: string | null;
          deleted_at?: string | null;
          description?: string | null;
          gym_id?: string | null;
          id?: string;
          image_url?: string | null;
          instructions?: string[] | null;
          movement_pattern?: Database['public']['Enums']['exercise_movement_pattern'];
          name?: string;
          scope?: Database['public']['Enums']['exercise_scope'];
          slug?: string;
          status?: Database['public']['Enums']['exercise_status'];
          tracking_type?: Database['public']['Enums']['exercise_tracking_type'];
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'exercises_gym_id_fkey';
            columns: ['gym_id'];
            isOneToOne: false;
            referencedRelation: 'gyms';
            referencedColumns: ['id'];
          },
        ];
      };
      gym_invitations: {
        Row: {
          accepted_at: string | null;
          accepted_by: string | null;
          created_at: string;
          email: string;
          expires_at: string;
          gym_id: string;
          id: string;
          invited_by: string;
          role_id: string;
          status: string;
          token_hash: string;
          updated_at: string;
        };
        Insert: {
          accepted_at?: string | null;
          accepted_by?: string | null;
          created_at?: string;
          email: string;
          expires_at: string;
          gym_id: string;
          id?: string;
          invited_by: string;
          role_id: string;
          status?: string;
          token_hash: string;
          updated_at?: string;
        };
        Update: {
          accepted_at?: string | null;
          accepted_by?: string | null;
          created_at?: string;
          email?: string;
          expires_at?: string;
          gym_id?: string;
          id?: string;
          invited_by?: string;
          role_id?: string;
          status?: string;
          token_hash?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'gym_invitations_gym_id_fkey';
            columns: ['gym_id'];
            isOneToOne: false;
            referencedRelation: 'gyms';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'gym_invitations_role_id_fkey';
            columns: ['role_id'];
            isOneToOne: false;
            referencedRelation: 'roles';
            referencedColumns: ['id'];
          },
        ];
      };
      gym_join_requests: {
        Row: {
          created_at: string;
          gym_id: string;
          id: string;
          note: string | null;
          reviewed_at: string | null;
          reviewed_by: string | null;
          status: string;
          updated_at: string;
          user_id: string;
        };
        Insert: {
          created_at?: string;
          gym_id: string;
          id?: string;
          note?: string | null;
          reviewed_at?: string | null;
          reviewed_by?: string | null;
          status?: string;
          updated_at?: string;
          user_id: string;
        };
        Update: {
          created_at?: string;
          gym_id?: string;
          id?: string;
          note?: string | null;
          reviewed_at?: string | null;
          reviewed_by?: string | null;
          status?: string;
          updated_at?: string;
          user_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'gym_join_requests_gym_id_fkey';
            columns: ['gym_id'];
            isOneToOne: false;
            referencedRelation: 'gyms';
            referencedColumns: ['id'];
          },
        ];
      };
      gym_member_roles: {
        Row: {
          created_at: string;
          gym_member_id: string;
          role_id: string;
        };
        Insert: {
          created_at?: string;
          gym_member_id: string;
          role_id: string;
        };
        Update: {
          created_at?: string;
          gym_member_id?: string;
          role_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'gym_member_roles_gym_member_id_fkey';
            columns: ['gym_member_id'];
            isOneToOne: false;
            referencedRelation: 'gym_members';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'gym_member_roles_role_id_fkey';
            columns: ['role_id'];
            isOneToOne: false;
            referencedRelation: 'roles';
            referencedColumns: ['id'];
          },
        ];
      };
      gym_members: {
        Row: {
          created_at: string;
          gym_id: string;
          id: string;
          joined_at: string;
          status: string;
          updated_at: string;
          user_id: string;
        };
        Insert: {
          created_at?: string;
          gym_id: string;
          id?: string;
          joined_at?: string;
          status?: string;
          updated_at?: string;
          user_id: string;
        };
        Update: {
          created_at?: string;
          gym_id?: string;
          id?: string;
          joined_at?: string;
          status?: string;
          updated_at?: string;
          user_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'gym_members_gym_id_fkey';
            columns: ['gym_id'];
            isOneToOne: false;
            referencedRelation: 'gyms';
            referencedColumns: ['id'];
          },
        ];
      };
      gyms: {
        Row: {
          created_at: string;
          id: string;
          name: string;
          slug: string;
          status: string;
          timezone: string;
          updated_at: string;
        };
        Insert: {
          created_at?: string;
          id?: string;
          name: string;
          slug: string;
          status?: string;
          timezone?: string;
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          id?: string;
          name?: string;
          slug?: string;
          status?: string;
          timezone?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      membership_plans: {
        Row: {
          access_limit: number | null;
          access_type: Database['public']['Enums']['membership_access_type'];
          created_at: string;
          currency: string;
          deleted_at: string | null;
          description: string | null;
          duration_days: number;
          frequency_period:
            Database['public']['Enums']['membership_frequency_period'] | null;
          gym_id: string;
          id: string;
          name: string;
          price: number;
          status: Database['public']['Enums']['membership_plan_status'];
          target: number | null;
          updated_at: string;
        };
        Insert: {
          access_limit?: number | null;
          access_type: Database['public']['Enums']['membership_access_type'];
          created_at?: string;
          currency?: string;
          deleted_at?: string | null;
          description?: string | null;
          duration_days: number;
          frequency_period?:
            Database['public']['Enums']['membership_frequency_period'] | null;
          gym_id: string;
          id?: string;
          name: string;
          price: number;
          status?: Database['public']['Enums']['membership_plan_status'];
          target?: number | null;
          updated_at?: string;
        };
        Update: {
          access_limit?: number | null;
          access_type?: Database['public']['Enums']['membership_access_type'];
          created_at?: string;
          currency?: string;
          deleted_at?: string | null;
          description?: string | null;
          duration_days?: number;
          frequency_period?:
            Database['public']['Enums']['membership_frequency_period'] | null;
          gym_id?: string;
          id?: string;
          name?: string;
          price?: number;
          status?: Database['public']['Enums']['membership_plan_status'];
          target?: number | null;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'membership_plans_gym_id_fkey';
            columns: ['gym_id'];
            isOneToOne: false;
            referencedRelation: 'gyms';
            referencedColumns: ['id'];
          },
        ];
      };
      memberships: {
        Row: {
          access_limit_snapshot: number | null;
          access_type_snapshot: Database['public']['Enums']['membership_access_type'];
          cancellation_reason: string | null;
          cancelled_at: string | null;
          contracted_price: number;
          created_at: string;
          currency: string;
          ends_at: string;
          gym_id: string;
          gym_member_id: string;
          id: string;
          membership_plan_id: string;
          period_snapshot:
            Database['public']['Enums']['membership_frequency_period'] | null;
          starts_at: string;
          status: Database['public']['Enums']['membership_status'];
          target_snapshot: number | null;
          updated_at: string;
        };
        Insert: {
          access_limit_snapshot?: number | null;
          access_type_snapshot: Database['public']['Enums']['membership_access_type'];
          cancellation_reason?: string | null;
          cancelled_at?: string | null;
          contracted_price: number;
          created_at?: string;
          currency: string;
          ends_at: string;
          gym_id: string;
          gym_member_id: string;
          id?: string;
          membership_plan_id: string;
          period_snapshot?:
            Database['public']['Enums']['membership_frequency_period'] | null;
          starts_at: string;
          status?: Database['public']['Enums']['membership_status'];
          target_snapshot?: number | null;
          updated_at?: string;
        };
        Update: {
          access_limit_snapshot?: number | null;
          access_type_snapshot?: Database['public']['Enums']['membership_access_type'];
          cancellation_reason?: string | null;
          cancelled_at?: string | null;
          contracted_price?: number;
          created_at?: string;
          currency?: string;
          ends_at?: string;
          gym_id?: string;
          gym_member_id?: string;
          id?: string;
          membership_plan_id?: string;
          period_snapshot?:
            Database['public']['Enums']['membership_frequency_period'] | null;
          starts_at?: string;
          status?: Database['public']['Enums']['membership_status'];
          target_snapshot?: number | null;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'memberships_gym_id_fkey';
            columns: ['gym_id'];
            isOneToOne: false;
            referencedRelation: 'gyms';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'memberships_gym_member_fk';
            columns: ['gym_member_id', 'gym_id'];
            isOneToOne: false;
            referencedRelation: 'gym_members';
            referencedColumns: ['id', 'gym_id'];
          },
          {
            foreignKeyName: 'memberships_plan_fk';
            columns: ['membership_plan_id', 'gym_id'];
            isOneToOne: false;
            referencedRelation: 'membership_plans';
            referencedColumns: ['id', 'gym_id'];
          },
        ];
      };
      muscle_groups: {
        Row: {
          code: string;
          created_at: string;
          display_order: number;
          id: string;
          name: string;
          updated_at: string;
        };
        Insert: {
          code: string;
          created_at?: string;
          display_order?: number;
          id?: string;
          name: string;
          updated_at?: string;
        };
        Update: {
          code?: string;
          created_at?: string;
          display_order?: number;
          id?: string;
          name?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      muscles: {
        Row: {
          code: string;
          created_at: string;
          id: string;
          map_key: string | null;
          muscle_group_id: string;
          name: string;
          updated_at: string;
        };
        Insert: {
          code: string;
          created_at?: string;
          id?: string;
          map_key?: string | null;
          muscle_group_id: string;
          name: string;
          updated_at?: string;
        };
        Update: {
          code?: string;
          created_at?: string;
          id?: string;
          map_key?: string | null;
          muscle_group_id?: string;
          name?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'muscles_muscle_group_id_fkey';
            columns: ['muscle_group_id'];
            isOneToOne: false;
            referencedRelation: 'muscle_groups';
            referencedColumns: ['id'];
          },
        ];
      };
      platform_admins: {
        Row: {
          created_at: string;
          user_id: string;
        };
        Insert: {
          created_at?: string;
          user_id: string;
        };
        Update: {
          created_at?: string;
          user_id?: string;
        };
        Relationships: [];
      };
      profiles: {
        Row: {
          avatar_path: string | null;
          birth_date: string | null;
          created_at: string;
          first_name: string | null;
          id: string;
          last_name: string | null;
          phone: string | null;
          status: string;
          updated_at: string;
        };
        Insert: {
          avatar_path?: string | null;
          birth_date?: string | null;
          created_at?: string;
          first_name?: string | null;
          id: string;
          last_name?: string | null;
          phone?: string | null;
          status?: string;
          updated_at?: string;
        };
        Update: {
          avatar_path?: string | null;
          birth_date?: string | null;
          created_at?: string;
          first_name?: string | null;
          id?: string;
          last_name?: string | null;
          phone?: string | null;
          status?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      roles: {
        Row: {
          created_at: string;
          description: string | null;
          id: string;
          name: string;
        };
        Insert: {
          created_at?: string;
          description?: string | null;
          id?: string;
          name: string;
        };
        Update: {
          created_at?: string;
          description?: string | null;
          id?: string;
          name?: string;
        };
        Relationships: [];
      };
      routine_assignments: {
        Row: {
          assigned_by: string;
          created_at: string;
          ends_at: string | null;
          gym_id: string;
          gym_member_id: string;
          id: string;
          notes: string | null;
          routine_id: string;
          starts_at: string;
          status: Database['public']['Enums']['routine_assignment_status'];
          updated_at: string;
        };
        Insert: {
          assigned_by: string;
          created_at?: string;
          ends_at?: string | null;
          gym_id: string;
          gym_member_id: string;
          id?: string;
          notes?: string | null;
          routine_id: string;
          starts_at?: string;
          status?: Database['public']['Enums']['routine_assignment_status'];
          updated_at?: string;
        };
        Update: {
          assigned_by?: string;
          created_at?: string;
          ends_at?: string | null;
          gym_id?: string;
          gym_member_id?: string;
          id?: string;
          notes?: string | null;
          routine_id?: string;
          starts_at?: string;
          status?: Database['public']['Enums']['routine_assignment_status'];
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'routine_assignments_member_fk';
            columns: ['gym_member_id', 'gym_id'];
            isOneToOne: false;
            referencedRelation: 'gym_members';
            referencedColumns: ['id', 'gym_id'];
          },
          {
            foreignKeyName: 'routine_assignments_routine_fk';
            columns: ['routine_id', 'gym_id'];
            isOneToOne: false;
            referencedRelation: 'routines';
            referencedColumns: ['id', 'gym_id'];
          },
        ];
      };
      routine_exercises: {
        Row: {
          created_at: string;
          distance_meters_target: number | null;
          duration_seconds_target: number | null;
          exercise_id: string;
          gym_id: string;
          id: string;
          notes: string | null;
          position: number;
          reps_max: number | null;
          reps_min: number | null;
          rest_seconds: number | null;
          routine_id: string;
          sets_target: number | null;
          tracking_type: Database['public']['Enums']['exercise_tracking_type'];
          updated_at: string;
          weight_target: number | null;
        };
        Insert: {
          created_at?: string;
          distance_meters_target?: number | null;
          duration_seconds_target?: number | null;
          exercise_id: string;
          gym_id: string;
          id?: string;
          notes?: string | null;
          position: number;
          reps_max?: number | null;
          reps_min?: number | null;
          rest_seconds?: number | null;
          routine_id: string;
          sets_target?: number | null;
          tracking_type: Database['public']['Enums']['exercise_tracking_type'];
          updated_at?: string;
          weight_target?: number | null;
        };
        Update: {
          created_at?: string;
          distance_meters_target?: number | null;
          duration_seconds_target?: number | null;
          exercise_id?: string;
          gym_id?: string;
          id?: string;
          notes?: string | null;
          position?: number;
          reps_max?: number | null;
          reps_min?: number | null;
          rest_seconds?: number | null;
          routine_id?: string;
          sets_target?: number | null;
          tracking_type?: Database['public']['Enums']['exercise_tracking_type'];
          updated_at?: string;
          weight_target?: number | null;
        };
        Relationships: [
          {
            foreignKeyName: 'routine_exercises_exercise_id_fkey';
            columns: ['exercise_id'];
            isOneToOne: false;
            referencedRelation: 'exercises';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'routine_exercises_routine_fk';
            columns: ['routine_id', 'gym_id'];
            isOneToOne: false;
            referencedRelation: 'routines';
            referencedColumns: ['id', 'gym_id'];
          },
        ];
      };
      routines: {
        Row: {
          created_at: string;
          created_by: string | null;
          deleted_at: string | null;
          description: string | null;
          gym_id: string;
          id: string;
          name: string;
          status: Database['public']['Enums']['routine_status'];
          updated_at: string;
        };
        Insert: {
          created_at?: string;
          created_by?: string | null;
          deleted_at?: string | null;
          description?: string | null;
          gym_id: string;
          id?: string;
          name: string;
          status?: Database['public']['Enums']['routine_status'];
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          created_by?: string | null;
          deleted_at?: string | null;
          description?: string | null;
          gym_id?: string;
          id?: string;
          name?: string;
          status?: Database['public']['Enums']['routine_status'];
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'routines_gym_id_fkey';
            columns: ['gym_id'];
            isOneToOne: false;
            referencedRelation: 'gyms';
            referencedColumns: ['id'];
          },
        ];
      };
      trainer_member_assignments: {
        Row: {
          created_at: string;
          created_by: string | null;
          ended_at: string | null;
          gym_id: string;
          id: string;
          member_gym_member_id: string;
          status: Database['public']['Enums']['trainer_member_assignment_status'];
          trainer_gym_member_id: string;
          updated_at: string;
        };
        Insert: {
          created_at?: string;
          created_by?: string | null;
          ended_at?: string | null;
          gym_id: string;
          id?: string;
          member_gym_member_id: string;
          status?: Database['public']['Enums']['trainer_member_assignment_status'];
          trainer_gym_member_id: string;
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          created_by?: string | null;
          ended_at?: string | null;
          gym_id?: string;
          id?: string;
          member_gym_member_id?: string;
          status?: Database['public']['Enums']['trainer_member_assignment_status'];
          trainer_gym_member_id?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'trainer_member_assignments_gym_id_fkey';
            columns: ['gym_id'];
            isOneToOne: false;
            referencedRelation: 'gyms';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'trainer_member_assignments_member_fk';
            columns: ['member_gym_member_id', 'gym_id'];
            isOneToOne: false;
            referencedRelation: 'gym_members';
            referencedColumns: ['id', 'gym_id'];
          },
          {
            foreignKeyName: 'trainer_member_assignments_trainer_fk';
            columns: ['trainer_gym_member_id', 'gym_id'];
            isOneToOne: false;
            referencedRelation: 'gym_members';
            referencedColumns: ['id', 'gym_id'];
          },
        ];
      };
      workout_exercises: {
        Row: {
          created_at: string;
          distance_meters_target: number | null;
          duration_seconds_target: number | null;
          exercise_name: string;
          exercise_scope_snapshot:
            Database['public']['Enums']['exercise_scope'] | null;
          exercise_slug_snapshot: string | null;
          gym_id: string;
          id: string;
          notes: string | null;
          position: number;
          reps_max: number | null;
          reps_min: number | null;
          rest_seconds: number | null;
          sets_target: number | null;
          source_exercise_id: string | null;
          source_routine_exercise_id: string | null;
          tracking_type: Database['public']['Enums']['exercise_tracking_type'];
          updated_at: string;
          weight_target: number | null;
          workout_session_id: string;
        };
        Insert: {
          created_at?: string;
          distance_meters_target?: number | null;
          duration_seconds_target?: number | null;
          exercise_name: string;
          exercise_scope_snapshot?:
            Database['public']['Enums']['exercise_scope'] | null;
          exercise_slug_snapshot?: string | null;
          gym_id: string;
          id?: string;
          notes?: string | null;
          position: number;
          reps_max?: number | null;
          reps_min?: number | null;
          rest_seconds?: number | null;
          sets_target?: number | null;
          source_exercise_id?: string | null;
          source_routine_exercise_id?: string | null;
          tracking_type: Database['public']['Enums']['exercise_tracking_type'];
          updated_at?: string;
          weight_target?: number | null;
          workout_session_id: string;
        };
        Update: {
          created_at?: string;
          distance_meters_target?: number | null;
          duration_seconds_target?: number | null;
          exercise_name?: string;
          exercise_scope_snapshot?:
            Database['public']['Enums']['exercise_scope'] | null;
          exercise_slug_snapshot?: string | null;
          gym_id?: string;
          id?: string;
          notes?: string | null;
          position?: number;
          reps_max?: number | null;
          reps_min?: number | null;
          rest_seconds?: number | null;
          sets_target?: number | null;
          source_exercise_id?: string | null;
          source_routine_exercise_id?: string | null;
          tracking_type?: Database['public']['Enums']['exercise_tracking_type'];
          updated_at?: string;
          weight_target?: number | null;
          workout_session_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'workout_exercises_session_fk';
            columns: ['workout_session_id', 'gym_id'];
            isOneToOne: false;
            referencedRelation: 'workout_sessions';
            referencedColumns: ['id', 'gym_id'];
          },
          {
            foreignKeyName: 'workout_exercises_source_exercise_id_fkey';
            columns: ['source_exercise_id'];
            isOneToOne: false;
            referencedRelation: 'exercises';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'workout_exercises_source_routine_exercise_id_fkey';
            columns: ['source_routine_exercise_id'];
            isOneToOne: false;
            referencedRelation: 'routine_exercises';
            referencedColumns: ['id'];
          },
        ];
      };
      workout_sessions: {
        Row: {
          cancellation_reason: string | null;
          cancelled_at: string | null;
          completed_at: string | null;
          created_at: string;
          gym_id: string;
          gym_member_id: string;
          id: string;
          routine_assignment_id: string;
          routine_id: string;
          started_at: string;
          status: Database['public']['Enums']['workout_status'];
          updated_at: string;
        };
        Insert: {
          cancellation_reason?: string | null;
          cancelled_at?: string | null;
          completed_at?: string | null;
          created_at?: string;
          gym_id: string;
          gym_member_id: string;
          id?: string;
          routine_assignment_id: string;
          routine_id: string;
          started_at?: string;
          status?: Database['public']['Enums']['workout_status'];
          updated_at?: string;
        };
        Update: {
          cancellation_reason?: string | null;
          cancelled_at?: string | null;
          completed_at?: string | null;
          created_at?: string;
          gym_id?: string;
          gym_member_id?: string;
          id?: string;
          routine_assignment_id?: string;
          routine_id?: string;
          started_at?: string;
          status?: Database['public']['Enums']['workout_status'];
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'workout_sessions_assignment_fk';
            columns: ['routine_assignment_id', 'gym_id'];
            isOneToOne: false;
            referencedRelation: 'routine_assignments';
            referencedColumns: ['id', 'gym_id'];
          },
          {
            foreignKeyName: 'workout_sessions_gym_id_fkey';
            columns: ['gym_id'];
            isOneToOne: false;
            referencedRelation: 'gyms';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'workout_sessions_member_fk';
            columns: ['gym_member_id', 'gym_id'];
            isOneToOne: false;
            referencedRelation: 'gym_members';
            referencedColumns: ['id', 'gym_id'];
          },
          {
            foreignKeyName: 'workout_sessions_routine_fk';
            columns: ['routine_id', 'gym_id'];
            isOneToOne: false;
            referencedRelation: 'routines';
            referencedColumns: ['id', 'gym_id'];
          },
        ];
      };
      workout_sets: {
        Row: {
          completed_at: string | null;
          created_at: string;
          distance_meters: number | null;
          duration_seconds: number | null;
          gym_id: string;
          id: string;
          notes: string | null;
          reps: number | null;
          set_number: number;
          status: Database['public']['Enums']['workout_set_status'];
          updated_at: string;
          weight: number | null;
          workout_exercise_id: string;
        };
        Insert: {
          completed_at?: string | null;
          created_at?: string;
          distance_meters?: number | null;
          duration_seconds?: number | null;
          gym_id: string;
          id?: string;
          notes?: string | null;
          reps?: number | null;
          set_number: number;
          status?: Database['public']['Enums']['workout_set_status'];
          updated_at?: string;
          weight?: number | null;
          workout_exercise_id: string;
        };
        Update: {
          completed_at?: string | null;
          created_at?: string;
          distance_meters?: number | null;
          duration_seconds?: number | null;
          gym_id?: string;
          id?: string;
          notes?: string | null;
          reps?: number | null;
          set_number?: number;
          status?: Database['public']['Enums']['workout_set_status'];
          updated_at?: string;
          weight?: number | null;
          workout_exercise_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'workout_sets_exercise_fk';
            columns: ['workout_exercise_id', 'gym_id'];
            isOneToOne: false;
            referencedRelation: 'workout_exercises';
            referencedColumns: ['id', 'gym_id'];
          },
        ];
      };
    };
    Views: {
      [_ in never]: never;
    };
    Functions: {
      add_routine_exercise: {
        Args: {
          p_distance_meters_target?: number;
          p_duration_seconds_target?: number;
          p_exercise_id: string;
          p_notes?: string;
          p_position: number;
          p_reps_max?: number;
          p_reps_min?: number;
          p_rest_seconds?: number;
          p_routine_id: string;
          p_sets_target?: number;
          p_weight_target?: number;
        };
        Returns: string;
      };
      addRoutineExercise: {
        Args: {
          p_distance_meters_target?: number;
          p_duration_seconds_target?: number;
          p_exercise_id: string;
          p_notes?: string;
          p_position: number;
          p_reps_max?: number;
          p_reps_min?: number;
          p_rest_seconds?: number;
          p_routine_id: string;
          p_sets_target?: number;
          p_weight_target?: number;
        };
        Returns: string;
      };
      archive_gym_exercise: {
        Args: { p_exercise_id: string };
        Returns: string;
      };
      archive_membership_plan: {
        Args: { p_plan_id: string };
        Returns: string;
      };
      archive_routine: {
        Args: { p_routine_id: string };
        Returns: string;
      };
      archiveGymExercise: {
        Args: { p_exercise_id: string };
        Returns: string;
      };
      archiveMembershipPlan: {
        Args: { p_plan_id: string };
        Returns: string;
      };
      archiveRoutine: {
        Args: { p_routine_id: string };
        Returns: string;
      };
      assign_routine: {
        Args: {
          p_gym_member_id: string;
          p_notes?: string;
          p_routine_id: string;
          p_starts_at?: string;
        };
        Returns: string;
      };
      assignRoutine: {
        Args: {
          p_gym_member_id: string;
          p_notes?: string;
          p_routine_id: string;
          p_starts_at?: string;
        };
        Returns: string;
      };
      cancel_attendance: {
        Args: { p_attendance_id: string; p_reason: string };
        Returns: string;
      };
      cancel_membership: {
        Args: { p_membership_id: string; p_reason: string };
        Returns: string;
      };
      cancel_routine_assignment: {
        Args: { p_assignment_id: string; p_ends_at?: string; p_notes?: string };
        Returns: string;
      };
      cancel_workout: {
        Args: { p_reason?: string; p_workout_session_id: string };
        Returns: string;
      };
      cancelAttendance: {
        Args: { p_attendance_id: string; p_reason: string };
        Returns: string;
      };
      cancelMembership: {
        Args: { p_membership_id: string; p_reason: string };
        Returns: string;
      };
      cancelRoutineAssignment: {
        Args: { p_assignment_id: string; p_ends_at?: string; p_notes?: string };
        Returns: string;
      };
      cancelWorkout: {
        Args: { p_reason?: string; p_workout_session_id: string };
        Returns: string;
      };
      change_membership_plan: {
        Args: {
          p_membership_id: string;
          p_new_plan_id: string;
          p_reason?: string;
          p_starts_at?: string;
        };
        Returns: string;
      };
      changeMembershipPlan: {
        Args: {
          p_membership_id: string;
          p_new_plan_id: string;
          p_reason?: string;
          p_starts_at?: string;
        };
        Returns: string;
      };
      complete_routine_assignment: {
        Args: { p_assignment_id: string; p_ends_at?: string };
        Returns: string;
      };
      complete_workout: {
        Args: { p_workout_session_id: string };
        Returns: string;
      };
      completeRoutineAssignment: {
        Args: { p_assignment_id: string; p_ends_at?: string };
        Returns: string;
      };
      completeWorkout: {
        Args: { p_workout_session_id: string };
        Returns: string;
      };
      create_global_exercise: {
        Args: {
          p_animation_url?: string;
          p_category: Database['public']['Enums']['exercise_category'];
          p_description: string;
          p_image_url?: string;
          p_instructions: string[];
          p_movement_pattern: Database['public']['Enums']['exercise_movement_pattern'];
          p_name: string;
          p_slug: string;
          p_tracking_type: Database['public']['Enums']['exercise_tracking_type'];
        };
        Returns: string;
      };
      create_gym_exercise: {
        Args: {
          p_animation_url?: string;
          p_category: Database['public']['Enums']['exercise_category'];
          p_description: string;
          p_gym_id: string;
          p_image_url?: string;
          p_instructions: string[];
          p_movement_pattern: Database['public']['Enums']['exercise_movement_pattern'];
          p_name: string;
          p_slug: string;
          p_tracking_type: Database['public']['Enums']['exercise_tracking_type'];
        };
        Returns: string;
      };
      create_membership: {
        Args: {
          p_gym_member_id: string;
          p_membership_plan_id: string;
          p_starts_at?: string;
        };
        Returns: string;
      };
      create_membership_plan: {
        Args: {
          p_access_limit: number;
          p_access_type: Database['public']['Enums']['membership_access_type'];
          p_currency: string;
          p_description: string;
          p_duration_days: number;
          p_frequency_period: Database['public']['Enums']['membership_frequency_period'];
          p_gym_id: string;
          p_name: string;
          p_price: number;
          p_target: number;
        };
        Returns: string;
      };
      create_routine: {
        Args: { p_description?: string; p_gym_id: string; p_name: string };
        Returns: string;
      };
      create_trainer_member_assignment: {
        Args: {
          p_gym_id: string;
          p_member_gym_member_id: string;
          p_trainer_gym_member_id: string;
        };
        Returns: string;
      };
      createGlobalExercise: {
        Args: {
          p_animation_url?: string;
          p_category: Database['public']['Enums']['exercise_category'];
          p_description: string;
          p_image_url?: string;
          p_instructions: string[];
          p_movement_pattern: Database['public']['Enums']['exercise_movement_pattern'];
          p_name: string;
          p_slug: string;
          p_tracking_type: Database['public']['Enums']['exercise_tracking_type'];
        };
        Returns: string;
      };
      createGymExercise: {
        Args: {
          p_animation_url?: string;
          p_category: Database['public']['Enums']['exercise_category'];
          p_description: string;
          p_gym_id: string;
          p_image_url?: string;
          p_instructions: string[];
          p_movement_pattern: Database['public']['Enums']['exercise_movement_pattern'];
          p_name: string;
          p_slug: string;
          p_tracking_type: Database['public']['Enums']['exercise_tracking_type'];
        };
        Returns: string;
      };
      createMembership: {
        Args: {
          p_gym_member_id: string;
          p_membership_plan_id: string;
          p_starts_at?: string;
        };
        Returns: string;
      };
      createMembershipPlan: {
        Args: {
          p_access_limit: number;
          p_access_type: Database['public']['Enums']['membership_access_type'];
          p_currency: string;
          p_description: string;
          p_duration_days: number;
          p_frequency_period: Database['public']['Enums']['membership_frequency_period'];
          p_gym_id: string;
          p_name: string;
          p_price: number;
          p_target: number;
        };
        Returns: string;
      };
      createRoutine: {
        Args: { p_description?: string; p_gym_id: string; p_name: string };
        Returns: string;
      };
      createTrainerMemberAssignment: {
        Args: {
          p_gym_id: string;
          p_member_gym_member_id: string;
          p_trainer_gym_member_id: string;
        };
        Returns: string;
      };
      deactivate_trainer_member_assignment: {
        Args: { p_assignment_id: string };
        Returns: string;
      };
      deactivateTrainerMemberAssignment: {
        Args: { p_assignment_id: string };
        Returns: string;
      };
      record_workout_set: {
        Args: {
          p_distance_meters?: number;
          p_duration_seconds?: number;
          p_notes?: string;
          p_reps?: number;
          p_set_number: number;
          p_status?: Database['public']['Enums']['workout_set_status'];
          p_weight?: number;
          p_workout_exercise_id: string;
        };
        Returns: string;
      };
      recordWorkoutSet: {
        Args: {
          p_distance_meters?: number;
          p_duration_seconds?: number;
          p_notes?: string;
          p_reps?: number;
          p_set_number: number;
          p_status?: Database['public']['Enums']['workout_set_status'];
          p_weight?: number;
          p_workout_exercise_id: string;
        };
        Returns: string;
      };
      register_attendance: {
        Args: {
          p_gym_member_id: string;
          p_membership_id?: string;
          p_method: Database['public']['Enums']['attendance_method'];
          p_occurred_at: string;
          p_source_reference?: string;
        };
        Returns: string;
      };
      registerAttendance: {
        Args: {
          p_gym_member_id: string;
          p_membership_id?: string;
          p_method: Database['public']['Enums']['attendance_method'];
          p_occurred_at: string;
          p_source_reference?: string;
        };
        Returns: string;
      };
      remove_routine_exercise: {
        Args: { p_routine_exercise_id: string };
        Returns: string;
      };
      removeRoutineExercise: {
        Args: { p_routine_exercise_id: string };
        Returns: string;
      };
      renew_membership: {
        Args: { p_membership_id: string; p_starts_at?: string };
        Returns: string;
      };
      renewMembership: {
        Args: { p_membership_id: string; p_starts_at?: string };
        Returns: string;
      };
      reorder_routine_exercises: {
        Args: { p_order: Json; p_routine_id: string };
        Returns: string;
      };
      reorderRoutineExercises: {
        Args: { p_order: Json; p_routine_id: string };
        Returns: string;
      };
      resume_membership: {
        Args: { p_membership_id: string };
        Returns: string;
      };
      resumeMembership: {
        Args: { p_membership_id: string };
        Returns: string;
      };
      set_exercise_equipment: {
        Args: { p_equipment_ids: string[]; p_exercise_id: string };
        Returns: string;
      };
      set_exercise_muscles: {
        Args: { p_exercise_id: string; p_muscles: Json };
        Returns: string;
      };
      setExerciseEquipment: {
        Args: { p_equipment_ids: string[]; p_exercise_id: string };
        Returns: string;
      };
      setExerciseMuscles: {
        Args: { p_exercise_id: string; p_muscles: Json };
        Returns: string;
      };
      start_workout: {
        Args: { p_routine_assignment_id: string };
        Returns: string;
      };
      startWorkout: {
        Args: { p_routine_assignment_id: string };
        Returns: string;
      };
      suspend_membership: {
        Args: { p_membership_id: string };
        Returns: string;
      };
      suspendMembership: {
        Args: { p_membership_id: string };
        Returns: string;
      };
      update_global_exercise: {
        Args: {
          p_animation_url?: string;
          p_category: Database['public']['Enums']['exercise_category'];
          p_description: string;
          p_exercise_id: string;
          p_image_url?: string;
          p_instructions: string[];
          p_movement_pattern: Database['public']['Enums']['exercise_movement_pattern'];
          p_name: string;
          p_slug: string;
          p_status: Database['public']['Enums']['exercise_status'];
          p_tracking_type: Database['public']['Enums']['exercise_tracking_type'];
        };
        Returns: string;
      };
      update_gym_exercise: {
        Args: {
          p_animation_url?: string;
          p_category: Database['public']['Enums']['exercise_category'];
          p_description: string;
          p_exercise_id: string;
          p_image_url?: string;
          p_instructions: string[];
          p_movement_pattern: Database['public']['Enums']['exercise_movement_pattern'];
          p_name: string;
          p_slug: string;
          p_status: Database['public']['Enums']['exercise_status'];
          p_tracking_type: Database['public']['Enums']['exercise_tracking_type'];
        };
        Returns: string;
      };
      update_membership_plan: {
        Args: {
          p_access_limit: number;
          p_access_type: Database['public']['Enums']['membership_access_type'];
          p_currency: string;
          p_description: string;
          p_duration_days: number;
          p_frequency_period: Database['public']['Enums']['membership_frequency_period'];
          p_name: string;
          p_plan_id: string;
          p_price: number;
          p_target: number;
        };
        Returns: string;
      };
      update_routine: {
        Args: {
          p_description: string;
          p_name: string;
          p_routine_id: string;
          p_status: Database['public']['Enums']['routine_status'];
        };
        Returns: string;
      };
      update_routine_exercise: {
        Args: {
          p_distance_meters_target?: number;
          p_duration_seconds_target?: number;
          p_exercise_id: string;
          p_notes?: string;
          p_position: number;
          p_reps_max?: number;
          p_reps_min?: number;
          p_rest_seconds?: number;
          p_routine_exercise_id: string;
          p_sets_target?: number;
          p_weight_target?: number;
        };
        Returns: string;
      };
      updateGlobalExercise: {
        Args: {
          p_animation_url?: string;
          p_category: Database['public']['Enums']['exercise_category'];
          p_description: string;
          p_exercise_id: string;
          p_image_url?: string;
          p_instructions: string[];
          p_movement_pattern: Database['public']['Enums']['exercise_movement_pattern'];
          p_name: string;
          p_slug: string;
          p_status: Database['public']['Enums']['exercise_status'];
          p_tracking_type: Database['public']['Enums']['exercise_tracking_type'];
        };
        Returns: string;
      };
      updateGymExercise: {
        Args: {
          p_animation_url?: string;
          p_category: Database['public']['Enums']['exercise_category'];
          p_description: string;
          p_exercise_id: string;
          p_image_url?: string;
          p_instructions: string[];
          p_movement_pattern: Database['public']['Enums']['exercise_movement_pattern'];
          p_name: string;
          p_slug: string;
          p_status: Database['public']['Enums']['exercise_status'];
          p_tracking_type: Database['public']['Enums']['exercise_tracking_type'];
        };
        Returns: string;
      };
      updateMembershipPlan: {
        Args: {
          p_access_limit: number;
          p_access_type: Database['public']['Enums']['membership_access_type'];
          p_currency: string;
          p_description: string;
          p_duration_days: number;
          p_frequency_period: Database['public']['Enums']['membership_frequency_period'];
          p_name: string;
          p_plan_id: string;
          p_price: number;
          p_target: number;
        };
        Returns: string;
      };
      updateRoutine: {
        Args: {
          p_description: string;
          p_name: string;
          p_routine_id: string;
          p_status: Database['public']['Enums']['routine_status'];
        };
        Returns: string;
      };
      updateRoutineExercise: {
        Args: {
          p_distance_meters_target?: number;
          p_duration_seconds_target?: number;
          p_exercise_id: string;
          p_notes?: string;
          p_position: number;
          p_reps_max?: number;
          p_reps_min?: number;
          p_rest_seconds?: number;
          p_routine_exercise_id: string;
          p_sets_target?: number;
          p_weight_target?: number;
        };
        Returns: string;
      };
    };
    Enums: {
      attendance_method:
        'MANUAL' | 'QR' | 'WORKOUT_COMPLETED' | 'WORKOUT_STARTED';
      attendance_status: 'CANCELLED' | 'VALID';
      exercise_category: 'STRENGTH' | 'CARDIO' | 'MOBILITY' | 'STRETCHING';
      exercise_movement_pattern:
        | 'PUSH'
        | 'PULL'
        | 'SQUAT'
        | 'HINGE'
        | 'LUNGE'
        | 'CARRY'
        | 'ROTATION'
        | 'ISOMETRIC'
        | 'CARDIO';
      exercise_scope: 'GLOBAL' | 'GYM';
      exercise_status: 'ACTIVE' | 'INACTIVE';
      exercise_tracking_type:
        | 'WEIGHT_REPS'
        | 'REPS'
        | 'TIME'
        | 'DISTANCE_TIME'
        | 'WEIGHT_TIME'
        | 'WEIGHT_DISTANCE';
      membership_access_type:
        'ACCESS_COUNT' | 'MONTHLY_LIMIT' | 'UNLIMITED' | 'WEEKLY_FREQUENCY';
      membership_frequency_period: 'MONTH' | 'WEEK';
      membership_plan_status: 'ACTIVE' | 'INACTIVE';
      membership_status: 'ACTIVE' | 'CANCELLED' | 'EXPIRED' | 'SUSPENDED';
      muscle_involvement: 'PRIMARY' | 'SECONDARY';
      routine_assignment_status: 'ACTIVE' | 'COMPLETED' | 'CANCELLED';
      routine_status: 'ACTIVE' | 'INACTIVE' | 'ARCHIVED';
      trainer_member_assignment_status: 'ACTIVE' | 'INACTIVE';
      workout_set_status: 'PLANNED' | 'COMPLETED' | 'SKIPPED';
      workout_status: 'IN_PROGRESS' | 'COMPLETED' | 'CANCELLED';
    };
    CompositeTypes: {
      [_ in never]: never;
    };
  };
};

type DatabaseWithoutInternals = Omit<Database, '__InternalSupabase'>;

type DefaultSchema = DatabaseWithoutInternals[Extract<
  keyof Database,
  'public'
>];

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema['Tables'] & DefaultSchema['Views'])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Tables'] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Views'])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Tables'] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Views'])[TableName] extends {
      Row: infer R;
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema['Tables'] &
        DefaultSchema['Views'])
    ? (DefaultSchema['Tables'] &
        DefaultSchema['Views'])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R;
      }
      ? R
      : never
    : never;

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    keyof DefaultSchema['Tables'] | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Tables']
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Tables'][TableName] extends {
      Insert: infer I;
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema['Tables']
    ? DefaultSchema['Tables'][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I;
      }
      ? I
      : never
    : never;

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    keyof DefaultSchema['Tables'] | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Tables']
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Tables'][TableName] extends {
      Update: infer U;
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema['Tables']
    ? DefaultSchema['Tables'][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U;
      }
      ? U
      : never
    : never;

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    keyof DefaultSchema['Enums'] | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions['schema']]['Enums']
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions['schema']]['Enums'][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema['Enums']
    ? DefaultSchema['Enums'][DefaultSchemaEnumNameOrOptions]
    : never;

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema['CompositeTypes']
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions['schema']]['CompositeTypes']
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions['schema']]['CompositeTypes'][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema['CompositeTypes']
    ? DefaultSchema['CompositeTypes'][PublicCompositeTypeNameOrOptions]
    : never;

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {
      attendance_method: [
        'MANUAL',
        'QR',
        'WORKOUT_COMPLETED',
        'WORKOUT_STARTED',
      ],
      attendance_status: ['CANCELLED', 'VALID'],
      exercise_category: ['STRENGTH', 'CARDIO', 'MOBILITY', 'STRETCHING'],
      exercise_movement_pattern: [
        'PUSH',
        'PULL',
        'SQUAT',
        'HINGE',
        'LUNGE',
        'CARRY',
        'ROTATION',
        'ISOMETRIC',
        'CARDIO',
      ],
      exercise_scope: ['GLOBAL', 'GYM'],
      exercise_status: ['ACTIVE', 'INACTIVE'],
      exercise_tracking_type: [
        'WEIGHT_REPS',
        'REPS',
        'TIME',
        'DISTANCE_TIME',
        'WEIGHT_TIME',
        'WEIGHT_DISTANCE',
      ],
      membership_access_type: [
        'ACCESS_COUNT',
        'MONTHLY_LIMIT',
        'UNLIMITED',
        'WEEKLY_FREQUENCY',
      ],
      membership_frequency_period: ['MONTH', 'WEEK'],
      membership_plan_status: ['ACTIVE', 'INACTIVE'],
      membership_status: ['ACTIVE', 'CANCELLED', 'EXPIRED', 'SUSPENDED'],
      muscle_involvement: ['PRIMARY', 'SECONDARY'],
      routine_assignment_status: ['ACTIVE', 'COMPLETED', 'CANCELLED'],
      routine_status: ['ACTIVE', 'INACTIVE', 'ARCHIVED'],
      trainer_member_assignment_status: ['ACTIVE', 'INACTIVE'],
      workout_set_status: ['PLANNED', 'COMPLETED', 'SKIPPED'],
      workout_status: ['IN_PROGRESS', 'COMPLETED', 'CANCELLED'],
    },
  },
} as const;
