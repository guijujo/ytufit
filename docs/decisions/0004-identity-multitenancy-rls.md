# ADR 0004: Endurecimiento de identidad, multi-tenancy y RLS

- Estado: aceptado
- Fecha: 2026-09-02

## Decisión

La migración de hardening es incremental y append-only. Se elimina el `UPDATE` administrativo genérico sobre solicitudes e invitaciones. El cliente solo puede crear solicitudes propias en `PENDING` y cancelarlas; las transiciones sensibles quedan reservadas a comandos server-side.

Los comandos `approveJoinRequest` y `rejectJoinRequest` deben autenticar al actor, comprobar `GYM_ADMIN` del mismo gimnasio, bloquear la solicitud, validar `PENDING`, establecer `reviewed_by` y `reviewed_at` en servidor y, al aprobar, crear membership y rol `MEMBER` idempotentemente dentro de una transacción. `acceptGymInvitation` y `revokeGymInvitation` deben validar token/hash, identidad, transición, timestamps y replay sin almacenar tokens plaintext.

RLS permanece default deny y todos los helpers `SECURITY DEFINER` están en el esquema privado, con `search_path` fijo y privilegios explícitos. Las pruebas usan actores de dos gimnasios y verifican que ningún usuario pueda declarar otra identidad, tenant o rol.

## Consecuencias

Hasta que existan endpoints server-only, las transiciones sensibles no tienen una mutación pública intencional. Esto evita escalación y efectos duplicados a costa de requerir esos comandos antes de habilitar los flujos de producto.
