# YtuFit

Bootstrap de la plataforma SaaS multi-tenant para gimnasios. Este primer hito configura la infraestructura; no contiene pantallas ni funcionalidades de producto.

## Requisitos

- Node.js 22 o superior
- pnpm 10.28.1 (usar `corepack enable`)
- Docker, para Supabase local
- Supabase CLI, para migraciones y pruebas de base de datos

## Inicio rápido

```bash
cp .env.example .env.local
pnpm install
pnpm dev
```

La web queda disponible en `http://localhost:3000`. Para iniciar una aplicación por separado:

```bash
pnpm --filter @ytufit/web dev
pnpm --filter @ytufit/mobile dev
```

## Calidad y compilación

```bash
pnpm typecheck
pnpm lint
pnpm format:check
pnpm build
```

## Supabase local

```bash
supabase start
supabase db reset
```

`SUPABASE_SERVICE_ROLE_KEY` es exclusivamente server-side. La web y mobile usan solo las claves públicas. RLS será `default deny`: una tabla operativa no se considera terminada hasta tener RLS, políticas y pruebas negativas de aislamiento entre gimnasios.

## Estructura

- `apps/web`: Next.js App Router y adaptadores Supabase para browser/server/admin.
- `apps/mobile`: Expo y cliente Supabase con persistencia de sesión nativa.
- `packages/domain`: contratos y lógica pura de dominio.
- `packages/types`: tipos compartidos, incluidos los generados desde PostgreSQL.
- `packages/validation`: esquemas de validación compartidos.
- `packages/config`: validación de configuración pública.
- `packages/ui`: primitives visuales compartibles (vacío hasta definir la estrategia cross-platform).
- `supabase`: configuración, migraciones, seed y futuras pruebas RLS.
- `docs`: contexto de producto, arquitectura, base de datos y ADRs.

## Variables de entorno

Copiar `.env.example`; nunca confirmar valores reales. Las variables `NEXT_PUBLIC_*` y `EXPO_PUBLIC_*` forman parte de los bundles cliente. La clave `service_role` solo se lee en `apps/web/src/lib/supabase/admin.ts`, que está marcado como módulo server-only.

## Flujo de cambios de base de datos

1. Crear una migración versionada en `supabase/migrations`.
2. Activar RLS y escribir políticas explícitas en la misma entrega.
3. Añadir pruebas positivas y negativas, incluyendo acceso cruzado entre tenants.
4. Regenerar `packages/types/src/database.ts` con `supabase gen types typescript --local`.
5. Revisar operaciones multi-entidad para ejecutarlas como comando server-side/transacción.

Consulta las decisiones iniciales en [`docs/decisions`](docs/decisions) y el modelo de seguridad en [`docs/architecture/security.md`](docs/architecture/security.md).
