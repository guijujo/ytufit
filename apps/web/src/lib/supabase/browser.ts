'use client';

import { createBrowserClient } from '@supabase/ssr';

import type { Database } from '@ytufit/types';

import { getPublicSupabaseEnvironment } from './env';

export function createSupabaseBrowserClient() {
  const { url, publishableKey } = getPublicSupabaseEnvironment();
  return createBrowserClient<Database>(url, publishableKey);
}
