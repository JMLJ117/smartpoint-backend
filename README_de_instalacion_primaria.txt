1. Guía de Instalación y Configuración Local
Sigue estos pasos para levantar el entorno de desarrollo en una máquina nueva.

1.1. Prerrequisitos
Necesitarás tener instaladas las siguientes herramientas:

Rust: Instálalo usando rustup desde rustup.rs.

Servidor MySQL: Una instancia de MySQL local (como XAMPP, Docker, o un servicio de MySQL).

SQLx CLI: La herramienta de línea de comandos de sqlx. Es obligatoria.

Bash

cargo install sqlx-cli
1.2. Configuración de la Base de Datos
El proyecto usa sqlx-cli para gestionar la estructura de la base de datos (migraciones).

Crea el archivo .env: En la raíz de este proyecto (smartpoint_api/), crea un archivo llamado .env y añade la URL de conexión a tu base de datos MySQL.

.env:

Fragmento de código

# Reemplaza con tu usuario, contraseña y el nombre de la DB
DATABASE_URL="mysql://root:tu_contraseña@localhost/db_smart_point"
Crea la Base de Datos: sqlx-cli leerá tu .env y creará la base de datos por ti.

Bash

sqlx database create
Crea y Ejecuta la Migración: Las migraciones son la forma en que sqlx construye tus tablas.

a. Crea el archivo de migración (puedes usar el nombre que quieras):

Bash

sqlx migrate add script_inicial_smartpoint
b. Se creará un archivo en la carpeta migrations/. Ábrelo.

c. Pega el script SQL corregido (el Sql de la migración que me diste) dentro de ese archivo. Este script NO debe contener DELIMITER y debe usar ; al final de cada END.

d. Ejecuta la migración para crear todas tus tablas, procedimientos y triggers:

Bash

sqlx migrate run
Si todo sale bien, tu base de datos estará poblada y lista.

1.3. Verificación y Ejecución
Verificación de sqlx (Paso Crucial): Este comando compila tu código Rust y se conecta a tu base de datos para verificar que todas tus consultas SQL (query_as!, query!) sean 100% correctas.

Bash

cargo sqlx prepare
Ejecutar el Servidor: Si sqlx prepare tuvo éxito, puedes iniciar el servidor:

Bash

cargo run
El servidor estará disponible en http://localhost:3000.

2. Documentación de la API (Endpoints)
Tu frontend de Angular consumirá los siguientes endpoints:

Productos y Categorías
GET /api/productos

Respuesta: 200 OK

Body: [Producto] (Una lista de todos los productos con sus detalles).

GET /api/productos/:id

Parámetro: id (El codigo_producto del producto).

Respuesta: 200 OK o 404 Not Found

Body: Producto (Un objeto JSON con los detalles del producto).

Llama a: sp_obtener_producto_por_id

GET /api/categorias

Respuesta: 200 OK

Body: [Categoria] (Una lista de todas las categorías visibles).

GET /api/categorias/:id/productos

Parámetro: id (El id_categorias de la categoría).

Respuesta: 200 OK

Body: [ProductoCategoria] (Una lista de productos filtrados por esa categoría).

Llama a: sp_listar_productos_por_categoria

Clientes y Consultas
POST /api/clientes

Body (JSON): NuevoCliente

JSON

{
    "telefono": "9611234567",
    "fldNombres": "Nombre",
    "fldApellidos": "Apellido",
    "fldCorreoElectronico": "correo@ejemplo.com"
}
Respuesta: 201 Created

Llama a: sp_registrar_cliente

POST /api/consultas

Body (JSON): NuevaConsulta

JSON

{
    "telefono": "9611234567",
    "id_tipo": 1,
    "fldAsunto": "Duda sobre producto",
    "fldMensaje": "Mi producto no funciona como esperaba."
}
Respuesta: 201 Created

Llama a: sp_registrar_consulta

3. Explicación del Funcionamiento Interno
src/main.rs
Este es el cerebro de la aplicación.

Struct AppState: Un struct que contiene el MySqlPool (pool de conexiones). Se clona y se "inyecta" en cada handler de ruta que lo necesita.

Structs de Datos (Producto, Categoria, etc.): Definen la forma de los datos.

#[derive(Serialize)]: Permite que axum::Json los convierta a JSON para la respuesta.

#[derive(Deserialize)]: Permite que axum::Json convierta un JSON entrante (de un POST) en el struct.

#[derive(FromRow)]: Permite a sqlx mapear una fila de la base de datos a un struct.

#[allow(non_snake_case)]: Silencia las advertencias de Rust por usar nombres de MySQL como fldNombre.

Función main:

Carga el .env.

Crea el MySqlPoolOptions y se conecta a la DB.

Crea el AppState con el pool.

Define el Router de Axum, asignando rutas (ej. /api/products/:id) a handlers (ej. get_product_by_id).

Inicia el servidor con axum::serve.

Handlers (ej. get_product_by_id)

Son funciones async que toman parámetros (ej. State<AppState>, Path(id)).

Usan sqlx::query_as! (con !) para ejecutar SQL puro que se verifica en tiempo de compilación.

Usan sqlx::query! (con !) para llamar a CALL de procedimientos almacenados.

Devuelven un Result<Json<...>, AppError>.

Manejo de Errores (AppError)

Un struct simple que convierte errores (como sqlx::Error::RowNotFound) en respuestas HTTP apropiadas (como StatusCode::NOT_FOUND).