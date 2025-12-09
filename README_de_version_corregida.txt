SMARTPOINT API

Documentación Completa para Integración con Frontend (Angular)

------------------------------------------------------------------------

1. CONFIGURACIÓN INICIAL DEL BACKEND

1.1 Actualizar el archivo .env

Actualiza la conexión para que apunte a la nueva base de datos
db_smart_point1.

    # Antes: mysql://root:pass@localhost/db_smart_point
    DATABASE_URL="mysql://root:tu_contraseña@localhost/db_smart_point1"

Asegúrate de modificar usuario y contraseña según tu entorno.

------------------------------------------------------------------------

1.2 Actualizar Migración (SQLx)

1.  Ve a la carpeta: /migrations.
2.  Abre el archivo existente, por ejemplo:
    2025xxxxxx_script_inicial.sql.
3.  Borra todo su contenido.
4.  Pega tu nuevo script SQL corregido.

Correcciones necesarias para SQLx:

-   ❌ Eliminar: CREATE DATABASE, USE db_smart_point1.
-   ❌ Eliminar todos los DELIMITER // y DELIMITER ;.
-   ✔ Reemplazar END // por END;
-   ✔ Asegurar que cada trigger y procedure termina solo con ;.

Ya esta listo el archivo en el rar extraído


Aplicar migración

Ejecutar en la raíz del proyecto:

    sqlx database drop
    sqlx database create
    sqlx migrate run

------------------------------------------------------------------------

1.3 Actualizar src/main.rs

El nuevo script SQL contiene SPs completos.

    CALL sp_nombre_procedimiento(...)

El archivo main.rs ya está listo en el archivo rar extraído.

------------------------------------------------------------------------

1.4 Preparar y ejecutar proyecto Rust

    cargo clean
    cargo sqlx prepare
    cargo run

Tu API quedará disponible en:

    http://localhost:3000/api

------------------------------------------------------------------------

2. DOCUMENTACIÓN COMPLETA DE ENDPOINTS (BACKEND)

------------------------------------------------------------------------

Módulo de Productos (Público)
🟢 Listar Todos los Productos (Público)
   Devuelve el catálogo completo, incluyendo una cadena con los nombres de las categorías a las que pertenece cada producto.

   Método: GET

   URL: http://localhost:3000/api/productos

Endpoint: /productos

Respuesta Exitosa (200 OK):

JSON

[
    {
        "codigo_producto": 1,
        "fldNombre": "Resistor 10k",
        "fldPrecio": "0.50",
        "fldMarca": "Vishay",
        "descripcion": "Bolsa de 100 piezas",
        "unidades": 100,
        "categorias_nombres": "Componentes pasivos, Componentes",
        "categorias_ids": "1,3"
    },
    {
        "codigo_producto": 3,
        "fldNombre": "Transistor NPN BC547",
        "fldPrecio": "2.50",
        "fldMarca": "ON Semiconductor",
        "descripcion": "Pack 50 transistores NPN",
        "unidades": 50,
        "categorias_nombres": "Semiconductores, Componentes",
        "categorias_ids": "2,3"
    }
]
🟢 Obtener producto por ID
Obtiene los detalles específicos de un producto.

Método: GET

Endpoint: /productos/1 (Reemplaza 1 por el ID real)

Respuesta Exitosa (200 OK):

JSON

{
    "codigo_producto": 1,
    "fldNombre": "Resistor 10k",
    "fldPrecio": "0.50",
    "fldMarca": "Vishay",
    "descripcion": "Bolsa de 100 piezas",
    "unidades": 100,
    "categorias_nombres": "Componentes pasivos, Componentes",
    "categorias_ids": "1,3"
}

2. Módulo de Categorías
🟢 Listar Categorías
Obtiene todas las categorías para generar el menú de navegación.

Método: GET

Endpoint: /categorias

Respuesta Exitosa (200 OK):

JSON

[
  {
    "id_categorias": 1,
    "fldNombre": "Componentes",
    "fldDescripcion": "Resistencias, capacitores, etc."
  },
  {
    "id_categorias": 2,
    "fldNombre": "Robótica",
    "fldDescripcion": "Motores y controladores"
  }
]
🟢 Listar Productos por Categoría
Filtra los productos que pertenecen a una categoría específica.

Método: GET

Endpoint: /categorias/1/productos (Reemplaza 1 por el ID de categoría)

Respuesta Exitosa (200 OK):

JSON

[
  {
    "Categoria": "Componentes",
    "codigo_producto": 1,
    "Producto": "Resistor 10kΩ 1/4W",
    "fldPrecio": "0.50",
    "fldMarca": "Vishay"
  },
  {
    "Categoria": "Componentes",
    "codigo_producto": 5,
    "Producto": "Capacitor 100uF",
    "fldPrecio": "5.00",
    "fldMarca": "Samsung"
  }
]
3. Módulo de Clientes y Autenticación
🟢 Registrar Cliente Nuevo
Crea una cuenta para un usuario final.

Método: POST

Endpoint: /auth/cliente/registro

JSON de Petición (Body):

JSON

{
  "telefono": "9611112222",
  "fldNombres": "Juan",
  "fldApellidos": "Pérez",
  "fldCorreoElectronico": "juan@mail.com",
  "fldContrasena": "password123"
}
Respuesta Exitosa: 201 Created (Sin contenido).

🟢 Iniciar Sesión (Cliente)
Valida credenciales y devuelve token de acceso.

Método: POST

Endpoint: /auth/cliente/login

JSON de Petición (Body):

JSON

{
  "correo": "juan@mail.com",
  "contrasena": "password123"
}
Respuesta Exitosa (200 OK):

JSON

{
  "id": "9611112222",
  "nombre": "Juan",
  "rol": "cliente",
  "token": "jwt_token_cliente"
}
🟢 Editar Mi Perfil (Cliente)
Permite al cliente logueado actualizar sus datos.

Método: PUT

Endpoint: /clientes/9611112222 (El ID es el teléfono)

JSON de Petición (Body):

JSON

{
  "fldNombres": "Juan Carlos",
  "fldApellidos": "Pérez López",
  "fldCorreoElectronico": "juan.perez@mail.com",
  "fldContrasena": "nuevaClave456"
}
(Nota: Si fldContrasena es null o "", no se cambia la contraseña actual).

Respuesta Exitosa: 200 OK (Sin contenido).

4. Módulo de Carrito de Compras (Flujo de Venta)
🟢 Paso 1: Crear Carrito
Inicializa una venta en estado 'pendiente'.

Método: POST

Endpoint: /ventas

JSON de Petición (Body):

JSON

{
  "telefono": "9611112222",
  "id_usuario": 1
}
Respuesta Exitosa (200 OK):

JSON

{
  "idventas": 15
}
(El frontend debe guardar este idventas para los siguientes pasos).

🟢 Paso 2: Ver Carrito
Muestra el contenido actual de la venta.

Método: GET

Endpoint: /ventas/15 (Usando el idventas del paso 1)

Respuesta Exitosa (200 OK):

JSON

[
  {
    "idventas": 15,
    "codigo_producto": 3,
    "Producto": "Sensor Ultrasónico",
    "Marca": "SparkFun",
    "DetalleDescripcion": "Bolsa individual",
    "DetalleUnidades": 50,
    "PrecioUnitario": "85.50",
    "cantidad": 2,
    "subtotal": "171.00"
  }
]
🟢 Paso 3: Agregar Producto
Añade un ítem al carrito. Si ya existe, suma la cantidad.

Método: POST

Endpoint: /ventas/15/productos

JSON de Petición (Body):

JSON

{
  "codigo_producto": 3,
  "cantidad": 2
}
Respuesta Exitosa: 201 Created (Sin contenido).

🟢 Paso 4: Modificar Cantidad
Actualiza cuántas unidades de un producto específico se quieren llevar.

Método: PUT

Endpoint: /ventas/15/productos/3 (Venta 15, Producto 3)

JSON de Petición (Body):

JSON

{
  "nueva_cantidad": 5
}
Respuesta Exitosa: 200 OK (Sin contenido).

🟢 Paso 5: Eliminar Producto
Quita un ítem del carrito.

Método: DELETE

Endpoint: /ventas/15/productos/3

Body: Ninguno.

Respuesta Exitosa: 204 No Content (Sin contenido).

🟢 Paso 6: Finalizar Compra
Cierra la venta, genera el comprobante y descuenta el stock.

Método: POST

Endpoint: /ventas/15/finalizar

JSON de Petición (Body):

JSON

{
  "id_tipo_pago": 1
}
(IDs de Pago: 1=Tarjeta, 2=Efectivo, 3=Transferencia)

Respuesta Exitosa (200 OK):

JSON

{
  "total_pagado": "427.50"
}
🟢 Cancelar Venta
Marca la venta como cancelada.

Método: PUT

Endpoint: /ventas/15/cancelar

Body: Ninguno.

Respuesta Exitosa: 200 OK.

5. Módulo de Soporte
🟢 Obtener Tipos de Consulta
Para llenar el selector en el formulario de contacto.

Método: GET

Endpoint: /tipos-consulta

Respuesta Exitosa (200 OK):

JSON

[
  {
    "id_tipo": 1,
    "fldOpciones": "Producto defectuoso"
  },
  {
    "id_tipo": 2,
    "fldOpciones": "Envío"
  }
]
🟢 Enviar Consulta
Registra el mensaje del cliente.

Método: POST

Endpoint: /consultas

JSON de Petición (Body):

JSON

{
  "telefono": "9611112222",
  "id_tipo": 1,
  "fldAsunto": "Falla de encendido",
  "fldMensaje": "El kit que compré ayer no enciende."
}
Respuesta Exitosa: 201 Created.

6. Panel de Administrador (Gestión)
Endpoints protegidos para usuarios con rol admin.

🟢 Registrar Administrador
Crea un nuevo usuario con permisos de gestión.

Método: POST

Endpoint: /auth/admin/registro

JSON de Petición (Body):

JSON

{
  "fldTelefono": "9998887777",
  "fldNombre": "SuperAdmin",
  "fldCorreoElectronico": "admin@smartpoint.com",
  "fldContrasena": "adminPass"
}
Respuesta Exitosa: 201 Created.

🟢 Login Administrador
Método: POST

Endpoint: /auth/admin/login

JSON de Petición (Body):

JSON

{
  "correo": "admin@smartpoint.com",
  "contrasena": "adminPass"
}
Respuesta Exitosa (200 OK):

JSON

{
  "id": "1",
  "nombre": "SuperAdmin",
  "rol": "admin",
  "token": "jwt_token_admin"
}
🟢 Crear Producto Completo
Crea el producto y sus detalles de inventario en una sola operación.

Método: POST

Endpoint: /admin/productos

JSON de Petición (Body):

JSON

{
    "fldNombre": "Kit Arduino Avanzado",
    "fldPrecio": 1250.00,
    "fldMarca": "Arduino",
    "descripcion": "Incluye placa y 50 sensores",
    "unidades": 20,
    "categorias": [4, 8, 12]
}
Respuesta Exitosa: 201 Created.

🟢 Editar Producto Completo
Actualiza información y stock.

Método: PUT

Endpoint: /admin/productos/1 (ID del producto)

JSON de Petición (Body):

JSON

{
    "fldNombre": "Kit Arduino Avanzado V2",
    "fldPrecio": 1300.00,
    "fldMarca": "Arduino Oficial",
    "descripcion": "Edición especial con case",
    "unidades": 15,
    "categorias": [4, 8]
}
Respuesta Exitosa: 200 OK.

🟢 Eliminar Producto
Borra el producto y todo su historial relacionado de forma segura.

Método: DELETE

Endpoint: /admin/productos/1

Respuesta Exitosa: 204 No Content.

🟢 Listar Usuarios (Admins)
Ve todos los administradores registrados.

Método: GET

Endpoint: /admin/usuarios

Respuesta Exitosa (200 OK):

JSON

[
  {
    "id_usuario": 1,
    "fldNombre": "SuperAdmin",
    "fldCorreoElectronico": "admin@smartpoint.com",
    "fldTelefono": "9998887777"
  }
]
🟢 Editar Usuario (Admin)
Modifica datos de un administrador (o de sí mismo).

Método: PUT

Endpoint: /admin/usuarios/1

JSON de Petición (Body):

JSON

{
  "fldTelefono": "9998887777",
  "fldNombre": "Admin Master",
  "fldCorreoElectronico": "master@smartpoint.com",
  "fldContrasena": "nuevaPass123"
}
(Si fldContrasena es null, no se cambia).

Respuesta Exitosa: 200 OK.

🟢 Eliminar Usuario (Admin)
Método: DELETE

Endpoint: /admin/usuarios/1

Respuesta Exitosa: 204 No Content.

🟢 Listar Clientes (Vista Admin)
Método: GET

Endpoint: /admin/clientes

Respuesta Exitosa (200 OK):

JSON

[
  {
    "telefono": "9611112222",
    "fldNombres": "Juan",
    "fldApellidos": "Pérez",
    "fldCorreoElectronico": "juan@mail.com"
  }
]
🟢 Editar Cliente (Desde Admin)
Permite al admin corregir datos de un cliente.

Método: PUT

Endpoint: /admin/clientes/9611112222

JSON de Petición (Body):

JSON

{
  "fldNombres": "Juan Antonio",
  "fldApellidos": "Pérez",
  "fldCorreoElectronico": "juan.antonio@mail.com",
  "fldContrasena": null
}
Respuesta Exitosa: 200 OK.

🟢 Eliminar Cliente (Admin)
Método: DELETE

Endpoint: /admin/clientes/9611112222

Respuesta Exitosa: 204 No Content.

🟢 Reporte de Ventas
Método: GET

Endpoint: /admin/ventas

Respuesta Exitosa (200 OK):

JSON

[
  {
    "idventas": 10,
    "fecha": "2025-11-20T14:30:00",
    "estado": "pagado",
    "cliente": "Juan Pérez",
    "total": 427.50
  }
]

🟢 Ver Consultas de Soporte (Panel Admin)
Esta API permite al administrador ver todos los mensajes enviados por los clientes desde el formulario de contacto.

Método: GET

URL: https://smartpoint-api.onrender.com/api/admin/consultas

Body: Ninguno.

Respuesta Exitosa (200 OK): Devuelve una lista con el detalle del cliente, el tipo de problema y el mensaje.

JSON

[
    {
        "id_consulta": 1,
        "cliente_nombre": "Juan",
        "cliente_apellido": "Pérez",
        "cliente_email": "juan@example.com",
        "telefono": "9611234567",
        "tipo_consulta": "Producto defectuoso",
        "asunto": "Falla de encendido",
        "mensaje": "El kit que compré ayer no enciende."
    }
]

🟢 Buscador de Productos (Público)
Esta API permite filtrar productos por nombre, marca o descripción.

Método: GET

URL: https://smartpoint-api.onrender.com/api/productos/buscar

Parámetros (Query Params):

Key: q

Value: (Lo que quieras buscar, ej: arduino, led, resistor)

URL Completa de Ejemplo: https://smartpoint-api.onrender.com/api/productos/buscar?q=resistor

Respuesta Exitosa (200 OK): Te devolverá un arreglo con los productos que coincidan.

JSON

[
    {
        "codigo_producto": 1,
        "fldNombre": "Resistor 10k",
        "fldPrecio": "0.50",
        "fldMarca": "Vishay",
        "descripcion": "Bolsa de 100 piezas",
        "unidades": 100,
        "categorias_nombres": "Componentes",
        "categorias_ids": "1"
    }
]
(Si no hay coincidencias, devuelve un arreglo vacío []).

🟢 Eliminar consulta:

Método: DELETE

URL: https://smartpoint-api.onrender.com/api/admin/consultas/1 (Reemplaza 1 con el ID real de la consulta que quieres borrar)

Respuesta Exitosa: 204 No Content (No devuelve nada, pero borra el registro).