# Distribuidora – Inventario y Ventas con Supabase

## Estructura
```
index.html            Interfaz (misma de la versión anterior, ahora conectada)
js/config.js          URL y anon key de TU proyecto Supabase  ← editar
js/api.js             Capa de datos (consultas y llamadas RPC)
supabase/01_schema.sql  Tablas, seguridad (RLS) y funciones transaccionales
supabase/02_seed.sql    Datos de prueba (opcional)
```

## Puesta en marcha
1. Crea un proyecto en https://supabase.com.
2. **SQL Editor** → pega y ejecuta `01_schema.sql`, y luego `02_seed.sql` (opcional).
3. **Authentication → Users → Add user**: crea el usuario (correo + contraseña, marca «Auto Confirm User»).
   En **Authentication → Sign In / Providers**, desactiva el registro público (*Allow new users to sign up*) para que solo entren usuarios que tú crees.
4. **Project Settings → API**: copia *Project URL* y la clave *anon public* en `js/config.js`.
5. Abre `index.html` con un servidor local (VS Code «Live Server» o `npx serve .`) e inicia sesión.
   Para publicarlo: Netlify, Vercel o GitHub Pages (solo archivos estáticos).

## Cómo funciona la seguridad
- Todas las tablas tienen RLS: solo usuarios autenticados leen datos.
- El navegador **no puede** cambiar stock, kardex, ventas ni compras directamente (permisos revocados). Solo lo hace a través de `registrar_venta`, `registrar_compra` y `registrar_ajuste`, que corren en una transacción con bloqueo de fila: sin sobreventa aunque dos cajeros facturen a la vez.
- La clave `anon` puede estar en el front-end. **Nunca pongas la `service_role`.**
- «Eliminar» producto lo desactiva (`activo = false`) para conservar el historial.

## Límites conocidos
- La interfaz carga las últimas 1 000 filas de kardex, ventas y compras (límite por defecto de la API). Con más volumen conviene paginar o crear vistas/funciones SQL para los indicadores del panel.
- Todos los usuarios autenticados tienen los mismos permisos. Para roles (vendedor, bodega, gerente) se agregaría una tabla `perfiles` y políticas por rol.
- El Crédito sigue siendo solo una forma de pago (no hay cuentas por cobrar).
