# Identidad y multi-tenancy

La identidad global vive en `auth.users`; `profiles` contiene sus datos de aplicación. `gyms` son los límites de tenant y `gym_members` relaciona usuarios con gimnasios mediante una clave única `(gym_id, user_id)`. La restricción única `(id, gym_id)` deja preparada la estrategia de claves foráneas compuestas para tablas de dominio futuras.

`roles` es el catálogo (`GYM_ADMIN`, `TRAINER`, `MEMBER`) y `gym_member_roles` asigna esos roles de forma contextual al gimnasio. `platform_admins` es una lista global separada del modelo de tenant.

## Solicitudes e invitaciones

`gym_join_requests` permite a un usuario crear su propia solicitud `PENDING`. El índice parcial `idx_gym_join_requests_unique_pending` evita solicitudes pendientes duplicadas. El cliente solo puede cancelar su propia solicitud pendiente; aprobar o rechazar es un comando server-side transaccional.

`gym_invitations` almacena únicamente `token_hash`, nunca el bearer token. El índice parcial `idx_gym_invitations_unique_pending` evita invitaciones pendientes duplicadas para el mismo correo y gimnasio. Sus estados son `PENDING`, `ACCEPTED`, `DECLINED`, `REVOKED` y `EXPIRED`. Aceptar y revocar son comandos server-side; la aceptación valida token, usuario, membership, rol, timestamp y replay dentro de una transacción.

Todas las tablas tienen RLS en modo default deny. Los tipos TypeScript se generan desde la base mediante `supabase gen types typescript --local`; no se mantiene un segundo esquema manual.
