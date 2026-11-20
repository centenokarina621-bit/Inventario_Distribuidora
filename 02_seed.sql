-- Datos de prueba (ejecutar DESPUÉS de 01_schema.sql). Opcional.
insert into productos (codigo,nombre,categoria,subcategoria,unidad,costo,precio_detalle,precio_mayorista,stock,stock_minimo,exento) values
('ARZ-050','Arroz Faisán 80/20 saco 50 lb','Granos básicos','Arroz','Saco',1150,1320,1260,40,8,true),
('ARZ-005','Arroz Faisán 5 lb (paq.)','Granos básicos','Arroz','Paquete',68,82,76,120,30,true),
('FRJ-100','Frijol rojo quintal','Granos básicos','Frijol','Quintal',2900,3300,3150,15,4,true),
('AZU-050','Azúcar San Antonio saco 50 lb','Granos básicos','Azúcar','Saco',1080,1240,1180,30,6,true),
('ACE-012','Aceite Ideal 1 L caja x12','Abarrotes','Aceites','Caja',720,820,780,25,6,true),
('LEC-012','Leche Eskimo 1 L caja x12','Lácteos','Leche','Caja',370,430,405,20,5,true),
('CAF-024','Café Presto 200 g caja x24','Abarrotes','Café','Caja',1600,1980,1850,12,4,false),
('GAL-024','Galletas María caja x24','Abarrotes','Galletas','Caja',210,270,250,30,8,false),
('GAS-008','Coca-Cola 2 L caja x8','Bebidas','Gaseosas','Caja',300,390,360,60,15,false),
('AGU-012','Agua Cristal 600 ml paq. x12','Bebidas','Agua','Paquete',90,120,110,70,20,false),
('CER-024','Cerveza Toña lata caja x24','Bebidas','Cervezas','Caja',580,720,680,80,20,false),
('CER-VIC','Cerveza Victoria Clásica caja x24','Bebidas','Cervezas','Caja',560,700,660,0,15,false),
('RON-012','Ron Flor de Caña 4 años caja x12','Licores','Ron','Caja',3900,4800,4500,10,3,false),
('JAB-072','Jabón Palmolive caja x72','Higiene','Jabones','Caja',1080,1350,1260,2,3,false),
('DET-012','Detergente Deterjabón 1 kg caja x12','Limpieza','Detergentes','Caja',560,690,650,15,5,false),
('ATU-048','Atún Calvo 140 g caja x48','Enlatados','Atún','Caja',1500,1850,1720,4,6,false);
