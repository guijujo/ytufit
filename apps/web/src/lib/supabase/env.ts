function requireEnvironmentVariable(
  name: string,
  value: string | undefined,
): string {
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

export function getPublicSupabaseEnvironment() {
  return {
    url: requireEnvironmentVariable(
      'NEXT_PUBLIC_SUPABASE_URL',
      process.env.NEXT_PUBLIC_SUPABASE_URL,
    ),
    publishableKey: requireEnvironmentVariable(
      'NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY',
      process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
    ),
  };
}

export function getServiceRoleKey(): string {
  return requireEnvironmentVariable(
    'SUPABASE_SERVICE_ROLE_KEY',
    process.env.SUPABASE_SERVICE_ROLE_KEY,
  );
}
