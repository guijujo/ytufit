# Modelo de seguridad multi-tenant

`User` es una identidad global de Supabase Auth. La pertenencia contextual se modelará mediante `gym_members`, con unicidad por usuario/gimnasio. `GYM_ADMIN`, `TRAINER` y `MEMBER` se evaluarán dentro de ese vínculo; `PLATFORM_ADMIN` será global y explícito.

## Postura obligatoria

1. RLS está habilitado y forzado en todo dato operativo, sin acceso implícito (`default deny`).
2. Las políticas derivan el usuario de `auth.uid()`; no aceptan una identidad declarada por el cliente.
3. Toda consulta queda limitada por `gym_id` y pertenencia activa, además de restricciones de rol/asignación.
4. Ocultar controles en UI nunca sustituye autorización.
5. `SECURITY DEFINER` se limita a helpers privados y triggers, fija `search_path`, revoca ejecución pública y nunca confía en IDs enviados por el cliente.
6. `service_role` solo se usa en módulos server-only, con validación de autorización previa y auditoría.
7. Storage replica el aislamiento por gimnasio mediante nombres de objeto y políticas.
8. Las pruebas RLS incluyen siempre actores de, al menos, dos gimnasios y casos anónimos.

## Fronteras de confianza y comandos

El cliente puede leer los datos permitidos, crear su propia solicitud pendiente y cancelarla. No puede cambiar ownership, roles, tokens, timestamps de revisión ni estados de invitaciones. `approveJoinRequest`, `rejectJoinRequest`, `acceptGymInvitation` y `revokeGymInvitation` son contratos server-side: autentican al actor, comprueban el rol contextual, bloquean la fila, validan la transición, escriben los campos sensibles desde el servidor y ejecutan membership/role assignment de forma idempotente y transaccional. La migración deja esas transiciones fuera de UPDATE directo hasta exponer dichos comandos.

Los comandos iniciales previstos incluyen aprobación y alta de miembros, asignación de roles, cambios/renovaciones de membresía, asistencias, workouts, rachas, comodines, logros y recompensas. Su contrato exacto se diseñará junto con el esquema, sin exponer mutaciones privilegiadas al cliente.

## Membresías y asistencia

Las tablas de planes, membresías y asistencias usan RLS `FORCE` con default
deny: los socios solo leen sus propios contratos y eventos históricos, y los
administradores solo leen filas de su gimnasio. Trainers no reciben acceso
administrativo implícito. Las claves foráneas compuestas `(id, gym_id)` y los
índices únicos parciales refuerzan estas fronteras incluso cuando RLS no aplica.

Las mutaciones pasan por comandos `SECURITY DEFINER` con `search_path` fijo y
ejecución revocada a `PUBLIC`. El servidor obtiene el gimnasio desde
`gym_members`, obtiene precio y snapshots desde el plan, y deriva
`attendance_date` usando la zona horaria del gimnasio. Memberships y
asistencias son históricas: cambiar de plan cierra el contrato anterior y
cancelar una asistencia conserva la fila. Los límites semanal, mensual y de
accesos se derivan de eventos `VALID`; la restricción diaria es la defensa
definitiva frente a carreras concurrentes.

En v2.0.2, `registerAttendance` es exclusivamente administrativo: el actor
debe ser `GYM_ADMIN` del mismo gimnasio y el único método público habilitado es
`MANUAL`. `QR`, `WORKOUT_STARTED` y `WORKOUT_COMPLETED` permanecen modelados
para futuras superficies server-side, pero no pueden ser falsificados por un
miembro. Para registros manuales históricos, la membresía se valida contra
`occurred_at`, mientras `attendance_date` siempre se calcula en la zona local.
Una membership `ACTIVE` cuyo `ends_at` ya pasó se normaliza a `EXPIRED` durante
los comandos de creación/renovación; una membership suspendida vencida no se
reanuda y debe renovarse.
