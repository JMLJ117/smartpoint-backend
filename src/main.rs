/*
==========================================================
    API REST SmartPoint v7
    - Seguridad: Argon2
    - Roles: Cliente y Administrador
==========================================================
*/

use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::{IntoResponse, Response},
    routing::{get, post, put, delete},
    Json,
    Router,
};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use sqlx::mysql::MySqlPoolOptions;
use sqlx::{FromRow, MySqlPool};
use tower_http::cors::{Any, CorsLayer};
use argon2::{
    password_hash::{rand_core::OsRng, PasswordHash, PasswordHasher, PasswordVerifier, SaltString},
    Argon2
};

#[derive(Clone)]
struct AppState { db: MySqlPool }

// --- STRUCTS ---
#[allow(non_snake_case)]
#[derive(Serialize, FromRow)]
struct Producto {
    codigo_producto: Option<i32>,
    fldNombre: Option<String>,
    fldPrecio: Option<Decimal>,
    fldMarca: Option<String>,
    descripcion: Option<String>,
    unidades: Option<i32>,
    categorias_nombres: Option<String>,
    categorias_ids: Option<String>,
}

#[allow(non_snake_case)]
#[derive(Deserialize)]
struct ProductoAdminPayload {
    fldNombre: String,
    fldPrecio: Decimal,
    fldMarca: String,
    descripcion: String,
    unidades: i32,
    categorias: Option<Vec<i32>>,
}

#[allow(non_snake_case)]
#[derive(Serialize, FromRow)]
struct Categoria {
    id_categorias: i32,
    fldNombre: String,
    fldDescripcion: String,
}

#[allow(non_snake_case)]
#[derive(Serialize, FromRow)]
struct ProductoCategoria {
    Categoria: String,
    codigo_producto: i32,
    Producto: String,
    fldPrecio: Decimal,
    fldMarca: Option<String>,
}

#[allow(non_snake_case)]
#[derive(Deserialize)]
struct RegistroCliente {
    telefono: String,
    fldNombres: String,
    fldApellidos: String,
    fldCorreoElectronico: String,
    fldContrasena: String,
}

#[allow(non_snake_case)]
#[derive(Serialize, FromRow)]
struct ClienteInfo {
    telefono: String,
    fldNombres: String,
    fldApellidos: String,
    fldCorreoElectronico: Option<String>,
}

#[allow(non_snake_case)]
#[derive(Deserialize)]
struct EditarClientePayload {
    fldNombres: String,
    fldApellidos: String,
    fldCorreoElectronico: String,
    fldContrasena: Option<String>,
}

#[allow(non_snake_case)]
#[derive(Deserialize)]
struct RegistroAdmin {
    fldTelefono: String,
    fldNombre: String,
    fldCorreoElectronico: String,
    fldContrasena: String,
}

#[allow(non_snake_case)]
#[derive(Serialize, FromRow)]
struct UsuarioAdminInfo {
    id_usuario: i32,
    fldNombre: String,
    fldCorreoElectronico: String,
    fldTelefono: String,
}

#[allow(non_snake_case)]
#[derive(Deserialize)]
struct EditarUsuarioPayload {
    fldTelefono: String,
    fldNombre: String,
    fldCorreoElectronico: String,
    fldContrasena: Option<String>,
}

#[allow(non_snake_case)]
#[derive(Deserialize)]
struct LoginRequest {
    correo: String,
    contrasena: String,
}

#[derive(Serialize)]
struct LoginResponse {
    id: String,
    nombre: String,
    rol: String,
    token: String,
}

#[allow(non_snake_case)]
#[derive(FromRow)]
struct CredencialDB {
    id: Option<String>,
    nombre: String,
    hash_contrasena: Option<String>,
}

#[allow(non_snake_case)]
#[derive(Deserialize)]
struct NuevaConsulta {
    telefono: String,
    id_tipo: i32,
    fldAsunto: String,
    fldMensaje: String,
}

#[allow(non_snake_case)]
#[derive(Serialize, FromRow)]
struct TipoConsulta {
    id_tipo: i32,
    fldOpciones: String,
}

#[allow(non_snake_case)]
#[derive(Deserialize)]
struct NuevaVenta {
    telefono: String,
    id_usuario: i32,
}

#[derive(Serialize, FromRow)]
struct VentaCreada { idventas: u64 }

#[allow(non_snake_case)]
#[derive(Serialize, FromRow)]
struct DetalleCarrito {
    idventas: i32,
    codigo_producto: i32,
    Producto: String,
    Marca: Option<String>,
    DetalleDescripcion: Option<String>,
    DetalleUnidades: Option<i32>,
    PrecioUnitario: Decimal,
    cantidad: i32,
    subtotal: Decimal,
}

#[derive(Deserialize)]
struct AgregarItem { codigo_producto: i32, cantidad: i32 }
#[derive(Deserialize)]
struct ActualizarItem { nueva_cantidad: i32 }
#[derive(Deserialize)]
struct FinalizarVenta { id_tipo_pago: i32 }
#[derive(Serialize, FromRow)]
struct TotalVenta { total_pagado: Option<Decimal> }

#[allow(non_snake_case)]
#[derive(Serialize, FromRow)]
struct VentaReporte {
    idventas: Option<i32>,
    fecha: Option<chrono::NaiveDateTime>,
    estado: Option<String>,
    cliente: Option<String>,
    total: Option<Decimal>,
}

// ==========================================
//                  MAIN
// ==========================================

#[tokio::main]
async fn main() {
    dotenvy::dotenv().ok();
    let database_url = std::env::var("DATABASE_URL").expect("DATABASE_URL no configurada");

    let pool = MySqlPoolOptions::new()
        .max_connections(10)
        .connect(&database_url)
        .await
        .expect("Error conectando a MySQL");

    println!("✅ Base de datos conectada.");

    let app_state = AppState { db: pool };
    let cors = CorsLayer::new().allow_origin(Any).allow_methods(Any).allow_headers(Any);

    let app = Router::new()
        // Productos
        .route("/api/productos", get(get_all_products))
        .route("/api/productos/:id", get(get_product_by_id))
        .route("/api/categorias", get(get_all_categories))
        .route("/api/categorias/:id/productos", get(get_products_by_category))

        // Auth
        .route("/api/auth/cliente/registro", post(register_client))
        .route("/api/auth/cliente/login", post(login_client))
        .route("/api/auth/admin/registro", post(register_admin))
        .route("/api/auth/admin/login", post(login_admin))

        // Carrito
        .route("/api/ventas", post(create_sale))
        .route("/api/ventas/:id", get(get_cart))
        .route("/api/ventas/:id/productos", post(add_to_cart))
        .route("/api/ventas/:id/productos/:prod_id", put(update_cart_item).delete(remove_from_cart))
        .route("/api/ventas/:id/finalizar", post(finalize_sale))
        .route("/api/ventas/:id/cancelar", put(cancel_sale))

        // Contacto
        .route("/api/tipos-consulta", get(get_tipos_consulta))
        .route("/api/consultas", post(register_consulta))

        // Admin Panel
        .route("/api/admin/productos", post(admin_create_product))
        .route("/api/admin/productos/:id", put(admin_update_product).delete(admin_delete_product))
        .route("/api/admin/usuarios", get(admin_list_users))
        .route("/api/admin/usuarios/:id", put(admin_update_user).delete(admin_delete_user))
        .route("/api/admin/clientes", get(admin_list_clients))
        .route("/api/admin/clientes/:id", put(admin_update_client).delete(admin_delete_client))
        .route("/api/clientes/:id", put(update_client))
        .route("/api/admin/ventas", get(admin_list_sales))

        .layer(cors)
        .with_state(app_state);

    // --- CAMBIO PARA RENDER: Leer puerto dinámico ---
    let port = std::env::var("PORT").unwrap_or_else(|_| "3000".to_string());
    let address = format!("0.0.0.0:{}", port);

    let listener = tokio::net::TcpListener::bind(&address).await.unwrap();
    println!("🚀 Servidor corriendo en {}", address);
    axum::serve(listener, app).await.unwrap();
}

fn hash_password(password: &str) -> Result<String, AppError> {
    let salt = SaltString::generate(&mut OsRng);
    let argon2 = Argon2::default();
    Ok(argon2.hash_password(password.as_bytes(), &salt)
        .map_err(|_| AppError(StatusCode::INTERNAL_SERVER_ERROR, "Error hash".into()))?
        .to_string())
}

fn verify_password(password: &str, hash: &str) -> bool {
    let parsed_hash = match PasswordHash::new(hash) {
        Ok(h) => h,
        Err(_) => return false,
    };
    Argon2::default().verify_password(password.as_bytes(), &parsed_hash).is_ok()
}

// --- HANDLERS ---

async fn get_all_products(State(state): State<AppState>) -> Result<Json<Vec<Producto>>, AppError> {
    let productos = sqlx::query_as!(Producto,
        r#"SELECT p.codigo_producto, p.fldNombre, p.fldPrecio, p.fldMarca, dp.descripcion, dp.unidades,
           (SELECT GROUP_CONCAT(c.fldNombre SEPARATOR ', ') FROM categorias_x_productos cxp JOIN categorias c ON cxp.id_categorias = c.id_categorias WHERE cxp.codigo_producto = p.codigo_producto) as categorias_nombres,
           (SELECT GROUP_CONCAT(cxp.id_categorias SEPARATOR ',') FROM categorias_x_productos cxp WHERE cxp.codigo_producto = p.codigo_producto) as categorias_ids
           FROM productos p JOIN detalle_productos dp ON p.id_detalle_producto = dp.id_detalle_producto"#
    ).fetch_all(&state.db).await?;
    Ok(Json(productos))
}

async fn get_product_by_id(State(state): State<AppState>, Path(id): Path<i32>) -> Result<Json<Producto>, AppError> {
    let p = sqlx::query_as!(Producto,
        r#"SELECT p.codigo_producto, p.fldNombre, p.fldPrecio, p.fldMarca, dp.descripcion, dp.unidades,
           (SELECT GROUP_CONCAT(c.fldNombre SEPARATOR ', ') FROM categorias_x_productos cxp JOIN categorias c ON cxp.id_categorias = c.id_categorias WHERE cxp.codigo_producto = p.codigo_producto) as categorias_nombres,
           (SELECT GROUP_CONCAT(cxp.id_categorias SEPARATOR ',') FROM categorias_x_productos cxp WHERE cxp.codigo_producto = p.codigo_producto) as categorias_ids
           FROM productos p JOIN detalle_productos dp ON p.id_detalle_producto = dp.id_detalle_producto WHERE p.codigo_producto = ?"#, id
    ).fetch_one(&state.db).await?;
    Ok(Json(p))
}

async fn get_all_categories(State(state): State<AppState>) -> Result<Json<Vec<Categoria>>, AppError> {
    let c = sqlx::query_as!(Categoria, "SELECT id_categorias, fldNombre, fldDescripcion FROM categorias WHERE visible = 1").fetch_all(&state.db).await?;
    Ok(Json(c))
}

async fn get_products_by_category(State(state): State<AppState>, Path(id): Path<i32>) -> Result<Json<Vec<ProductoCategoria>>, AppError> {
    let productos = sqlx::query_as!(ProductoCategoria, r#"SELECT c.fldNombre AS Categoria, p.codigo_producto, p.fldNombre AS Producto, p.fldPrecio, p.fldMarca FROM categorias c INNER JOIN categorias_x_productos cp ON c.id_categorias = cp.id_categorias INNER JOIN productos p ON cp.codigo_producto = p.codigo_producto WHERE c.id_categorias = ? AND c.visible = 1 ORDER BY p.fldNombre"#, id).fetch_all(&state.db).await?;
    Ok(Json(productos))
}

async fn register_client(State(state): State<AppState>, Json(payload): Json<RegistroCliente>) -> Result<StatusCode, AppError> {
    let hash = hash_password(&payload.fldContrasena)?;
    sqlx::query!("INSERT INTO cliente (telefono, fldNombres, fldApellidos, fldCorreoElectronico, fldContrasena) VALUES (?, ?, ?, ?, ?)", payload.telefono, payload.fldNombres, payload.fldApellidos, payload.fldCorreoElectronico, hash).execute(&state.db).await?;
    Ok(StatusCode::CREATED)
}

async fn login_client(State(state): State<AppState>, Json(payload): Json<LoginRequest>) -> Result<Json<LoginResponse>, AppError> {
    let user = sqlx::query_as!(CredencialDB, "SELECT telefono as id, fldNombres as nombre, fldContrasena as hash_contrasena FROM cliente WHERE fldCorreoElectronico = ?", payload.correo).fetch_optional(&state.db).await?;
    if let Some(u) = user {
        if let Some(h) = u.hash_contrasena {
            if verify_password(&payload.contrasena, &h) {
                return Ok(Json(LoginResponse { id: u.id.unwrap_or_default(), nombre: u.nombre, rol: "cliente".into(), token: "jwt_token".into() }));
            }
        }
    }
    Err(AppError(StatusCode::UNAUTHORIZED, "Credenciales inválidas".into()))
}

async fn update_client(State(state): State<AppState>, Path(id): Path<String>, Json(payload): Json<EditarClientePayload>) -> Result<StatusCode, AppError> {
    let hash = match payload.fldContrasena {
        Some(ref p) if !p.is_empty() => Some(hash_password(p)?),
        _ => None,
    };
    sqlx::query!("CALL sp_editar_cliente(?, ?, ?, ?, ?)", id, payload.fldNombres, payload.fldApellidos, payload.fldCorreoElectronico, hash).execute(&state.db).await?;
    Ok(StatusCode::OK)
}

async fn register_admin(State(state): State<AppState>, Json(payload): Json<RegistroAdmin>) -> Result<StatusCode, AppError> {
    let hash = hash_password(&payload.fldContrasena)?;
    sqlx::query!("INSERT INTO usuario (fldTelefono, fldNombre, fldCorreoElectronico, fldContrasena) VALUES (?, ?, ?, ?)", payload.fldTelefono, payload.fldNombre, payload.fldCorreoElectronico, hash).execute(&state.db).await?;
    Ok(StatusCode::CREATED)
}

async fn login_admin(State(state): State<AppState>, Json(payload): Json<LoginRequest>) -> Result<Json<LoginResponse>, AppError> {
    let user = sqlx::query_as!(CredencialDB, "SELECT CAST(id_usuario AS CHAR) as id, fldNombre as nombre, fldContrasena as hash_contrasena FROM usuario WHERE fldCorreoElectronico = ?", payload.correo).fetch_optional(&state.db).await?;
    if let Some(u) = user {
        if let Some(h) = u.hash_contrasena {
            if verify_password(&payload.contrasena, &h) {
                return Ok(Json(LoginResponse { id: u.id.unwrap_or_default(), nombre: u.nombre, rol: "admin".into(), token: "jwt_token".into() }));
            }
        }
    }
    Err(AppError(StatusCode::UNAUTHORIZED, "Credenciales inválidas".into()))
}

// --- ADMIN PRODUCTOS ---
async fn admin_create_product(State(state): State<AppState>, Json(payload): Json<ProductoAdminPayload>) -> Result<StatusCode, AppError> {
    let cats_json = serde_json::to_string(&payload.categorias).unwrap_or("[]".to_string());

    sqlx::query!("CALL sp_crear_producto_admin(?, ?, ?, ?, ?, ?)",
        payload.fldNombre, payload.fldPrecio, payload.fldMarca, payload.descripcion, payload.unidades, cats_json
    ).execute(&state.db).await?;
    Ok(StatusCode::CREATED)
}

async fn admin_update_product(State(state): State<AppState>, Path(id): Path<i32>, Json(payload): Json<ProductoAdminPayload>) -> Result<StatusCode, AppError> {
    let cats_json = serde_json::to_string(&payload.categorias).unwrap_or("[]".to_string());

    sqlx::query!("CALL sp_actualizar_producto_admin(?, ?, ?, ?, ?, ?, ?)",
        id, payload.fldNombre, payload.fldPrecio, payload.fldMarca, payload.descripcion, payload.unidades, cats_json
    ).execute(&state.db).await?;
    Ok(StatusCode::OK)
}

async fn admin_delete_product(State(state): State<AppState>, Path(id): Path<i32>) -> Result<StatusCode, AppError> {
    sqlx::query!("CALL sp_eliminar_producto_admin(?)", id).execute(&state.db).await?;
    Ok(StatusCode::NO_CONTENT)
}

// --- ADMIN USUARIOS Y CLIENTES ---
async fn admin_list_users(State(state): State<AppState>) -> Result<Json<Vec<UsuarioAdminInfo>>, AppError> {
    let users = sqlx::query_as!(UsuarioAdminInfo, "SELECT id_usuario, fldNombre, fldCorreoElectronico, fldTelefono FROM usuario").fetch_all(&state.db).await?;
    Ok(Json(users))
}

async fn admin_update_user(State(state): State<AppState>, Path(id): Path<i32>, Json(payload): Json<EditarUsuarioPayload>) -> Result<StatusCode, AppError> {
    let hash = match payload.fldContrasena {
        Some(ref p) if !p.is_empty() => Some(hash_password(p)?),
        _ => None,
    };
    sqlx::query!("CALL sp_editar_usuario(?, ?, ?, ?, ?)", id, payload.fldTelefono, payload.fldNombre, payload.fldCorreoElectronico, hash).execute(&state.db).await?;
    Ok(StatusCode::OK)
}

async fn admin_delete_user(State(state): State<AppState>, Path(id): Path<i32>) -> Result<StatusCode, AppError> {
    sqlx::query!("CALL sp_eliminar_usuario(?)", id).execute(&state.db).await?;
    Ok(StatusCode::NO_CONTENT)
}

async fn admin_list_clients(State(state): State<AppState>) -> Result<Json<Vec<ClienteInfo>>, AppError> {
    let clients = sqlx::query_as!(
        ClienteInfo,
        "SELECT telefono, fldNombres, fldApellidos, fldCorreoElectronico FROM cliente ORDER BY fldNombres"
    ).fetch_all(&state.db).await?;
    Ok(Json(clients))
}

async fn admin_update_client(State(state): State<AppState>, Path(id): Path<String>, Json(payload): Json<EditarClientePayload>) -> Result<StatusCode, AppError> {
    let hash = match payload.fldContrasena {
        Some(ref p) if !p.is_empty() => Some(hash_password(p)?),
        _ => None,
    };
    sqlx::query!("CALL sp_editar_cliente(?, ?, ?, ?, ?)", id, payload.fldNombres, payload.fldApellidos, payload.fldCorreoElectronico, hash).execute(&state.db).await?;
    Ok(StatusCode::OK)
}

async fn admin_delete_client(State(state): State<AppState>, Path(id): Path<String>) -> Result<StatusCode, AppError> {
    sqlx::query!("CALL sp_eliminar_cliente(?)", id).execute(&state.db).await?;
    Ok(StatusCode::NO_CONTENT)
}

async fn admin_list_sales(State(state): State<AppState>) -> Result<Json<Vec<VentaReporte>>, AppError> {
    let ventas = sqlx::query_as!(VentaReporte, r#"SELECT v.idventas, v.fldFecha as fecha, v.estado, c.fldNombres as cliente, (SELECT COALESCE(SUM(subtotal), 0) FROM detalle_ventas WHERE idventas = v.idventas) as total FROM ventas v INNER JOIN cliente c ON v.telefono = c.telefono ORDER BY v.fldFecha DESC"#).fetch_all(&state.db).await?;
    Ok(Json(ventas))
}

// --- OTROS ---
async fn get_tipos_consulta(State(state): State<AppState>) -> Result<Json<Vec<TipoConsulta>>, AppError> {
    let tipos = sqlx::query_as!(TipoConsulta, "SELECT id_tipo, fldOpciones FROM tipo_consulta").fetch_all(&state.db).await?;
    Ok(Json(tipos))
}

async fn register_consulta(State(state): State<AppState>, Json(payload): Json<NuevaConsulta>) -> Result<StatusCode, AppError> {
    sqlx::query!("CALL sp_registrar_consulta(?, ?, ?, ?)", payload.telefono, payload.id_tipo, payload.fldAsunto, payload.fldMensaje).execute(&state.db).await?;
    Ok(StatusCode::CREATED)
}

async fn create_sale(State(state): State<AppState>, Json(payload): Json<NuevaVenta>) -> Result<Json<VentaCreada>, AppError> {
    let mut tx = state.db.begin().await?;
    sqlx::query!("INSERT INTO ventas (fldFecha, telefono, id_usuario, estado) VALUES (NOW(), ?, ?, 'pendiente')", payload.telefono, payload.id_usuario).execute(&mut *tx).await?;
    let v = sqlx::query_as!(VentaCreada, "SELECT LAST_INSERT_ID() as idventas").fetch_one(&mut *tx).await?;
    tx.commit().await?;
    Ok(Json(v))
}

async fn get_cart(State(state): State<AppState>, Path(id): Path<i32>) -> Result<Json<Vec<DetalleCarrito>>, AppError> {
    let items = sqlx::query_as!(DetalleCarrito, r#"SELECT dv.idventas, dv.codigo_producto, p.fldNombre AS Producto, p.fldMarca AS Marca, dp.descripcion AS DetalleDescripcion, dp.unidades AS DetalleUnidades, p.fldPrecio AS PrecioUnitario, dv.cantidad, dv.subtotal FROM detalle_ventas dv INNER JOIN productos p ON dv.codigo_producto = p.codigo_producto INNER JOIN detalle_productos dp ON p.id_detalle_producto = dp.id_detalle_producto WHERE dv.idventas = ? ORDER BY p.fldNombre"#, id).fetch_all(&state.db).await?;
    Ok(Json(items))
}

async fn add_to_cart(State(state): State<AppState>, Path(id): Path<i32>, Json(payload): Json<AgregarItem>) -> Result<StatusCode, AppError> {
    sqlx::query!("CALL sp_agregar_producto_carrito(?, ?, ?)", id, payload.codigo_producto, payload.cantidad).execute(&state.db).await?;
    Ok(StatusCode::CREATED)
}

async fn update_cart_item(State(state): State<AppState>, Path((id, prod_id)): Path<(i32, i32)>, Json(payload): Json<ActualizarItem>) -> Result<StatusCode, AppError> {
    sqlx::query!("CALL sp_actualizar_producto_carrito(?, ?, ?)", id, prod_id, payload.nueva_cantidad).execute(&state.db).await?;
    Ok(StatusCode::OK)
}

async fn remove_from_cart(State(state): State<AppState>, Path((id, prod_id)): Path<(i32, i32)>) -> Result<StatusCode, AppError> {
    sqlx::query!("CALL sp_eliminar_producto_carrito(?, ?)", id, prod_id).execute(&state.db).await?;
    Ok(StatusCode::NO_CONTENT)
}

async fn finalize_sale(State(state): State<AppState>, Path(id): Path<i32>, Json(payload): Json<FinalizarVenta>) -> Result<Json<TotalVenta>, AppError> {
    let mut tx = state.db.begin().await?;
    sqlx::query!("INSERT INTO comprobante (id_tipo_pago, idventas) VALUES (?, ?)", payload.id_tipo_pago, id).execute(&mut *tx).await?;
    let t = sqlx::query_as!(TotalVenta, "SELECT SUM(subtotal) AS total_pagado FROM detalle_ventas WHERE idventas = ?", id).fetch_one(&mut *tx).await?;
    tx.commit().await?;
    Ok(Json(t))
}

async fn cancel_sale(State(state): State<AppState>, Path(id): Path<i32>) -> Result<StatusCode, AppError> {
    sqlx::query!("CALL sp_cancelar_venta(?)", id).execute(&state.db).await?;
    Ok(StatusCode::OK)
}

struct AppError(StatusCode, String);
impl IntoResponse for AppError { fn into_response(self) -> Response { (self.0, self.1).into_response() } }
impl From<sqlx::Error> for AppError {
    fn from(err: sqlx::Error) -> Self {
        eprintln!("DB Error: {:?}", err);
        match err {
            sqlx::Error::RowNotFound => AppError(StatusCode::NOT_FOUND, "No encontrado".into()),
            sqlx::Error::Database(e) => {
                if e.code().as_deref() == Some("1062") { return AppError(StatusCode::CONFLICT, "Ya existe".into()); }
                if e.code().as_deref() == Some("45000") { return AppError(StatusCode::BAD_REQUEST, e.message().into()); }
                AppError(StatusCode::INTERNAL_SERVER_ERROR, "Error interno".into())
            },
            _ => AppError(StatusCode::INTERNAL_SERVER_ERROR, "Error interno".into()),
        }
    }
}
