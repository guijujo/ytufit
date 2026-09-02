# ADR 0001: Límites del monorepo

- Estado: aceptado
- Fecha: 2026-09-02

## Decisión

Usar pnpm workspaces y Turborepo con aplicaciones desplegables en `apps` y módulos independientes de framework en `packages`. Las aplicaciones poseen sus adaptadores de plataforma (cookies web y almacenamiento nativo); los paquetes no leen variables de entorno globales.

## Consecuencias

Los contratos pueden compartirse sin filtrar APIs de Node hacia mobile. Se acepta algo de duplicación en composición de clientes Supabase a cambio de límites de seguridad visibles.
