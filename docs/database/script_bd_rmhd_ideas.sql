-- =====================================================================
-- Script de generación de la base de datos — Plataforma RMHD Ideas
-- Motor: PostgreSQL 14+
-- Componente 4 del Manual Técnico (corresponde al modelo relacional
-- del Componente 3 — ver docs/diagrams/03_modelo_relacional)
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Usuarios (artesana administradora y clientes)
-- ---------------------------------------------------------------------
CREATE TABLE usuario (
    id_usuario       SERIAL PRIMARY KEY,
    nombre           VARCHAR(120) NOT NULL,
    email            VARCHAR(160) NOT NULL UNIQUE,
    password_hash    VARCHAR(255) NOT NULL,
    rol              VARCHAR(20)  NOT NULL CHECK (rol IN ('artesana', 'cliente')),
    telefono         VARCHAR(20),
    fecha_registro   TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------
-- 2. Catálogo: categorías, productos y materiales
-- ---------------------------------------------------------------------
CREATE TABLE categoria_producto (
    id_categoria              SERIAL PRIMARY KEY,
    nombre                    VARCHAR(80) NOT NULL,
    tiempo_estimado_min_dias  INTEGER,
    tiempo_estimado_max_dias  INTEGER
);

CREATE TABLE producto (
    id_producto      SERIAL PRIMARY KEY,
    id_categoria     INTEGER NOT NULL REFERENCES categoria_producto(id_categoria),
    nombre           VARCHAR(150) NOT NULL,
    descripcion      TEXT,
    precio           NUMERIC(12,2) NOT NULL CHECK (precio >= 0),
    disponibilidad   VARCHAR(20) NOT NULL DEFAULT 'bajo_pedido'
                     CHECK (disponibilidad IN ('bajo_pedido', 'stock_limitado')),
    destacado        BOOLEAN NOT NULL DEFAULT FALSE,
    no_recomendar    BOOLEAN NOT NULL DEFAULT FALSE,
    imagen_url       VARCHAR(255),
    activo           BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE material (
    id_material      SERIAL PRIMARY KEY,
    nombre           VARCHAR(100) NOT NULL,
    unidad_medida    VARCHAR(20),
    stock_actual     NUMERIC(12,2) DEFAULT 0
);

CREATE TABLE producto_material (
    id_producto          INTEGER NOT NULL REFERENCES producto(id_producto) ON DELETE CASCADE,
    id_material          INTEGER NOT NULL REFERENCES material(id_material) ON DELETE CASCADE,
    cantidad_requerida   NUMERIC(12,2) NOT NULL DEFAULT 0,
    PRIMARY KEY (id_producto, id_material)
);

-- ---------------------------------------------------------------------
-- 3. Capacidad de producción (RF-12)
-- ---------------------------------------------------------------------
CREATE TABLE capacidad_produccion (
    id_capacidad             SERIAL PRIMARY KEY,
    max_ordenes_simultaneas  INTEGER NOT NULL,
    max_ordenes_semana       INTEGER NOT NULL,
    vigente_desde            DATE NOT NULL DEFAULT CURRENT_DATE
);

-- ---------------------------------------------------------------------
-- 4. Pedidos, detalle y pagos
-- ---------------------------------------------------------------------
CREATE TABLE pedido (
    id_pedido        SERIAL PRIMARY KEY,
    id_cliente       INTEGER NOT NULL REFERENCES usuario(id_usuario),
    fecha_pedido     TIMESTAMP NOT NULL DEFAULT NOW(),
    tipo_pedido      VARCHAR(20) NOT NULL CHECK (tipo_pedido IN ('stock', 'pre_orden')),
    estado_pago      VARCHAR(20) NOT NULL DEFAULT 'pendiente'
                     CHECK (estado_pago IN ('pendiente', 'pagado', 'cancelado')),
    total            NUMERIC(12,2) DEFAULT 0
);

CREATE TABLE detalle_pedido (
    id_detalle_pedido   SERIAL PRIMARY KEY,
    id_pedido           INTEGER NOT NULL REFERENCES pedido(id_pedido) ON DELETE CASCADE,
    id_producto         INTEGER NOT NULL REFERENCES producto(id_producto),
    cantidad            INTEGER NOT NULL CHECK (cantidad > 0),
    precio_unitario     NUMERIC(12,2) NOT NULL
);

CREATE TABLE pago (
    id_pago                 SERIAL PRIMARY KEY,
    id_pedido               INTEGER NOT NULL REFERENCES pedido(id_pedido) ON DELETE CASCADE,
    pasarela                VARCHAR(30) CHECK (pasarela IN ('wompi', 'pse')),
    referencia_transaccion  VARCHAR(100),
    estado                  VARCHAR(20) NOT NULL DEFAULT 'pendiente',
    monto                   NUMERIC(12,2),
    fecha_pago              TIMESTAMP
);

-- ---------------------------------------------------------------------
-- 5. Gestión de producción (núcleo del sistema)
-- ---------------------------------------------------------------------
CREATE TABLE orden_produccion (
    id_orden_produccion     SERIAL PRIMARY KEY,
    id_detalle_pedido       INTEGER NOT NULL UNIQUE
                            REFERENCES detalle_pedido(id_detalle_pedido) ON DELETE CASCADE,
    estado                  VARCHAR(20) NOT NULL DEFAULT 'en_cola'
                            CHECK (estado IN ('en_cola', 'en_proceso', 'en_acabados',
                                               'terminado', 'entregado')),
    fecha_inicio             TIMESTAMP NOT NULL DEFAULT NOW(),
    fecha_estimada_entrega   DATE NOT NULL,
    fecha_real_entrega       DATE,
    prioridad_manual         INTEGER DEFAULT 0,
    notas                    TEXT
);

CREATE TABLE historial_estado_orden (
    id_historial            SERIAL PRIMARY KEY,
    id_orden_produccion     INTEGER NOT NULL REFERENCES orden_produccion(id_orden_produccion) ON DELETE CASCADE,
    id_usuario              INTEGER NOT NULL REFERENCES usuario(id_usuario),
    estado_anterior         VARCHAR(20),
    estado_nuevo            VARCHAR(20) NOT NULL,
    fecha_cambio            TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE consumo_material_orden (
    id_orden_produccion     INTEGER NOT NULL REFERENCES orden_produccion(id_orden_produccion) ON DELETE CASCADE,
    id_material             INTEGER NOT NULL REFERENCES material(id_material),
    cantidad_consumida      NUMERIC(12,2) NOT NULL DEFAULT 0,
    PRIMARY KEY (id_orden_produccion, id_material)
);

-- ---------------------------------------------------------------------
-- 6. Recomendación (interacciones de cliente)
-- ---------------------------------------------------------------------
CREATE TABLE interaccion_cliente (
    id_interaccion       SERIAL PRIMARY KEY,
    id_cliente           INTEGER NOT NULL REFERENCES usuario(id_usuario),
    id_producto          INTEGER NOT NULL REFERENCES producto(id_producto),
    tipo_interaccion     VARCHAR(20) NOT NULL CHECK (tipo_interaccion IN ('vista', 'carrito', 'compra')),
    fecha                TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------
-- 7. Predicción de demanda y alertas proactivas
-- ---------------------------------------------------------------------
CREATE TABLE prediccion_demanda (
    id_prediccion        SERIAL PRIMARY KEY,
    id_categoria         INTEGER NOT NULL REFERENCES categoria_producto(id_categoria),
    fecha_generacion     TIMESTAMP NOT NULL DEFAULT NOW(),
    fecha_proyeccion     DATE NOT NULL,
    valor_proyectado     NUMERIC(12,2)
);

CREATE TABLE alerta_produccion (
    id_alerta            SERIAL PRIMARY KEY,
    id_prediccion        INTEGER NOT NULL REFERENCES prediccion_demanda(id_prediccion) ON DELETE CASCADE,
    fecha_alerta         TIMESTAMP NOT NULL DEFAULT NOW(),
    mensaje              TEXT,
    enviada              BOOLEAN NOT NULL DEFAULT FALSE
);

-- ---------------------------------------------------------------------
-- 8. Automatización de comunicaciones
-- ---------------------------------------------------------------------
CREATE TABLE plantilla_mensaje (
    id_plantilla     SERIAL PRIMARY KEY,
    nombre           VARCHAR(100) NOT NULL,
    canal            VARCHAR(20) NOT NULL CHECK (canal IN ('email', 'whatsapp')),
    contenido        TEXT NOT NULL
);

CREATE TABLE notificacion_enviada (
    id_notificacion      SERIAL PRIMARY KEY,
    id_orden_produccion  INTEGER REFERENCES orden_produccion(id_orden_produccion) ON DELETE SET NULL,
    id_pedido            INTEGER REFERENCES pedido(id_pedido) ON DELETE SET NULL,
    id_plantilla         INTEGER NOT NULL REFERENCES plantilla_mensaje(id_plantilla),
    canal                VARCHAR(20) NOT NULL,
    estado_envio         VARCHAR(20) NOT NULL DEFAULT 'pendiente'
                         CHECK (estado_envio IN ('pendiente', 'enviada', 'fallida')),
    fecha_envio          TIMESTAMP
);

-- =====================================================================
-- Índices de soporte para las consultas más frecuentes
-- =====================================================================
CREATE INDEX idx_producto_categoria        ON producto(id_categoria);
CREATE INDEX idx_pedido_cliente            ON pedido(id_cliente);
CREATE INDEX idx_detalle_pedido_pedido     ON detalle_pedido(id_pedido);
CREATE INDEX idx_orden_estado              ON orden_produccion(estado);
CREATE INDEX idx_orden_fecha_estimada      ON orden_produccion(fecha_estimada_entrega);
CREATE INDEX idx_historial_orden           ON historial_estado_orden(id_orden_produccion);
CREATE INDEX idx_interaccion_cliente       ON interaccion_cliente(id_cliente);
CREATE INDEX idx_interaccion_producto      ON interaccion_cliente(id_producto);
CREATE INDEX idx_prediccion_categoria      ON prediccion_demanda(id_categoria);
CREATE INDEX idx_notificacion_estado       ON notificacion_enviada(estado_envio);

-- =====================================================================
-- Datos semilla mínimos (configuración inicial)
-- =====================================================================
INSERT INTO capacidad_produccion (max_ordenes_simultaneas, max_ordenes_semana)
VALUES (8, 15);

INSERT INTO categoria_producto (nombre, tiempo_estimado_min_dias, tiempo_estimado_max_dias)
VALUES
    ('Cajas artesanales', 3, 5),
    ('Ramos de flores artificiales', 10, 15);

COMMIT;
