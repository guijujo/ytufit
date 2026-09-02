import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';

import type { Database } from '@ytufit/types';

import { getPublicSupabaseEnvironment } from './env';

export async function createSupabaseServerClient() {
  const cookieStore = await cookies();
  const { url, publishableKey } = getPublicSupabaseEnvironment();

  return createServerClient<Database>(url, publishableKey, {
    cookies: {
      getAll: () => cookieStore.getAll(),
      setAll: (values) => {
        try {
          values.forEach(({ name, value, options }) =>
            cookieStore.set(name, value, options),
          );
        } catch {
          // Server Components cannot write cookies. Middleware or a Server Action
          // is responsible for refreshing the session.
        }
      },
    },
  });
}
