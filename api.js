// Capa de datos: traduce entre Supabase y el modelo que usa la interfaz.
(function () {
  const C = window.APP_CONFIG || {};
  if (!C.SUPABASE_URL || C.SUPABASE_URL.includes('TU-PROYECTO')) alert('Configura js/config.js con la URL y la anon key de tu proyecto Supabase.');
  const sb = window.supabase.createClient(C.SUPABASE_URL || 'http://x', C.SUPABASE_ANON_KEY || 'x');
  const ok = r => { if (r.error) throw new Error(r.error.message); return r.data; };
  const fmt = d => new Date(d).toLocaleString('es-NI', { dateStyle: 'short', timeStyle: 'short' });
  const n = Number;

  window.API = {
    async session() { return (await sb.auth.getSession()).data.session; },
    async signIn(email, password) { ok(await sb.auth.signInWithPassword({ email, password })); },
    async signOut() { await sb.auth.signOut(); },

    async load() {
      const [cf, pr, mv, vt, cp] = await Promise.all([
        sb.from('configuracion').select('tipo_cambio').eq('id', 1).single(),
        sb.from('productos').select('id,code:codigo,name:nombre,cat:categoria,sub:subcategoria,um:unidad,cost:costo,price:precio_detalle,pm:precio_mayorista,stock,min:stock_minimo,ex:exento').eq('activo', true).order('codigo'),
        sb.from('movimientos').select('producto_id,tipo,cantidad,saldo,referencia,created_at').order('id', { ascending: false }).limit(1000),
        sb.from('ventas').select('*,venta_items(*)').order('id', { ascending: false }).limit(1000),
        sb.from('compras').select('*,productos(nombre)').order('id', { ascending: false }).limit(1000)
      ]);
      return {
        rate: n(ok(cf).tipo_cambio),
        prods: ok(pr).map(p => ({ ...p, cost: n(p.cost), price: n(p.price), pm: n(p.pm), ex: p.ex ? 1 : 0 })),
        movs: ok(mv).reverse().map(m => ({ d: fmt(m.created_at), pid: m.producto_id, type: m.tipo, qty: m.cantidad, bal: m.saldo, ref: m.referencia || '' })),
        sales: ok(vt).reverse().map(s => ({
          num: s.numero, d: fmt(s.created_at), cli: s.cliente, tipo: s.tipo_precio, pay: s.forma_pago, dsc: n(s.descuento_pct),
          sub: n(s.subtotal), ds: n(s.descuento), iva: n(s.iva), total: n(s.total), utilidad: n(s.utilidad),
          items: s.venta_items.map(i => ({ pid: i.producto_id, name: i.nombre, um: i.unidad, qty: i.cantidad, price: n(i.precio), ex: i.exento ? 1 : 0 }))
        })),
        buys: ok(cp).reverse().map(b => ({ d: fmt(b.created_at), pid: b.producto_id, name: b.productos ? b.productos.nombre : '—', prov: b.proveedor, doc: b.documento, qty: b.cantidad, cost: n(b.costo_unit), total: n(b.total), met: b.metodo === 'p' ? 'Promedio' : 'Último' }))
      };
    },

    async saveProduct(id, d, oldStock) {
      const row = { codigo: d.code, nombre: d.name, categoria: d.cat, subcategoria: d.sub, unidad: d.um, costo: d.cost, precio_detalle: d.price, precio_mayorista: d.pm, stock_minimo: d.min, exento: !!d.ex };
      if (id) {
        ok(await sb.from('productos').update(row).eq('id', id));
        if (d.stock !== oldStock) ok(await sb.rpc('registrar_ajuste', { p_producto: id, p_tipo: 'Ajuste físico', p_cantidad: d.stock, p_motivo: 'Edición de producto' }));
      } else ok(await sb.from('productos').insert({ ...row, stock: d.stock }));
    },
    async deleteProduct(id) { ok(await sb.from('productos').update({ activo: false }).eq('id', id)); },
    async setRate(v) { ok(await sb.from('configuracion').update({ tipo_cambio: v }).eq('id', 1)); },
    async sale(cli, tipo, pago, dsc, cart) {
      return ok(await sb.rpc('registrar_venta', { p_cliente: cli, p_tipo: tipo, p_pago: pago, p_dsc: dsc, p_items: cart.map(c => ({ producto_id: c.pid, cantidad: c.qty })) }));
    },
    async buy(pid, prov, doc, qty, cost, met) { return ok(await sb.rpc('registrar_compra', { p_producto: pid, p_proveedor: prov, p_documento: doc, p_cantidad: qty, p_costo: cost, p_metodo: met })); },
    async adjust(pid, tipo, qty, why) { ok(await sb.rpc('registrar_ajuste', { p_producto: pid, p_tipo: tipo, p_cantidad: qty, p_motivo: why })); }
  };
})();
