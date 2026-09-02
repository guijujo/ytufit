# ADR 0005: Contratos históricos y asistencias por día local

- Estado: aceptado
- Fecha: 2026-09-02

## Decisión

Los planes son configuración comercial mutable; una `membership` es un
contrato inmutable en cuanto a su precio y configuración, por lo que contiene
snapshots. Un cambio de plan cancela el contrato anterior y crea otro. Las
asistencias se conservan como eventos: una corrección cambia `VALID` a
`CANCELLED` con motivo, actor y timestamp, nunca elimina la fila.

`attendance_date` se calcula en el comando de registro con
`occurred_at AT TIME ZONE gyms.timezone`. La unicidad diaria se aplica solo a
eventos `VALID`, permitiendo corregir y volver a registrar el mismo día.
Los límites comerciales se calculan desde el historial válido de la
membresía (semana ISO iniciada en lunes y mes calendario local), sin un
contador mutable como fuente de verdad.

`registerAttendance` queda limitado a `GYM_ADMIN` del tenant y al método
`MANUAL` mientras no existan QR verificable ni eventos de Training. Los métodos
futuros conservan sus enums, pero no son invocables libremente por miembros.
Los comandos normalizan memberships `ACTIVE` vencidas a `EXPIRED` antes de
crear o renovar contratos; las memberships suspendidas vencidas no se
reanuda y deben renovarse.

## Consecuencias

Los comandos server-side son la única superficie de escritura para estas
tablas. Una violación concurrente del índice parcial diario es un error
determinista `23505`; los futuros `audit_logs` podrán complementar los campos
de auditoría ya almacenados en cada fila.
