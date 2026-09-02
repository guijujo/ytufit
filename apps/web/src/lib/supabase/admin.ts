import 'server-only';

import { createClient } from '@supabase/supabase-js';

import type { Database } from '@ytufit/types';

import { getPublicSupabaseEnvironment, getServiceRoleKey } from './env';

export function createSupabaseAdminClient() {
  const { url } = getPublicSupabaseEnvironment();
  return createClient<Database>(url, getServiceRoleKey(), {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}
