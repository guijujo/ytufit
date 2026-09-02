# Identidad y multi-tenancy

La identidad global vive en `auth.users`; `profiles` contiene sus datos de aplicación. `gyms` son los límites de tenant y `gym_members` relaciona usuarios con gimnasios mediante una clave única `(gym_id, user_id)`. La restricción única `(id, gym_id)` deja preparada la estrategia de claves foráneas compuestas para tablas de dominio futuras.

`roles` es el catálogo (`GYM_ADMIN`, `TRAINER`, `MEMBER`) y `gym_member_roles` asigna esos roles de forma contextual al gimnasio. `platform_admins` es una lista global separada del modelo de tenant.

## Solicitudes e invitaciones

`gym_join_requests` permite a un usuario crear su propia solicitud `PENDING`. El índice parcial `idx_gym_join_requests_unique_pending` evita solicitudes pendientes duplicadas. El cliente solo puede cancelar su propia solicitud pendiente; aprobar o rechazar es un comando server-side transaccional.

`gym_invitations` almacena únicamente `token_hash`, nunca el bearer token. El índice parcial `idx_gym_invitations_unique_pending` evita invitaciones pendientes duplicadas para el mismo correo y gimnasio. Sus estados son `PENDING`, `ACCEPTED`, `DECLINED`, `REVOKED` y `EXPIRED`. Aceptar y revocar son comandos server-side; la aceptación valida token, usuario, membership, rol, timestamp y replay dentro de una transacción.

Todas las tablas tienen RLS en modo default deny. Los tipos TypeScript se generan desde la base mediante `supabase gen types typescript --local`; no se mantiene un segundo esquema manual.

## Membresías y asistencias (v2.0.2)

`membership_plans` es la oferta vigente de cada gimnasio. `access_type` distingue
`WEEKLY_FREQUENCY` (objetivo por semana), `MONTHLY_LIMIT` (objetivo por mes),
`ACCESS_COUNT` (cantidad total) y `UNLIMITED`; los checks impiden combinaciones
incoherentes. El precio es `numeric(12,2)` y siempre incluye código de moneda.

`memberships` es el contrato histórico entre `gym_members` y un plan. Guarda
snapshots de precio, tipo, objetivo, período y límite: cambiar el plan crea un
nuevo contrato y no reescribe el pasado. La clave única parcial
`idx_memberships_one_active_per_member` permite como máximo una membresía activa
por socio y gimnasio.

`attendances` conserva eventos válidos y cancelados. La clave foránea compuesta
incluye `gym_id` para impedir asociaciones cross-tenant, y
`idx_attendances_one_valid_per_local_day` permite una sola asistencia `VALID` por
socio/gimnasio/día, sin borrar la fila cancelada. `attendance_date` se deriva
server-side como `occurred_at AT TIME ZONE gyms.timezone`; nunca se acepta una
fecha del cliente.

Las lecturas se limitan por RLS al propio socio o a `GYM_ADMIN` del mismo
gimnasio. No hay mutaciones directas para clientes. Los comandos
`createMembershipPlan`, `updateMembershipPlan`, `archiveMembershipPlan`,
`createMembership`, `renewMembership`, `changeMembershipPlan`,
`suspendMembership`, `resumeMembership`, `cancelMembership`, `registerAttendance`
y `cancelAttendance` son funciones `SECURITY DEFINER`, autentican el actor y
derivan tenant, precio, snapshots y campos de auditoría en el servidor.
Los límites se calculan desde asistencias `VALID`; una violación del índice
diario por concurrencia se devuelve como `23505`.
