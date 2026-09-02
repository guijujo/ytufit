# ADR 0002: Supabase y frontera de autorización

- Estado: aceptado
- Fecha: 2026-09-02

## Decisión

Separar tres clientes: público de browser, autenticado server-side mediante cookies y administrativo server-only. El cliente mobile usa exclusivamente credenciales públicas y almacenamiento seguro de sesión compatible con React Native.

PostgreSQL RLS adopta `default deny`. `service_role` no se comparte, no se prefija como variable pública y no se usa para lecturas ordinarias. Los cambios sensibles y multi-entidad se modelan como comandos server-side transaccionales y auditables.

## Consecuencias

Una pantalla o API no puede ampliar permisos por sí misma. Cada tabla operativa exigirá políticas y pruebas negativas antes de considerarse lista.
