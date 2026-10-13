/*
 * Viveros Tajinaste S.A. - Modelo relacional
 * Uso:
 *   sudo -u postgres psql
 *   \c viveros
 *   \i viveros.sql
 */

/* Borrar todo lo que haya en el esquema 'public' para empezar de cero */
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;


/* ============================== TABLAS ============================== */

/* Tabla 'vivero' */
CREATE TABLE vivero (
    id_vivero  SERIAL PRIMARY KEY,
    latitud    NUMERIC(9,6) NOT NULL CHECK (latitud BETWEEN -90 AND 90),
    longitud   NUMERIC(9,6) NOT NULL CHECK (longitud BETWEEN -180 AND 180)
);

/* Tabla 'zona': entidad débil en existencia, si se borra el vivero se borran sus zonas */
CREATE TABLE zona (
    id_zona    SERIAL PRIMARY KEY,
    latitud    NUMERIC(9,6) NOT NULL CHECK (latitud BETWEEN -90 AND 90),
    longitud   NUMERIC(9,6) NOT NULL CHECK (longitud BETWEEN -180 AND 180),
    id_vivero  INTEGER NOT NULL REFERENCES vivero(id_vivero) ON DELETE CASCADE
);

/* Tabla 'producto' */
CREATE TABLE producto (
    id_producto  SERIAL PRIMARY KEY,
    nombre       VARCHAR(100) NOT NULL,
    tipo         VARCHAR(20)  NOT NULL CHECK (tipo IN ('planta', 'jardineria', 'decoracion')),
    precio       NUMERIC(10,2) NOT NULL CHECK (precio > 0)
);

/* Cambio de los tipos de producto permitidos: se añade 'herramientas' */
ALTER TABLE producto DROP CONSTRAINT producto_tipo_check;
ALTER TABLE producto ADD CONSTRAINT producto_tipo_check
    CHECK (tipo IN ('planta', 'jardineria', 'decoracion', 'herramientas'));

/* Tabla 'empleado' (la productividad es derivada: se calcula en una vista) */
CREATE TABLE empleado (
    id_empleado  SERIAL PRIMARY KEY,
    nombre       VARCHAR(100) NOT NULL
);

/* Tabla 'cliente': jerarquía en una sola tabla.
   fecha_ingreso vacía = cliente básico, con fecha = cliente Plus.
   Las bonificaciones son derivadas: se calculan en una vista */
CREATE TABLE cliente (
    id_cliente     SERIAL PRIMARY KEY,
    nombre         VARCHAR(100) NOT NULL,
    fecha_ingreso  DATE
);

/* Tabla 'pedido': recibe las FK de Gestiona, Hace y En (relaciones 1:N) */
CREATE TABLE pedido (
    id_pedido    SERIAL PRIMARY KEY,
    fecha        DATE NOT NULL DEFAULT CURRENT_DATE,
    id_empleado  INTEGER NOT NULL REFERENCES empleado(id_empleado),
    id_cliente   INTEGER NOT NULL REFERENCES cliente(id_cliente),
    id_zona      INTEGER NOT NULL REFERENCES zona(id_zona)
);

/* Tabla 'stock' (N:M Zona - Producto) */
CREATE TABLE stock (
    id_zona      INTEGER NOT NULL REFERENCES zona(id_zona) ON DELETE CASCADE,
    id_producto  INTEGER NOT NULL REFERENCES producto(id_producto) ON DELETE CASCADE,
    cantidad     INTEGER NOT NULL CHECK (cantidad >= 0),
    PRIMARY KEY (id_zona, id_producto)
);

/* Tabla 'incluye' (N:M Pedido - Producto): las líneas de cada pedido */
CREATE TABLE incluye (
    id_pedido    INTEGER NOT NULL REFERENCES pedido(id_pedido) ON DELETE CASCADE,
    id_producto  INTEGER NOT NULL REFERENCES producto(id_producto),
    cantidad     INTEGER NOT NULL CHECK (cantidad > 0),
    PRIMARY KEY (id_pedido, id_producto)
);

/* Tabla 'tarea' (N:M Empleado - Zona): histórico de destinos.
   fecha_inicio forma parte de la PK porque un empleado puede volver
   a la misma zona en otra temporada */
CREATE TABLE tarea (
    id_empleado    INTEGER NOT NULL REFERENCES empleado(id_empleado),
    id_zona        INTEGER NOT NULL REFERENCES zona(id_zona),
    fecha_inicio   DATE NOT NULL,
    fecha_fin      DATE,
    tipo_de_tarea  VARCHAR(50) NOT NULL,
    PRIMARY KEY (id_empleado, id_zona, fecha_inicio),
    CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio)
);


/* ============================= TRIGGERS ============================= */

/* Función 'comprobar_destinos': un empleado no puede tener dos destinos a la vez.
   Dos periodos se solapan si cada uno empieza antes de que acabe el otro.
   Una FECHA_FIN vacía significa que el destino sigue abierto */
CREATE OR REPLACE FUNCTION comprobar_destinos() RETURNS TRIGGER AS $$
   BEGIN
      IF EXISTS (
         SELECT * FROM TAREA
         WHERE ID_EMPLEADO = NEW.ID_EMPLEADO
           AND (FECHA_FIN IS NULL OR FECHA_FIN >= NEW.FECHA_INICIO)
           AND (NEW.FECHA_FIN IS NULL OR NEW.FECHA_FIN >= FECHA_INICIO)
      ) THEN
         RAISE EXCEPTION 'El empleado % ya tiene un destino en esas fechas', NEW.ID_EMPLEADO;
      END IF;
      RETURN NEW;
   END;
$$ LANGUAGE plpgsql;

/* Trigger 'trg_comprobar_destinos': se ejecuta ANTES de insertar en TAREA */
CREATE TRIGGER trg_comprobar_destinos BEFORE INSERT ON TAREA
FOR EACH ROW EXECUTE PROCEDURE comprobar_destinos();


/* Función 'comprobar_stock': un pedido no puede incluir más unidades de las
   disponibles en la zona desde la que se sirve. Si hay stock, lo descuenta */
CREATE OR REPLACE FUNCTION comprobar_stock() RETURNS TRIGGER AS $$
   BEGIN
      IF NOT EXISTS (
         SELECT * FROM STOCK S
         JOIN PEDIDO P ON P.ID_ZONA = S.ID_ZONA
         WHERE P.ID_PEDIDO = NEW.ID_PEDIDO
           AND S.ID_PRODUCTO = NEW.ID_PRODUCTO
           AND S.CANTIDAD >= NEW.CANTIDAD
      ) THEN
         RAISE EXCEPTION 'No hay stock suficiente del producto % en la zona del pedido %',
            NEW.ID_PRODUCTO, NEW.ID_PEDIDO;
      END IF;

      UPDATE STOCK SET CANTIDAD = CANTIDAD - NEW.CANTIDAD
      WHERE ID_PRODUCTO = NEW.ID_PRODUCTO
        AND ID_ZONA = (SELECT ID_ZONA FROM PEDIDO WHERE ID_PEDIDO = NEW.ID_PEDIDO);

      RETURN NEW;
   END;
$$ LANGUAGE plpgsql;

/* Trigger 'trg_comprobar_stock': se ejecuta ANTES de insertar en INCLUYE */
CREATE TRIGGER trg_comprobar_stock BEFORE INSERT ON INCLUYE
FOR EACH ROW EXECUTE PROCEDURE comprobar_stock();


/* ============================== VISTAS ============================== */

/* Vista 'clientes_plus': el subtipo Plus de la jerarquía */
CREATE VIEW clientes_plus AS
SELECT id_cliente, nombre, fecha_ingreso
FROM cliente
WHERE fecha_ingreso IS NOT NULL;

/* Vista 'BONIFICACIONES_PLUS': volumen de compras de cada cliente Plus por mes
   desde su ingreso, y su bonificación (se supone un 5 % del volumen) */
CREATE VIEW BONIFICACIONES_PLUS AS
SELECT C.ID_CLIENTE, C.NOMBRE,
       EXTRACT(YEAR FROM P.FECHA)  AS ANIO,
       EXTRACT(MONTH FROM P.FECHA) AS MES,
       SUM(I.CANTIDAD * PR.PRECIO)        AS VOLUMEN_COMPRAS,
       SUM(I.CANTIDAD * PR.PRECIO) * 0.05 AS BONIFICACION
FROM CLIENTES_PLUS C
JOIN PEDIDO P    ON P.ID_CLIENTE = C.ID_CLIENTE
JOIN INCLUYE I   ON I.ID_PEDIDO = P.ID_PEDIDO
JOIN PRODUCTO PR ON PR.ID_PRODUCTO = I.ID_PRODUCTO
WHERE P.FECHA >= C.FECHA_INGRESO
GROUP BY C.ID_CLIENTE, C.NOMBRE, EXTRACT(YEAR FROM P.FECHA), EXTRACT(MONTH FROM P.FECHA);

/* Vista 'PRODUCTIVIDAD_EMPLEADO': pedidos e importe vendido por cada empleado por mes */
CREATE VIEW PRODUCTIVIDAD_EMPLEADO AS
SELECT E.ID_EMPLEADO, E.NOMBRE,
       EXTRACT(YEAR FROM P.FECHA)  AS ANIO,
       EXTRACT(MONTH FROM P.FECHA) AS MES,
       COUNT(DISTINCT P.ID_PEDIDO) AS NUM_PEDIDOS,
       SUM(I.CANTIDAD * PR.PRECIO) AS IMPORTE_VENTAS
FROM EMPLEADO E
JOIN PEDIDO P    ON P.ID_EMPLEADO = E.ID_EMPLEADO
JOIN INCLUYE I   ON I.ID_PEDIDO = P.ID_PEDIDO
JOIN PRODUCTO PR ON PR.ID_PRODUCTO = I.ID_PRODUCTO
GROUP BY E.ID_EMPLEADO, E.NOMBRE, EXTRACT(YEAR FROM P.FECHA), EXTRACT(MONTH FROM P.FECHA);

/* Vista 'PRODUCTIVIDAD_ZONA': pedidos e importe vendido desde cada zona por mes */
CREATE VIEW PRODUCTIVIDAD_ZONA AS
SELECT Z.ID_ZONA, Z.ID_VIVERO,
       EXTRACT(YEAR FROM P.FECHA)  AS ANIO,
       EXTRACT(MONTH FROM P.FECHA) AS MES,
       COUNT(DISTINCT P.ID_PEDIDO) AS NUM_PEDIDOS,
       SUM(I.CANTIDAD * PR.PRECIO) AS IMPORTE_VENTAS
FROM ZONA Z
JOIN PEDIDO P    ON P.ID_ZONA = Z.ID_ZONA
JOIN INCLUYE I   ON I.ID_PEDIDO = P.ID_PEDIDO
JOIN PRODUCTO PR ON PR.ID_PRODUCTO = I.ID_PRODUCTO
GROUP BY Z.ID_ZONA, Z.ID_VIVERO, EXTRACT(YEAR FROM P.FECHA), EXTRACT(MONTH FROM P.FECHA);


/* =========================== COMPROBACIONES ========================= */

/* Mostrar todos los triggers creados por nosotros */
SELECT tgname FROM pg_trigger WHERE NOT tgisinternal;

/* Mostrar todas las vistas */
SELECT table_name FROM information_schema.views WHERE table_schema = 'public';
