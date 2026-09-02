# Modelo de seguridad multi-tenant

`User` es una identidad global de Supabase Auth. La pertenencia contextual se modelará mediante `gym_members`, con unicidad por usuario/gimnasio. `GYM_ADMIN`, `TRAINER` y `MEMBER` se evaluarán dentro de ese vínculo; `PLATFORM_ADMIN` será global y explícito.

## Postura obligatoria

1. RLS habilitado en todo dato operativo y sin acceso implícito (`default deny`).
2. Las políticas derivan el usuario de `auth.uid()`; no aceptan una identidad declarada por el cliente.
3. Toda consulta queda limitada por `gym_id` y pertenencia activa, además de restricciones de rol/asignación.
4. Ocultar controles en UI nunca sustituye autorización.
5. `service_role` solo se usa en módulos server-only, con validación de autorización previa y auditoría.
6. Storage replica el aislamiento por gimnasio mediante nombres de objeto y políticas.
7. Las pruebas RLS incluyen siempre actores de, al menos, dos gimnasios y casos anónimos.

Los comandos iniciales previstos incluyen aprobación y alta de miembros, asignación de roles, cambios/renovaciones de membresía, asistencias, workouts, rachas, comodines, logros y recompensas. Su contrato exacto se diseñará junto con el esquema, sin exponer mutaciones privilegiadas al cliente.
