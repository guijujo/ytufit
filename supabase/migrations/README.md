# Migrations

Cada migración define una parte append-only del esquema. Las migraciones de
identidad y de membresías/asistencia incluyen restricciones, índices,
activación de RLS y políticas necesarias para que la postura inicial sea
`default deny`.

No introducir una tabla operativa sin una prueba de aislamiento entre dos gimnasios en `../tests`.
