# Database tests

Las pruebas pgTAP se añadirán con el primer esquema. Deben cubrir, como mínimo:

- acceso permitido dentro del gimnasio activo;
- denegación entre tenants;
- denegación para usuarios sin relación `gym_members`;
- permisos contextuales por rol y asignación de entrenador;
- invariantes y comandos server-side sensibles.
