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
      attendances: {
        Row: {
          attendance_date: string;
          cancelled_at: string | null;
          cancelled_by: string | null;
          cancellation_reason: string | null;
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
          cancelled_at?: string | null;
          cancelled_by?: string | null;
          cancellation_reason?: string | null;
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
          cancelled_at?: string | null;
          cancelled_by?: string | null;
          cancellation_reason?: string | null;
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
          {
            foreignKeyName: 'attendances_created_by_fkey';
            columns: ['created_by'];
            isOneToOne: false;
            referencedRelation: 'users';
            referencedColumns: ['id'];
            referencedSchema: 'auth';
          },
          {
            foreignKeyName: 'attendances_cancelled_by_fkey';
            columns: ['cancelled_by'];
            isOneToOne: false;
            referencedRelation: 'users';
            referencedColumns: ['id'];
            referencedSchema: 'auth';
          },
        ];
      };
      membership_plans: {
        Row: {
          access_limit: number | null;
          access_type: Database['public']['Enums']['membership_access_type'];
          created_at: string;
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
          currency: string;
        };
        Insert: {
          access_limit?: number | null;
          access_type: Database['public']['Enums']['membership_access_type'];
          created_at?: string;
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
          currency?: string;
        };
        Update: {
          access_limit?: number | null;
          access_type?: Database['public']['Enums']['membership_access_type'];
          created_at?: string;
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
          currency?: string;
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
    };
    Views: {
      [_ in never]: never;
    };
    Functions: {
      archive_membership_plan: { Args: { p_plan_id: string }; Returns: string };
      cancel_attendance: {
        Args: { p_attendance_id: string; p_reason: string };
        Returns: string;
      };
      cancel_membership: {
        Args: { p_membership_id: string; p_reason: string };
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
          p_access_limit: number | null;
          p_access_type: Database['public']['Enums']['membership_access_type'];
          p_currency: string;
          p_description: string | null;
          p_duration_days: number;
          p_frequency_period:
            Database['public']['Enums']['membership_frequency_period'] | null;
          p_gym_id: string;
          p_name: string;
          p_price: number;
          p_target: number | null;
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
      renew_membership: {
        Args: { p_membership_id: string; p_starts_at?: string };
        Returns: string;
      };
      resume_membership: { Args: { p_membership_id: string }; Returns: string };
      suspend_membership: {
        Args: { p_membership_id: string };
        Returns: string;
      };
      update_membership_plan: {
        Args: {
          p_access_limit: number | null;
          p_access_type: Database['public']['Enums']['membership_access_type'];
          p_currency: string;
          p_description: string | null;
          p_duration_days: number;
          p_frequency_period:
            Database['public']['Enums']['membership_frequency_period'] | null;
          p_name: string;
          p_plan_id: string;
          p_price: number;
          p_target: number | null;
        };
        Returns: string;
      };
      archiveMembershipPlan: { Args: { p_plan_id: string }; Returns: string };
      cancelAttendance: {
        Args: { p_attendance_id: string; p_reason: string };
        Returns: string;
      };
      cancelMembership: {
        Args: { p_membership_id: string; p_reason: string };
        Returns: string;
      };
      changeMembershipPlan: {
        Args: {
          p_membership_id: string;
          p_new_plan_id: string;
          p_starts_at?: string;
          p_reason?: string;
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
          p_gym_id: string;
          p_name: string;
          p_description: string | null;
          p_access_type: Database['public']['Enums']['membership_access_type'];
          p_access_limit: number | null;
          p_frequency_period:
            Database['public']['Enums']['membership_frequency_period'] | null;
          p_target: number | null;
          p_price: number;
          p_currency: string;
          p_duration_days: number;
        };
        Returns: string;
      };
      registerAttendance: {
        Args: {
          p_gym_member_id: string;
          p_occurred_at: string;
          p_method: Database['public']['Enums']['attendance_method'];
          p_membership_id?: string;
          p_source_reference?: string;
        };
        Returns: string;
      };
      renewMembership: {
        Args: { p_membership_id: string; p_starts_at?: string };
        Returns: string;
      };
      resumeMembership: { Args: { p_membership_id: string }; Returns: string };
      suspendMembership: { Args: { p_membership_id: string }; Returns: string };
      updateMembershipPlan: {
        Args: {
          p_plan_id: string;
          p_name: string;
          p_description: string | null;
          p_access_type: Database['public']['Enums']['membership_access_type'];
          p_access_limit: number | null;
          p_frequency_period:
            Database['public']['Enums']['membership_frequency_period'] | null;
          p_target: number | null;
          p_price: number;
          p_currency: string;
          p_duration_days: number;
        };
        Returns: string;
      };
    };
    Enums: {
      attendance_method:
        'MANUAL' | 'QR' | 'WORKOUT_COMPLETED' | 'WORKOUT_STARTED';
      attendance_status: 'CANCELLED' | 'VALID';
      membership_access_type:
        'ACCESS_COUNT' | 'MONTHLY_LIMIT' | 'UNLIMITED' | 'WEEKLY_FREQUENCY';
      membership_frequency_period: 'MONTH' | 'WEEK';
      membership_plan_status: 'ACTIVE' | 'INACTIVE';
      membership_status: 'ACTIVE' | 'CANCELLED' | 'EXPIRED' | 'SUSPENDED';
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
        'QR',
        'WORKOUT_STARTED',
        'WORKOUT_COMPLETED',
        'MANUAL',
      ],
      attendance_status: ['VALID', 'CANCELLED'],
      membership_access_type: [
        'WEEKLY_FREQUENCY',
        'MONTHLY_LIMIT',
        'ACCESS_COUNT',
        'UNLIMITED',
      ],
      membership_frequency_period: ['WEEK', 'MONTH'],
      membership_plan_status: ['ACTIVE', 'INACTIVE'],
      membership_status: ['ACTIVE', 'EXPIRED', 'CANCELLED', 'SUSPENDED'],
    },
  },
} as const;
