# ADR 0003: Posponer el esquema de dominio

- Estado: aceptado
- Fecha: 2026-09-02

## Decisión

No crear tablas durante el bootstrap. La primera migración de dominio se diseñará como un conjunto coherente de claves, restricciones, RLS, funciones y pruebas, partiendo del modelo aprobado y de sus invariantes.

## Consecuencias

El arranque verifica herramientas y límites de clientes sin consolidar prematuramente un modelo incompleto. Los tipos de base de datos permanecen como placeholder vacío hasta generar el esquema real.
