# Arquitectura inicial

YtuFit usa un monorepo pnpm/Turborepo. Next.js ofrece la superficie web y el límite server-side; Expo ofrece la aplicación del socio. Supabase proporciona Auth, PostgreSQL, Storage y APIs sujetas a RLS.

Los paquetes compartidos se mantienen independientes de framework. `domain` expone vocabulario y lógica pura; `types` contiene contratos técnicos; `validation` centraliza esquemas; `config` utilidades de configuración; `ui` queda deliberadamente vacío hasta validar el límite visual web/native.

## Límites

- El cliente puede solicitar, pero no autorizar, operaciones.
- Los comandos sensibles se implementarán server-side y de forma transaccional.
- El contexto de gimnasio debe viajar explícitamente y validarse contra la sesión.
- Ningún adaptador compartido conoce `service_role`.
- La base de datos es la última frontera de autorización mediante RLS.
