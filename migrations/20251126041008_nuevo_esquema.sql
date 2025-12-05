
-- =========================================
-- 1. TABLAS
-- =========================================

CREATE TABLE IF NOT EXISTS detalle_productos (
                                               id_detalle_producto INT AUTO_INCREMENT PRIMARY KEY,
                                               descripcion VARCHAR(45) NOT NULL,
  unidades INT NOT NULL
  );

CREATE TABLE IF NOT EXISTS productos (
                                       codigo_producto INT AUTO_INCREMENT PRIMARY KEY,
                                       fldNombre VARCHAR(100) NOT NULL,
  fldPrecio DECIMAL(10,2) NOT NULL,
  fldMarca VARCHAR(45),
  id_detalle_producto INT NOT NULL,
  FOREIGN KEY (id_detalle_producto) REFERENCES detalle_productos(id_detalle_producto) ON DELETE CASCADE
  );

CREATE TABLE IF NOT EXISTS cliente (
                                     telefono VARCHAR(10) PRIMARY KEY,
  fldNombres VARCHAR(45) NOT NULL,
  fldApellidos VARCHAR(45) NOT NULL,
  fldContrasena VARCHAR(255),
  fldCorreoElectronico VARCHAR(100)
  );

CREATE TABLE IF NOT EXISTS tipo_consulta (
                                           id_tipo INT AUTO_INCREMENT PRIMARY KEY,
                                           fldOpciones VARCHAR(45) NOT NULL
  );

CREATE TABLE IF NOT EXISTS consulta (
                                      id_consulta INT AUTO_INCREMENT PRIMARY KEY,
                                      telefono VARCHAR(10) NOT NULL,
  id_tipo INT NOT NULL,
  fldAsunto VARCHAR(45) NOT NULL,
  fldMensaje VARCHAR(200) NOT NULL,
  FOREIGN KEY (telefono) REFERENCES cliente(telefono) ON DELETE CASCADE,
  FOREIGN KEY (id_tipo) REFERENCES tipo_consulta(id_tipo)
  );

CREATE TABLE IF NOT EXISTS categorias (
                                        id_categorias INT AUTO_INCREMENT PRIMARY KEY,
                                        fldNombre VARCHAR(45) NOT NULL,
  fldDescripcion VARCHAR(100) NOT NULL,
  visible TINYINT DEFAULT 1
  );

CREATE TABLE IF NOT EXISTS categorias_x_productos (
                                                    id_categorias INT NOT NULL,
                                                    codigo_producto INT NOT NULL,
                                                    PRIMARY KEY (id_categorias, codigo_producto),
  FOREIGN KEY (id_categorias) REFERENCES categorias(id_categorias) ON DELETE CASCADE,
  FOREIGN KEY (codigo_producto) REFERENCES productos(codigo_producto) ON DELETE CASCADE
  );

CREATE TABLE IF NOT EXISTS usuario (
                                     id_usuario INT AUTO_INCREMENT PRIMARY KEY,
                                     fldTelefono VARCHAR(10) NOT NULL,
  fldNombre VARCHAR(45) NOT NULL,
  fldContrasena VARCHAR(255) NOT NULL,
  fldCorreoElectronico VARCHAR(100) NOT NULL
  );

CREATE TABLE IF NOT EXISTS tipo_pago (
                                       id_tipo_pago INT AUTO_INCREMENT PRIMARY KEY,
                                       tipo VARCHAR(45) NOT NULL
  );

CREATE TABLE IF NOT EXISTS ventas (
                                    idventas INT AUTO_INCREMENT PRIMARY KEY,
                                    fldFecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                    telefono VARCHAR(10) NOT NULL,
  id_usuario INT NOT NULL,
  estado ENUM('pendiente','pagado','cancelado') DEFAULT 'pendiente',
  FOREIGN KEY (telefono) REFERENCES cliente(telefono) ON DELETE RESTRICT,
  FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario) ON DELETE RESTRICT
  );

CREATE TABLE IF NOT EXISTS comprobante (
                                         id_comprobante INT AUTO_INCREMENT PRIMARY KEY,
                                         id_tipo_pago INT NOT NULL,
                                         idventas INT NOT NULL,
                                         FOREIGN KEY (id_tipo_pago) REFERENCES tipo_pago(id_tipo_pago),
  FOREIGN KEY (idventas) REFERENCES ventas(idventas) ON DELETE CASCADE
  );

CREATE TABLE IF NOT EXISTS detalle_ventas (
                                            idventas INT NOT NULL,
                                            codigo_producto INT NOT NULL,
                                            cantidad INT NOT NULL,
                                            subtotal DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (idventas, codigo_producto),
  FOREIGN KEY (idventas) REFERENCES ventas(idventas) ON DELETE CASCADE,
  FOREIGN KEY (codigo_producto) REFERENCES productos(codigo_producto) ON DELETE RESTRICT
  );

-- =========================================
-- 2. PROCEDIMIENTOS ALMACENADOS
-- =========================================

-- --- CLIENTES ---
CREATE PROCEDURE sp_registrar_cliente(
  IN p_telefono VARCHAR(10),
  IN p_nombres VARCHAR(45),
  IN p_apellidos VARCHAR(45),
  IN p_correo VARCHAR(100),
  IN p_contrasena VARCHAR(255)
)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM cliente WHERE telefono = p_telefono) THEN
    INSERT INTO cliente (telefono, fldNombres, fldApellidos, fldCorreoElectronico, fldContrasena)
    VALUES (p_telefono, p_nombres, p_apellidos, p_correo, p_contrasena);
END IF;
END;

CREATE PROCEDURE sp_listar_clientes()
BEGIN
SELECT telefono, fldNombres, fldApellidos, fldCorreoElectronico
FROM cliente
ORDER BY fldNombres;
END;

CREATE PROCEDURE sp_editar_cliente(
  IN p_telefono VARCHAR(10),
  IN p_nombres VARCHAR(45),
  IN p_apellidos VARCHAR(45),
  IN p_correo VARCHAR(100),
  IN p_nueva_contrasena VARCHAR(255)
)
BEGIN
UPDATE cliente
SET fldNombres = p_nombres,
    fldApellidos = p_apellidos,
    fldCorreoElectronico = p_correo
WHERE telefono = p_telefono;

IF p_nueva_contrasena IS NOT NULL AND p_nueva_contrasena != '' THEN
UPDATE cliente SET fldContrasena = p_nueva_contrasena
WHERE telefono = p_telefono;
END IF;
END;

CREATE PROCEDURE sp_eliminar_cliente(IN p_telefono VARCHAR(10))
BEGIN
  IF EXISTS (SELECT 1 FROM ventas WHERE telefono = p_telefono) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se puede eliminar: El cliente tiene historial de compras.';
ELSE
DELETE FROM cliente WHERE telefono = p_telefono;
END IF;
END;

-- --- USUARIOS (ADMIN) ---
CREATE PROCEDURE sp_registrar_usuario(
  IN p_telefono VARCHAR(10),
  IN p_nombre VARCHAR(45),
  IN p_contrasena VARCHAR(255),
  IN p_correo VARCHAR(100)
)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM usuario WHERE fldTelefono = p_telefono) THEN
    INSERT INTO usuario (fldTelefono, fldNombre, fldContrasena, fldCorreoElectronico)
    VALUES (p_telefono, p_nombre, p_contrasena, p_correo);
END IF;
END;

CREATE PROCEDURE sp_listar_usuarios()
BEGIN
SELECT id_usuario, fldTelefono, fldNombre, fldCorreoElectronico
FROM usuario
ORDER BY fldNombre;
END;

CREATE PROCEDURE sp_editar_usuario(
  IN p_id_usuario INT,
  IN p_telefono VARCHAR(10),
  IN p_nombre VARCHAR(45),
  IN p_correo VARCHAR(100),
  IN p_nueva_contrasena VARCHAR(255)
)
BEGIN
UPDATE usuario
SET fldTelefono = p_telefono,
    fldNombre = p_nombre,
    fldCorreoElectronico = p_correo
WHERE id_usuario = p_id_usuario;

IF p_nueva_contrasena IS NOT NULL AND p_nueva_contrasena != '' THEN
UPDATE usuario SET fldContrasena = p_nueva_contrasena
WHERE id_usuario = p_id_usuario;
END IF;
END;

CREATE PROCEDURE sp_eliminar_usuario(IN p_id_usuario INT)
BEGIN
    -- Borrado en cascada seguro
    DELETE c FROM comprobante c INNER JOIN ventas v ON c.idventas = v.idventas WHERE v.id_usuario = p_id_usuario;
    DELETE dv FROM detalle_ventas dv INNER JOIN ventas v ON dv.idventas = v.idventas WHERE v.id_usuario = p_id_usuario;
DELETE FROM ventas WHERE id_usuario = p_id_usuario;
DELETE FROM usuario WHERE id_usuario = p_id_usuario;
END;

-- --- CONSULTAS Y CARRITO ---
CREATE PROCEDURE sp_registrar_consulta(
  IN p_telefono VARCHAR(10),
  IN p_id_tipo INT,
  IN p_asunto VARCHAR(45),
  IN p_mensaje VARCHAR(200)
)
BEGIN
  IF EXISTS (SELECT 1 FROM cliente WHERE telefono = p_telefono) THEN
    INSERT INTO consulta (telefono, id_tipo, fldAsunto, fldMensaje)
    VALUES (p_telefono, p_id_tipo, p_asunto, p_mensaje);
END IF;
END;

CREATE PROCEDURE sp_agregar_producto_carrito(
  IN p_idventas INT,
  IN p_codigo_producto INT,
  IN p_cantidad INT
)
BEGIN
  IF EXISTS (SELECT 1 FROM ventas WHERE idventas = p_idventas AND estado = 'pendiente') THEN
    IF EXISTS (SELECT 1 FROM detalle_ventas WHERE idventas = p_idventas AND codigo_producto = p_codigo_producto) THEN
UPDATE detalle_ventas dv
  JOIN productos p ON p.codigo_producto = dv.codigo_producto
  SET dv.cantidad = dv.cantidad + p_cantidad,
    dv.subtotal = (dv.cantidad + p_cantidad) * p.fldPrecio
WHERE dv.idventas = p_idventas AND dv.codigo_producto = p_codigo_producto;
ELSE
        INSERT INTO detalle_ventas (idventas, codigo_producto, cantidad, subtotal)
SELECT p_idventas, p_codigo_producto, p_cantidad, (p.fldPrecio * p_cantidad)
FROM productos p
WHERE p.codigo_producto = p_codigo_producto;
END IF;
END IF;
END;

CREATE PROCEDURE sp_eliminar_producto_carrito(IN p_idventas INT, IN p_codigo_producto INT)
BEGIN
DELETE FROM detalle_ventas
WHERE idventas = p_idventas AND codigo_producto = p_codigo_producto;
END;

CREATE PROCEDURE sp_actualizar_producto_carrito(
  IN p_idventas INT,
  IN p_codigo_producto INT,
  IN p_nueva_cantidad INT
)
BEGIN
  IF p_nueva_cantidad > 0 THEN
UPDATE detalle_ventas dv
  JOIN productos p ON p.codigo_producto = dv.codigo_producto
  SET dv.cantidad = p_nueva_cantidad,
    dv.subtotal = p.fldPrecio * p_nueva_cantidad
WHERE dv.idventas = p_idventas AND dv.codigo_producto = p_codigo_producto;
ELSE
DELETE FROM detalle_ventas
WHERE idventas = p_idventas AND codigo_producto = p_codigo_producto;
END IF;
END;

CREATE PROCEDURE sp_listar_carrito_completo(IN p_idventas INT)
BEGIN
SELECT
  dv.idventas,
  dv.codigo_producto,
  p.fldNombre AS Producto,
  p.fldMarca AS Marca,
  dp.descripcion AS DetalleDescripcion,
  dp.unidades AS StockActual,
  p.fldPrecio AS PrecioUnitario,
  dv.cantidad,
  dv.subtotal
FROM detalle_ventas dv
       INNER JOIN productos p ON dv.codigo_producto = p.codigo_producto
       INNER JOIN detalle_productos dp ON p.id_detalle_producto = dp.id_detalle_producto
WHERE dv.idventas = p_idventas
ORDER BY p.fldNombre;
END;

CREATE PROCEDURE sp_finalizar_compra(IN p_idventas INT, IN p_id_tipo_pago INT)
BEGIN
INSERT INTO comprobante (id_tipo_pago, idventas) VALUES (p_id_tipo_pago, p_idventas);
UPDATE ventas SET estado = 'pagado' WHERE idventas = p_idventas;
SELECT IFNULL(SUM(subtotal), 0) AS total_pagado FROM detalle_ventas WHERE idventas = p_idventas;
END;

CREATE PROCEDURE sp_cancelar_venta(IN p_idventas INT)
BEGIN
UPDATE ventas SET estado = 'cancelado' WHERE idventas = p_idventas;
END;

-- --- PRODUCTOS Y CATEGORÍAS (VISTAS) ---
CREATE PROCEDURE sp_listar_categorias_menu()
BEGIN
SELECT id_categorias, fldNombre FROM categorias WHERE visible = 1 ORDER BY fldNombre;
END;

CREATE PROCEDURE sp_listar_productos_por_categoria(IN p_id_categoria INT)
BEGIN
SELECT
  c.fldNombre AS Categoria,
  p.codigo_producto,
  p.fldNombre AS Producto,
  p.fldPrecio,
  p.fldMarca
FROM categorias c
       INNER JOIN categorias_x_productos cp ON c.id_categorias = cp.id_categorias
       INNER JOIN productos p ON cp.codigo_producto = p.codigo_producto
WHERE c.id_categorias = p_id_categoria AND c.visible = 1
ORDER BY p.fldNombre;
END;

CREATE PROCEDURE sp_obtener_producto_por_id(IN p_codigo_producto INT)
BEGIN
SELECT
  p.codigo_producto,
  p.fldNombre,
  p.fldPrecio,
  p.fldMarca,
  dp.descripcion,
  dp.unidades
FROM productos p
       INNER JOIN detalle_productos dp ON p.id_detalle_producto = dp.id_detalle_producto
WHERE p.codigo_producto = p_codigo_producto;
END;

-- --- REPORTES Y GESTIÓN DE PRODUCTOS (ADMIN) ---
CREATE PROCEDURE sp_listar_ventas()
BEGIN
SELECT
  v.idventas, v.fldFecha,
  CONCAT(c.fldNombres, ' ', c.fldApellidos) AS Cliente,
  v.estado,
  COALESCE(SUM(dv.subtotal), 0) AS Total
FROM ventas v
       INNER JOIN cliente c ON v.telefono = c.telefono
       LEFT JOIN detalle_ventas dv ON v.idventas = dv.idventas
WHERE v.estado = 'pagado'
GROUP BY v.idventas
ORDER BY v.fldFecha DESC;
END;

CREATE PROCEDURE sp_eliminar_venta(IN p_idventas INT)
BEGIN
DELETE FROM comprobante WHERE idventas = p_idventas;
DELETE FROM detalle_ventas WHERE idventas = p_idventas;
DELETE FROM ventas WHERE idventas = p_idventas;
END;

CREATE PROCEDURE sp_listar_productos_admin()
BEGIN
SELECT
  p.codigo_producto,
  p.fldNombre AS nombre_producto,
  p.fldPrecio AS precio,
  p.fldMarca AS marca,
  dp.descripcion AS detalle_descripcion,
  dp.unidades AS stock_actual,
  GROUP_CONCAT(COALESCE(c.fldNombre, '') SEPARATOR ', ') AS categorias
FROM productos p
       INNER JOIN detalle_productos dp ON p.id_detalle_producto = dp.id_detalle_producto
       LEFT JOIN categorias_x_productos cxp ON p.codigo_producto = cxp.codigo_producto
       LEFT JOIN categorias c ON cxp.id_categorias = c.id_categorias AND c.visible = 1
GROUP BY p.codigo_producto
ORDER BY p.fldNombre;
END;

CREATE PROCEDURE sp_crear_producto_admin(
  IN p_nombre VARCHAR(100),
  IN p_precio DECIMAL(10,2),
  IN p_marca VARCHAR(45),
  IN p_descripcion_detalle VARCHAR(45),
  IN p_unidades INT,
  IN p_categorias_json JSON
)
BEGIN
  DECLARE v_id_detalle INT;
  DECLARE v_codigo_producto INT;

  IF p_categorias_json IS NOT NULL AND JSON_LENGTH(p_categorias_json) > 0 THEN
    IF EXISTS (
      SELECT 1 FROM JSON_TABLE(p_categorias_json, '$[*]' COLUMNS(cat_id INT PATH '$')) jt
      LEFT JOIN categorias c ON c.id_categorias = jt.cat_id
      WHERE c.id_categorias IS NULL
    ) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Una o más categorías no existen';
END IF;
END IF;

INSERT INTO detalle_productos (descripcion, unidades) VALUES (p_descripcion_detalle, p_unidades);
SET v_id_detalle = LAST_INSERT_ID();

INSERT INTO productos (fldNombre, fldPrecio, fldMarca, id_detalle_producto)
VALUES (p_nombre, p_precio, p_marca, v_id_detalle);
SET v_codigo_producto = LAST_INSERT_ID();

  IF p_categorias_json IS NOT NULL AND JSON_LENGTH(p_categorias_json) > 0 THEN
    INSERT INTO categorias_x_productos (id_categorias, codigo_producto)
SELECT cat_id, v_codigo_producto
FROM JSON_TABLE(p_categorias_json, '$[*]' COLUMNS(cat_id INT PATH '$')) AS jt;
END IF;

SELECT v_codigo_producto AS nuevo_codigo_producto;
END;

CREATE PROCEDURE sp_actualizar_producto_admin(
  IN p_codigo_producto INT,
  IN p_nombre VARCHAR(100),
  IN p_precio DECIMAL(10,2),
  IN p_marca VARCHAR(45),
  IN p_descripcion_detalle VARCHAR(45),
  IN p_unidades INT,
  IN p_categorias_json JSON
)
BEGIN
  DECLARE v_id_detalle INT;

SELECT id_detalle_producto INTO v_id_detalle
FROM productos WHERE codigo_producto = p_codigo_producto;

IF v_id_detalle IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Producto no encontrado';
END IF;

  IF p_categorias_json IS NOT NULL AND JSON_LENGTH(p_categorias_json) > 0 THEN
    IF EXISTS (
      SELECT 1 FROM JSON_TABLE(p_categorias_json, '$[*]' COLUMNS(cat_id INT PATH '$')) jt
      LEFT JOIN categorias c ON c.id_categorias = jt.cat_id
      WHERE c.id_categorias IS NULL
    ) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Una o más categorías no existen';
END IF;
END IF;

UPDATE productos SET fldNombre = p_nombre, fldPrecio = p_precio, fldMarca = p_marca
WHERE codigo_producto = p_codigo_producto;

UPDATE detalle_productos SET descripcion = p_descripcion_detalle, unidades = p_unidades
WHERE id_detalle_producto = v_id_detalle;

DELETE FROM categorias_x_productos WHERE codigo_producto = p_codigo_producto;

IF p_categorias_json IS NOT NULL AND JSON_LENGTH(p_categorias_json) > 0 THEN
    INSERT INTO categorias_x_productos (id_categorias, codigo_producto)
SELECT cat_id, p_codigo_producto
FROM JSON_TABLE(p_categorias_json, '$[*]' COLUMNS(cat_id INT PATH '$')) AS jt;
END IF;

SELECT 'Producto actualizado correctamente' AS mensaje;
END;

CREATE PROCEDURE sp_eliminar_producto_admin(IN p_codigo_producto INT)
BEGIN
  IF EXISTS (SELECT 1 FROM detalle_ventas WHERE codigo_producto = p_codigo_producto) THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'No se puede eliminar: El producto tiene ventas registradas.';
ELSE
DELETE FROM categorias_x_productos WHERE codigo_producto = p_codigo_producto;
DELETE FROM productos WHERE codigo_producto = p_codigo_producto;
-- Opcional: Borrar detalle huérfano si fuera necesario
SELECT 'Producto eliminado correctamente' AS mensaje;
END IF;
END;

-- =========================================
-- 3. TRIGGERS
-- =========================================

CREATE TRIGGER trg_validar_stock_carrito BEFORE INSERT ON detalle_ventas FOR EACH ROW
BEGIN
  DECLARE v_stock INT;
  SELECT unidades INTO v_stock
  FROM detalle_productos dp
         JOIN productos p ON p.id_detalle_producto = dp.id_detalle_producto
  WHERE p.codigo_producto = NEW.codigo_producto;

  IF v_stock IS NULL OR v_stock < NEW.cantidad THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock insuficiente para este componente electrónico';
END IF;
END;

CREATE TRIGGER trg_descontar_stock_carrito AFTER INSERT ON detalle_ventas FOR EACH ROW
BEGIN
  UPDATE detalle_productos dp
    JOIN productos p ON p.id_detalle_producto = dp.id_detalle_producto
    SET dp.unidades = dp.unidades - NEW.cantidad
  WHERE p.codigo_producto = NEW.codigo_producto;
END;

CREATE TRIGGER trg_restaurar_stock_carrito AFTER DELETE ON detalle_ventas FOR EACH ROW
BEGIN
  UPDATE detalle_productos dp
    JOIN productos p ON p.id_detalle_producto = dp.id_detalle_producto
    SET dp.unidades = dp.unidades + OLD.cantidad
  WHERE p.codigo_producto = OLD.codigo_producto;
END;

CREATE TRIGGER trg_ajustar_stock_al_actualizar BEFORE UPDATE ON detalle_ventas FOR EACH ROW
BEGIN
  DECLARE v_stock INT;
  DECLARE v_diferencia INT DEFAULT NEW.cantidad - OLD.cantidad;

  IF v_diferencia > 0 THEN
  SELECT unidades INTO v_stock
  FROM detalle_productos dp
         JOIN productos p ON p.id_detalle_producto = dp.id_detalle_producto
  WHERE p.codigo_producto = NEW.codigo_producto;

  IF v_stock < v_diferencia THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock insuficiente para aumentar cantidad';
END IF;
END IF;
END;

CREATE TRIGGER trg_aplicar_ajuste_stock_post_update AFTER UPDATE ON detalle_ventas FOR EACH ROW
BEGIN
  DECLARE v_diferencia INT DEFAULT NEW.cantidad - OLD.cantidad;
  UPDATE detalle_productos dp
    JOIN productos p ON p.id_detalle_producto = dp.id_detalle_producto
    SET dp.unidades = dp.unidades - v_diferencia
  WHERE p.codigo_producto = NEW.codigo_producto;
END;

CREATE TRIGGER trg_venta_pagada AFTER INSERT ON comprobante FOR EACH ROW
BEGIN
  UPDATE ventas
  SET estado = 'pagado'
  WHERE idventas = NEW.idventas;
END;

-- =========================================
-- 4. DATOS DE PRUEBA (INSERTS)
-- =========================================

INSERT INTO detalle_productos (descripcion, unidades) VALUES
                                                        ('Bolsa de 100 piezas', 100),
                                                        ('Bolsa de 50 piezas', 50),
                                                        ('Tira de 10 piezas', 10),
                                                        ('Pack 200 resistores 1/4W', 200),
                                                        ('Pack 100 condensadores 10µF', 100),
                                                        ('Pack 50 transistores NPN', 50),
                                                        ('Kit 5 integrados 555 Timer', 5),
                                                        ('Bolsa 100 diodos 1N4007', 100),
                                                        ('Pack 50 LED rojos 5mm', 50),
                                                        ('Pack 50 LED verdes 5mm', 50);

INSERT INTO productos (fldNombre, fldPrecio, fldMarca, id_detalle_producto) VALUES
                                                                              ('Resistor 10kΩ 1/4W', 0.50, 'Vishay', 1),
                                                                              ('Condensador 10µF 16V', 1.20, 'Panasonic', 2),
                                                                              ('Transistor NPN BC547', 2.50, 'ON Semiconductor', 3),
                                                                              ('Circuito integrado 555 Timer', 12.00, 'STMicro', 4),
                                                                              ('Diodo rectificador 1N4007', 0.80, 'Diotec', 5),
                                                                              ('Resistor 1kΩ 1/4W', 0.45, 'Vishay', 6),
                                                                              ('Condensador 100µF 16V', 1.50, 'Panasonic', 7),
                                                                              ('LED rojo 5mm', 0.10, 'Kingbright', 8),
                                                                              ('LED verde 5mm', 0.10, 'Kingbright', 9),
                                                                              ('Transistor PNP BC558', 2.80, 'ON Semiconductor', 10);

INSERT INTO cliente (telefono, fldNombres, fldApellidos, fldCorreoElectronico, fldContrasena) VALUES
                                                                                                ('9611234567', 'Juan', 'Pérez', 'juan@example.com', 'HASH_PENDIENTE_REGISTRATE_POR_API'),
                                                                                                ('9619876543', 'Ana', 'López', 'ana@example.com', 'HASH_PENDIENTE_REGISTRATE_POR_API');

INSERT INTO tipo_consulta (fldOpciones) VALUES
                                          ('Producto defectuoso'),('Método de pago'),('Envío'),('Garantía'),('Devolución');

INSERT INTO categorias (fldNombre, fldDescripcion) VALUES
                                                      ('Servicios', 'Servicios especializados, soporte técnico y soluciones electrónicas'),
                                                      ('SMD', 'Componentes electrónicos de montaje superficial'),
                                                      ('Componentes', 'Resistencias, capacitores, transistores y más'),
                                                      ('Kits', 'Kits electrónicos para aprendizaje'),
                                                      ('Marcas', 'Catálogo por marcas'),
                                                      ('Laboratorio', 'Herramientas y equipos'),
                                                      ('Energía', 'Fuentes, baterías y cargadores'),
                                                      ('Tarjetas', 'Arduino, ESP32, Raspberry Pi'),
                                                      ('Sensores', 'Sensores varios'),
                                                      ('Módulos', 'Módulos electrónicos listos para usar'),
                                                      ('Optoelectrónica', 'LEDs, displays y fotodiodos'),
                                                      ('Robótica', 'Motores y controladores'),
                                                      ('Outlet', 'Productos en oferta'),
                                                      ('Accesorios', 'Accesorios para proyectos');

INSERT INTO categorias_x_productos (id_categorias, codigo_producto) VALUES
                                                                      (1,1),(1,2),(2,3),(2,4),(2,5),
                                                                      (1,6),(1,7),(3,8),(3,9),(2,10);

INSERT INTO usuario (fldTelefono, fldNombre, fldContrasena, fldCorreoElectronico) VALUES
  ('9615555555', 'Admin', 'HASH_PENDIENTE_REGISTRATE_POR_API', 'admin@example.com');

INSERT INTO tipo_pago (tipo) VALUES ('Tarjeta'),('Efectivo'),('Transferencia');

INSERT INTO ventas (fldFecha, telefono, id_usuario, estado) VALUES
  (NOW(), '9611234567', 1, 'pendiente');

INSERT INTO detalle_ventas (idventas, codigo_producto, cantidad, subtotal) VALUES
  (1,1,10,5.00);
