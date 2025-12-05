# ---------------------------------------------------
# ETAPA 1: Constructor (Builder)
# ---------------------------------------------------
FROM rust:1.75-slim-bookworm as builder

WORKDIR /usr/src/app

# 1. Instalar dependencias de sistema necesarias para compilar crates que usan SSL
# pkg-config y libssl-dev son OBLIGATORIOS para compilar con soporte de red/base de datos
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# 2. Copiar los archivos del proyecto
COPY . .

# 3. Configurar SQLx para modo OFFLINE
# Esto le dice a Rust: "No intentes conectarte a la DB real, usa el archivo sqlx-data.json"
# Así evitamos instalar sqlx-cli y errores de conexión durante el build.
ENV SQLX_OFFLINE=true

# 4. Compilar el proyecto en modo release
RUN cargo build --release

# ---------------------------------------------------
# ETAPA 2: Ejecución (Runner - Imagen final ligera)
# ---------------------------------------------------
FROM debian:bookworm-slim

# 5. Instalar certificados y OpenSSL para la conexión segura a Aiven
# ca-certificates: Permite verificar que Aiven es seguro.
# openssl: Necesario para la encriptación de la conexión.
RUN apt-get update && apt-get install -y \
    ca-certificates \
    openssl \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# 6. Copiar el binario compilado desde la etapa anterior
COPY --from=builder /usr/src/app/target/release/smartpoint_api /usr/local/bin/smartpoint_api

# 7. (Opcional) Exponer el puerto que usará (Render lo ignora, pero es buena práctica)
EXPOSE 3000

# 8. Comando de inicio
CMD ["smartpoint_api"]