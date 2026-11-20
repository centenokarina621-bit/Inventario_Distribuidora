-- =====================================================================
-- Distribuidora – Esquema Supabase (PostgreSQL)
-- Ejecutar en: Supabase > SQL Editor > New query
-- =====================================================================

create table configuracion (
  id int primary key default 1 check (id = 1),
  tipo_cambio numeric(10,4) not null default 36.62 check (tipo_cambio > 0),
  iva_pct numeric(4,3) not null default 0.15
);
insert into configuracion (id) values (1);

create table productos (
  id bigint generated always as identity primary key,
  codigo text not null unique,
  nombre text not null,
  categoria text not null,
  subcategoria text not null default 'General',
  unidad text not null default 'Unidad',
  costo numeric(12,2) not null check (costo >= 0),
  precio_detalle numeric(12,2) not null check (precio_detalle >= 0),
  precio_mayorista numeric(12,2) not null check (precio_mayorista >= 0),
  stock integer not null default 0 check (stock >= 0),
  stock_minimo integer not null default 0,
  exento boolean not null default false,
  activo boolean not null default true,
  created_at timestamptz not null default now()
);

create table movimientos (            -- Kardex
  id bigint generated always as identity primary key,
  producto_id bigint not null references productos(id),
  tipo text not null,
  cantidad integer not null,           -- + entrada / - salida
  saldo integer not null,
  referencia text,
  usuario uuid default auth.uid(),
  created_at timestamptz not null default now()
);
create index on movimientos (producto_id, created_at);

create sequence ventas_num_seq;
create table ventas (
  id bigint generated always as identity primary key,
  numero text not null unique default ('F-' || lpad(nextval('ventas_num_seq')::text, 5, '0')),
  cliente text not null default 'Consumidor final',
  tipo_precio text not null check (tipo_precio in ('Detalle','Mayorista')),
  forma_pago text not null check (forma_pago in ('Efectivo','Tarjeta','Transferencia','Crédito')),
  descuento_pct numeric(5,2) not null default 0,
  subtotal numeric(14,2) not null,
  descuento numeric(14,2) not null,
  iva numeric(14,2) not null,
  total numeric(14,2) not null,
  utilidad numeric(14,2) not null,
  usuario uuid default auth.uid(),
  created_at timestamptz not null default now()
);

create table venta_items (
  id bigint generated always as identity primary key,
  venta_id bigint not null references ventas(id) on delete cascade,
  producto_id bigint not null references productos(id),
  nombre text not null,
  unidad text not null,
  cantidad integer not null check (cantidad > 0),
  precio numeric(12,2) not null,
  costo numeric(12,2) not null,
  exento boolean not null
);

create table compras (
  id bigint generated always as identity primary key,
  producto_id bigint not null references productos(id),
  proveedor text not null,
  documento text not null,
  cantidad integer not null check (cantidad > 0),
  costo_unit numeric(12,2) not null,
  total numeric(14,2) not null,
  metodo text not null check (metodo in ('p','u')),   -- p = promedio ponderado, u = último costo
  usuario uuid default auth.uid(),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Seguridad: RLS + permisos mínimos. Solo usuarios autenticados.
-- El stock, kardex, ventas y compras SOLO se modifican con las funciones RPC.
-- ---------------------------------------------------------------------
alter table configuracion enable row level security;
alter table productos     enable row level security;
alter table movimientos   enable row level security;
alter table ventas        enable row level security;
alter table venta_items   enable row level security;
alter table compras       enable row level security;

create policy leer_config     on configuracion for select to authenticated using (true);
create policy leer_productos  on productos     for select to authenticated using (true);
create policy leer_mov        on movimientos   for select to authenticated using (true);
create policy leer_ventas     on ventas        for select to authenticated using (true);
create policy leer_items      on venta_items   for select to authenticated using (true);
create policy leer_compras    on compras       for select to authenticated using (true);
create policy crear_producto  on productos     for insert to authenticated with check (true);
create policy editar_producto on productos     for update to authenticated using (true) with check (true);
create policy editar_config   on configuracion for update to authenticated using (true) with check (true);

revoke all on configuracion, productos, movimientos, ventas, venta_items, compras from anon, authenticated;
grant select on configuracion, productos, movimientos, ventas, venta_items, compras to authenticated;
grant insert on productos to authenticated;
grant update (codigo,nombre,categoria,subcategoria,unidad,costo,precio_detalle,precio_mayorista,stock_minimo,exento,activo) on productos to authenticated;
grant update (tipo_cambio) on configuracion to authenticated;

-- Kardex inicial al crear un producto
create function trg_producto_inicial() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into movimientos (producto_id, tipo, cantidad, saldo, referencia)
  values (new.id, 'Inventario inicial', new.stock, new.stock, '—');
  return new;
end $$;
create trigger producto_inicial after insert on productos
for each row execute function trg_producto_inicial();

-- ---------------------------------------------------------------------
-- Funciones transaccionales (RPC)
-- ---------------------------------------------------------------------
create function registrar_venta(p_cliente text, p_tipo text, p_pago text, p_dsc numeric, p_items jsonb)
returns ventas language plpgsql security definer set search_path = public as $$
declare
  it jsonb; p productos; v ventas;
  d numeric := least(50, greatest(0, coalesce(p_dsc,0))) / 100;
  v_sub numeric := 0; v_iva numeric := 0; v_costo numeric := 0; v_rate numeric; pu numeric; q int;
begin
  if auth.uid() is null then raise exception 'No autenticado'; end if;
  if p_items is null or jsonb_array_length(p_items) = 0 then raise exception 'La factura no tiene productos'; end if;
  select iva_pct into v_rate from configuracion where id = 1;

  for it in select * from jsonb_array_elements(p_items) loop
    q := (it->>'cantidad')::int;
    select * into p from productos where id = (it->>'producto_id')::bigint and activo for update;
    if not found then raise exception 'Producto no existe'; end if;
    if q <= 0 or q > p.stock then raise exception 'Stock insuficiente: %', p.nombre; end if;
    pu := case when p_tipo = 'Mayorista' then p.precio_mayorista else p.precio_detalle end;
    v_sub := v_sub + pu * q;
    if not p.exento then v_iva := v_iva + pu * q * (1 - d) * v_rate; end if;
    v_costo := v_costo + p.costo * q;
  end loop;

  insert into ventas (cliente, tipo_precio, forma_pago, descuento_pct, subtotal, descuento, iva, total, utilidad)
  values (coalesce(nullif(trim(p_cliente),''),'Consumidor final'), p_tipo, p_pago, d*100,
          round(v_sub,2), round(v_sub*d,2), round(v_iva,2), round(v_sub - v_sub*d + v_iva,2),
          round(v_sub - v_sub*d - v_costo,2))
  returning * into v;

  for it in select * from jsonb_array_elements(p_items) loop
    q := (it->>'cantidad')::int;
    select * into p from productos where id = (it->>'producto_id')::bigint;
    pu := case when p_tipo = 'Mayorista' then p.precio_mayorista else p.precio_detalle end;
    update productos set stock = stock - q where id = p.id;   -- el CHECK (stock >= 0) evita sobreventa
    insert into venta_items (venta_id, producto_id, nombre, unidad, cantidad, precio, costo, exento)
    values (v.id, p.id, p.nombre, p.unidad, q, pu, p.costo, p.exento);
    insert into movimientos (producto_id, tipo, cantidad, saldo, referencia)
    values (p.id, 'Venta', -q, (select stock from productos where id = p.id), v.numero);
  end loop;
  return v;
end $$;

create function registrar_compra(p_producto bigint, p_proveedor text, p_documento text, p_cantidad int, p_costo numeric, p_metodo text)
returns compras language plpgsql security definer set search_path = public as $$
declare p productos; c compras; nc numeric;
begin
  if auth.uid() is null then raise exception 'No autenticado'; end if;
  if p_cantidad <= 0 or p_costo < 0 then raise exception 'Cantidad o costo inválido'; end if;
  if coalesce(trim(p_proveedor),'') = '' or coalesce(trim(p_documento),'') = '' then
    raise exception 'Proveedor y N.º de documento son obligatorios'; end if;
  select * into p from productos where id = p_producto and activo for update;
  if not found then raise exception 'Producto no existe'; end if;
  nc := case when p_metodo = 'p' then round((p.stock*p.costo + p_cantidad*p_costo) / (p.stock + p_cantidad), 2) else p_costo end;
  update productos set stock = stock + p_cantidad, costo = nc where id = p.id;
  insert into compras (producto_id, proveedor, documento, cantidad, costo_unit, total, metodo)
  values (p.id, trim(p_proveedor), trim(p_documento), p_cantidad, p_costo, round(p_cantidad*p_costo,2), p_metodo)
  returning * into c;
  insert into movimientos (producto_id, tipo, cantidad, saldo, referencia)
  values (p.id, 'Compra', p_cantidad, p.stock + p_cantidad, trim(p_documento));
  return c;
end $$;

create function registrar_ajuste(p_producto bigint, p_tipo text, p_cantidad int, p_motivo text)
returns void language plpgsql security definer set search_path = public as $$
declare p productos; delta int;
begin
  if auth.uid() is null then raise exception 'No autenticado'; end if;
  if coalesce(trim(p_motivo),'') = '' then raise exception 'El motivo es obligatorio'; end if;
  if p_cantidad < 0 then raise exception 'Cantidad inválida'; end if;
  select * into p from productos where id = p_producto and activo for update;
  if not found then raise exception 'Producto no existe'; end if;
  delta := case p_tipo
    when 'Ajuste físico' then p_cantidad - p.stock
    when 'Devolución de cliente' then p_cantidad
    when 'Merma' then -p_cantidad
    when 'Daño' then -p_cantidad
    else null end;
  if delta is null then raise exception 'Tipo de ajuste inválido'; end if;
  if delta = 0 then raise exception 'No hay diferencia que registrar'; end if;
  if p.stock + delta < 0 then raise exception 'La cantidad supera el stock disponible'; end if;
  update productos set stock = stock + delta where id = p.id;
  insert into movimientos (producto_id, tipo, cantidad, saldo, referencia)
  values (p.id, p_tipo, delta, p.stock + delta, trim(p_motivo));
end $$;

revoke execute on function registrar_venta(text,text,text,numeric,jsonb) from public, anon;
revoke execute on function registrar_compra(bigint,text,text,int,numeric,text) from public, anon;
revoke execute on function registrar_ajuste(bigint,text,int,text) from public, anon;
grant execute on function registrar_venta(text,text,text,numeric,jsonb) to authenticated;
grant execute on function registrar_compra(bigint,text,text,int,numeric,text) to authenticated;
grant execute on function registrar_ajuste(bigint,text,int,text) to authenticated;
