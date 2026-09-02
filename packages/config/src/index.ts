export interface PublicSupabaseConfig {
  publishableKey: string;
  url: string;
}

export function definePublicSupabaseConfig(
  config: PublicSupabaseConfig,
): PublicSupabaseConfig {
  if (!config.url || !config.publishableKey)
    throw new Error('Supabase public configuration is incomplete');
  return config;
}
