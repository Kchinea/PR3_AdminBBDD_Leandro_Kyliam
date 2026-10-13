/*
 * Viveros Tajinaste S.A. - Datos de prueba
 * Ejecutar después de viveros.sql:
 *   \i datos.sql
 */

/* Viveros */
INSERT INTO VIVERO (LATITUD, LONGITUD) VALUES
   (28.487400, -16.315900),
   (28.122700, -16.726000),
   (28.414000, -16.544900);

/* Zonas de cada vivero */
INSERT INTO ZONA (LATITUD, LONGITUD, ID_VIVERO) VALUES
   (28.487500, -16.316000, 1),
   (28.487600, -16.315700, 1),
   (28.122800, -16.726100, 2),
   (28.122600, -16.725800, 2),
   (28.414100, -16.545000, 3);

/* Productos */
INSERT INTO PRODUCTO (NOMBRE, TIPO, PRECIO) VALUES
   ('cactus polaco',       'planta',     12.95),
   ('girasol tuerto',      'planta',     24.50),
   ('Saco de escremento',  'jardineria',  8.75),
   ('rastrillo',           'jardineria', 15.00),
   ('enano de jardin',     'decoracion',  6.40);

/* Empleados */
INSERT INTO EMPLEADO (NOMBRE) VALUES
   ('Roberto Padron Castañeda'),
   ('Santiago Plasencia Dominues'),
   ('Kyliam Chinea Salcedo'),
   ('Leandro Delli Santi');

/* Clientes: los que tienen FECHA_INGRESO son Plus, los que no, básicos */
INSERT INTO CLIENTE (NOMBRE, FECHA_INGRESO) VALUES
   ('Paula Grillo San Jose',          '2026-01-15'),
   ('Guillermo Silva Gonzalez',       '2026-03-01'),
   ('Martin Torres Andrade',          NULL),
   ('Jose Carlos Hernandez Bencomo',  NULL);

/* Stock: cantidad de cada producto en cada zona */
INSERT INTO STOCK (ID_ZONA, ID_PRODUCTO, CANTIDAD) VALUES
   (1, 1, 40), (1, 2, 15), (1, 5, 60),
   (2, 3, 100), (2, 4, 25),
   (3, 1, 30), (3, 2, 10),
   (4, 3, 80), (4, 5, 45),
   (5, 1, 20), (5, 4, 12);

/* Histórico de destinos (sin solapamientos para un mismo empleado) */
INSERT INTO TAREA (ID_EMPLEADO, ID_ZONA, FECHA_INICIO, FECHA_FIN, TIPO_DE_TAREA) VALUES
   (1, 1, '2026-01-01', '2026-05-31', 'atencion al cliente'),
   (1, 3, '2026-06-01', NULL,         'atencion al cliente'),
   (2, 2, '2026-01-01', NULL,         'carga y descarga'),
   (3, 4, '2026-02-01', '2026-08-31', 'riego'),
   (4, 5, '2026-01-01', NULL,         'caja');

/* Pedidos */
INSERT INTO PEDIDO (FECHA, ID_EMPLEADO, ID_CLIENTE, ID_ZONA) VALUES
   ('2026-02-10', 1, 1, 1),
   ('2026-02-20', 1, 3, 1),
   ('2026-03-05', 2, 2, 2),
   ('2026-03-18', 4, 1, 5),
   ('2026-07-02', 1, 4, 3);

/* Líneas de pedido: el trigger comprueba y descuenta el stock */
INSERT INTO INCLUYE (ID_PEDIDO, ID_PRODUCTO, CANTIDAD) VALUES
   (1, 1, 2), (1, 5, 3),
   (2, 2, 1),
   (3, 3, 4), (3, 4, 1),
   (4, 1, 1), (4, 4, 2),
   (5, 2, 2);
