-- PayFlow: esquema SQLite (21 tablas del diccionario de datos)
PRAGMA foreign_keys = ON;

-- ===================== CATALOGOS =====================
CREATE TABLE IF NOT EXISTS cat_estado_financiero (
    id_estado_financiero INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre TEXT NOT NULL UNIQUE,
    permite_gasto_operativo INTEGER NOT NULL,
    severidad INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS cat_estado_suscripcion (
    id_estado_suscripcion INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre TEXT NOT NULL UNIQUE,
    descripcion TEXT
);

CREATE TABLE IF NOT EXISTS cat_categoria_gasto (
    id_categoria INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre TEXT NOT NULL UNIQUE,
    prioridad INTEGER NOT NULL UNIQUE,
    permite_registro_manual INTEGER NOT NULL,
    activo INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS cat_tipo_movimiento (
    id_tipo_movimiento INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre TEXT NOT NULL UNIQUE,
    efecto_saldo TEXT NOT NULL CHECK (efecto_saldo IN ('A','C'))
);

CREATE TABLE IF NOT EXISTS cat_tipo_alerta (
    id_tipo_alerta INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre TEXT NOT NULL UNIQUE,
    severidad INTEGER NOT NULL,
    requiere_confirmacion INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS cat_tipo_suscripcion (
    id_tipo_suscripcion INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre TEXT NOT NULL UNIQUE
);

-- ===================== ENTIDADES =====================
CREATE TABLE IF NOT EXISTS usuario (
    id_usuario INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre_usuario TEXT NOT NULL UNIQUE,
    hash_contrasena TEXT NOT NULL,
    codigo_moneda TEXT NOT NULL DEFAULT 'MXN',
    activo INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS periodo (
    id_periodo INTEGER PRIMARY KEY AUTOINCREMENT,
    id_usuario INTEGER NOT NULL REFERENCES usuario(id_usuario),
    anio INTEGER NOT NULL,
    mes INTEGER NOT NULL CHECK (mes BETWEEN 1 AND 12),
    fecha_inicio TEXT NOT NULL,
    fecha_fin TEXT NOT NULL,
    presupuesto_mensual_total REAL NOT NULL CHECK (presupuesto_mensual_total >= 0),
    ahorro_objetivo REAL NOT NULL CHECK (ahorro_objetivo >= 0),
    ahorro_reservado REAL NOT NULL DEFAULT 0 CHECK (ahorro_reservado >= 0),
    saldo_disponible REAL NOT NULL DEFAULT 0,
    id_estado_financiero INTEGER REFERENCES cat_estado_financiero(id_estado_financiero),
    cerrado INTEGER NOT NULL DEFAULT 0,
    fecha_creacion TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS suscripcion (
    id_suscripcion INTEGER PRIMARY KEY AUTOINCREMENT,
    id_usuario INTEGER NOT NULL REFERENCES usuario(id_usuario),
    nombre TEXT NOT NULL,
    monto REAL NOT NULL CHECK (monto >= 0),
    id_tipo_suscripcion INTEGER NOT NULL REFERENCES cat_tipo_suscripcion(id_tipo_suscripcion),
    dia_cobro INTEGER NOT NULL CHECK (dia_cobro BETWEEN 1 AND 31),
    activa INTEGER NOT NULL DEFAULT 1,
    suspendida INTEGER NOT NULL DEFAULT 0,  -- AGREGADO: CU06 exige guardar la suspension por el usuario
    fecha_alta TEXT NOT NULL,
    fecha_baja TEXT,
    autocobro INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS suscripcion_periodo (
    id_suscripcion_periodo INTEGER PRIMARY KEY AUTOINCREMENT,
    id_suscripcion INTEGER NOT NULL REFERENCES suscripcion(id_suscripcion),
    id_periodo INTEGER NOT NULL REFERENCES periodo(id_periodo),
    monto_cobro REAL NOT NULL CHECK (monto_cobro >= 0),
    fecha_cobro_programada TEXT NOT NULL,
    id_estado_suscripcion INTEGER NOT NULL REFERENCES cat_estado_suscripcion(id_estado_suscripcion),
    fecha_cobro_real TEXT,
    intentos_cobro INTEGER NOT NULL DEFAULT 0 CHECK (intentos_cobro >= 0),
    UNIQUE (id_suscripcion, id_periodo)
);

CREATE TABLE IF NOT EXISTS bitacora_estado_suscripcion (
    id_bitacora INTEGER PRIMARY KEY AUTOINCREMENT,
    id_suscripcion_periodo INTEGER NOT NULL REFERENCES suscripcion_periodo(id_suscripcion_periodo),
    id_estado_anterior INTEGER NOT NULL REFERENCES cat_estado_suscripcion(id_estado_suscripcion),
    id_estado_nuevo INTEGER NOT NULL REFERENCES cat_estado_suscripcion(id_estado_suscripcion),
    fecha_hora TEXT NOT NULL,
    motivo TEXT
);

CREATE TABLE IF NOT EXISTS meta_ahorro (
    id_meta INTEGER PRIMARY KEY AUTOINCREMENT,
    id_usuario INTEGER NOT NULL REFERENCES usuario(id_usuario),
    nombre TEXT NOT NULL,
    monto_objetivo REAL NOT NULL CHECK (monto_objetivo >= 0),
    monto_acumulado REAL NOT NULL DEFAULT 0 CHECK (monto_acumulado >= 0),
    fecha_creacion TEXT NOT NULL,
    fecha_limite TEXT,
    activa INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS aportacion_ahorro (
    id_aportacion INTEGER PRIMARY KEY AUTOINCREMENT,
    id_periodo INTEGER NOT NULL REFERENCES periodo(id_periodo),
    id_meta INTEGER NOT NULL REFERENCES meta_ahorro(id_meta),
    monto REAL NOT NULL CHECK (monto >= 0),
    fecha_aportacion TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS limite_gasto (
    id_limite INTEGER PRIMARY KEY AUTOINCREMENT,
    id_usuario INTEGER NOT NULL REFERENCES usuario(id_usuario),
    id_categoria INTEGER NOT NULL REFERENCES cat_categoria_gasto(id_categoria),
    monto_minimo REAL NOT NULL CHECK (monto_minimo >= 0),
    monto_maximo REAL NOT NULL,
    activo INTEGER NOT NULL DEFAULT 1,
    CHECK (monto_maximo >= monto_minimo)
);

CREATE TABLE IF NOT EXISTS gasto_variable (
    id_gasto INTEGER PRIMARY KEY AUTOINCREMENT,
    id_periodo INTEGER NOT NULL REFERENCES periodo(id_periodo),
    id_categoria INTEGER NOT NULL REFERENCES cat_categoria_gasto(id_categoria),
    concepto TEXT NOT NULL,
    monto REAL NOT NULL CHECK (monto >= 0),
    fecha_gasto TEXT NOT NULL,
    fecha_registro TEXT NOT NULL,
    genera_advertencia INTEGER NOT NULL DEFAULT 0,
    id_suscripcion_periodo_riesgo INTEGER REFERENCES suscripcion_periodo(id_suscripcion_periodo)
);

CREATE TABLE IF NOT EXISTS presupuesto_categoria (
    id_presupuesto INTEGER PRIMARY KEY AUTOINCREMENT,
    id_periodo INTEGER NOT NULL REFERENCES periodo(id_periodo),
    id_categoria INTEGER NOT NULL REFERENCES cat_categoria_gasto(id_categoria),
    monto_asignado REAL NOT NULL CHECK (monto_asignado >= 0),
    monto_ejecutado REAL NOT NULL DEFAULT 0 CHECK (monto_ejecutado >= 0)
);

CREATE TABLE IF NOT EXISTS corte_caja (
    id_corte INTEGER PRIMARY KEY AUTOINCREMENT,
    id_periodo INTEGER NOT NULL UNIQUE REFERENCES periodo(id_periodo),
    fecha_hora TEXT NOT NULL,
    saldo_final REAL NOT NULL,
    total_proyectado REAL NOT NULL,
    total_ejecutado REAL NOT NULL,
    suscripciones_pagadas INTEGER NOT NULL CHECK (suscripciones_pagadas >= 0),
    suscripciones_no_pagadas INTEGER NOT NULL CHECK (suscripciones_no_pagadas >= 0),
    ahorro_cumplido INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS reporte_variabilidad_detalle (
    id_detalle INTEGER PRIMARY KEY AUTOINCREMENT,
    id_corte INTEGER NOT NULL REFERENCES corte_caja(id_corte),
    id_categoria INTEGER NOT NULL REFERENCES cat_categoria_gasto(id_categoria),
    monto_proyectado REAL NOT NULL,
    monto_ejecutado REAL NOT NULL,
    variacion REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS historial_estado_financiero (
    id_historial INTEGER PRIMARY KEY AUTOINCREMENT,
    id_periodo INTEGER NOT NULL REFERENCES periodo(id_periodo),
    id_estado INTEGER NOT NULL REFERENCES cat_estado_financiero(id_estado_financiero),
    fecha_hora TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS movimiento (
    id_movimiento INTEGER PRIMARY KEY AUTOINCREMENT,
    id_periodo INTEGER NOT NULL REFERENCES periodo(id_periodo),
    id_tipo_movimiento INTEGER NOT NULL REFERENCES cat_tipo_movimiento(id_tipo_movimiento),
    monto REAL NOT NULL,
    saldo_anterior REAL NOT NULL,
    saldo_posterior REAL NOT NULL,
    fecha_hora TEXT NOT NULL,
    descripcion TEXT,
    id_aportacion INTEGER REFERENCES aportacion_ahorro(id_aportacion),
    id_suscripcion_periodo INTEGER REFERENCES suscripcion_periodo(id_suscripcion_periodo),
    id_gasto INTEGER REFERENCES gasto_variable(id_gasto)
);

CREATE TABLE IF NOT EXISTS alerta (
    id_alerta INTEGER PRIMARY KEY AUTOINCREMENT,
    id_periodo INTEGER NOT NULL REFERENCES periodo(id_periodo),
    id_tipo_alerta INTEGER NOT NULL REFERENCES cat_tipo_alerta(id_tipo_alerta),
    mensaje TEXT NOT NULL,
    fecha_hora TEXT NOT NULL,
    atendida INTEGER NOT NULL DEFAULT 0,
    id_suscripcion_periodo INTEGER REFERENCES suscripcion_periodo(id_suscripcion_periodo),
    id_gasto INTEGER REFERENCES gasto_variable(id_gasto),
    id_aportacion INTEGER REFERENCES aportacion_ahorro(id_aportacion)
);

-- ===================== SEEDS DE CATALOGOS =====================
-- (se quita CONF_FONDOS: no se usa en ningun caso de uso)
INSERT OR IGNORE INTO cat_estado_financiero (id_estado_financiero, nombre, permite_gasto_operativo, severidad) VALUES
 (1,'ALERTA_DEFICIT',0,3),
 (2,'SALUDABLE',1,1),
 (3,'EN_RIESGO',1,2),
 (4,'CRITICO',1,3);

INSERT OR IGNORE INTO cat_estado_suscripcion (id_estado_suscripcion, nombre, descripcion) VALUES
 (1,'PENDIENTE','Alta o reinicio por Corte de Caja; espera su fecha de cobro'),
 (2,'PAGADA','Cobro confirmado internamente con saldo suficiente'),
 (3,'VENCIDA','Cobro rechazado por falta de saldo'),
 (4,'SUSPENDIDA','Suspendida por decision del usuario; no se cobra');

INSERT OR IGNORE INTO cat_categoria_gasto (id_categoria, nombre, prioridad, permite_registro_manual, activo) VALUES
 (1,'AHORRO',1,0,1),
 (2,'SUSCRIPCION',2,0,1),
 (3,'SERVICIOS',3,1,1),
 (4,'OCIO',4,1,1);

INSERT OR IGNORE INTO cat_tipo_movimiento (id_tipo_movimiento, nombre, efecto_saldo) VALUES
 (1,'ASIGNACION_PMT','A'),
 (2,'RESERVA_AHORRO','C'),
 (3,'COBRO_SUSCRIPCION','C'),
 (4,'GASTO_VARIABLE','C'),
 (5,'REVERSA','A');

-- RIESGO_OCIO y CORTE_EJECUTADO: valores ilegibles en el documento; estos son una propuesta
INSERT OR IGNORE INTO cat_tipo_alerta (id_tipo_alerta, nombre, severidad, requiere_confirmacion) VALUES
 (1,'DEFICIT',2,0),
 (2,'EN_RIESGO',3,1),
 (3,'CRITICO',3,1),
 (4,'COBRO_RECHAZADO',2,1),
 (5,'RIESGO_OCIO',2,1),
 (6,'CORTE_EJECUTADO',1,0);

INSERT OR IGNORE INTO cat_tipo_suscripcion (id_tipo_suscripcion, nombre) VALUES
 (1,'OCIO Y CONSUMO'),
 (2,'SERVICIOS Y HOGAR');
