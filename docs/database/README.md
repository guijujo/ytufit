# Diseño de base de datos

El esquema definitivo se diseñará en una entrega posterior. Las invariantes de producto (historial inmutable, cancelación en vez de borrado, unicidad de asistencia válida, membresías versionadas, snapshots de workouts y reglas de rachas/comodines) se expresarán con restricciones y comandos transaccionales, no solo mediante validación de interfaz.

Toda decisión de tenancy debe permitir demostrar aislamiento usando pruebas SQL. Los tipos TypeScript se generan desde la base, evitando mantener un segundo esquema manual.
