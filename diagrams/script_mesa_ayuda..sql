-- Base de datos para Mesa de Ayuda (Consúltenos)
-- Motor: PostgreSQL

-- 1. Catálogos y Mantenedores
CREATE TABLE perfiles (
    id_perfil SERIAL PRIMARY KEY,
    nombre_perfil VARCHAR(50) NOT NULL UNIQUE,
    descripcion VARCHAR(150)
);

CREATE TABLE areas (
    id_area SERIAL PRIMARY KEY,
    nombre_area VARCHAR(100) NOT NULL UNIQUE,
    estado_activo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE tipos_tique (
    id_tipo_tique SERIAL PRIMARY KEY,
    nombre_tipo VARCHAR(50) NOT NULL UNIQUE,
    estado_activo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE criticidades (
    id_criticidad SERIAL PRIMARY KEY,
    nivel_criticidad VARCHAR(30) NOT NULL UNIQUE,
    estado_activo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE estados_tique (
    id_estado SERIAL PRIMARY KEY,
    nombre_estado VARCHAR(30) NOT NULL UNIQUE
);

-- 2. Tabla de Usuarios
CREATE TABLE usuarios (
    id_usuario SERIAL PRIMARY KEY,
    rut_usuario VARCHAR(12) NOT NULL UNIQUE,
    nombre_completo VARCHAR(100) NOT NULL,
    correo VARCHAR(100) NOT NULL UNIQUE,
    clave_hash VARCHAR(255) NOT NULL,
    id_perfil INT NOT NULL,
    id_area INT,
    estado_activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_usuario_perfil FOREIGN KEY (id_perfil) REFERENCES perfiles(id_perfil),
    CONSTRAINT fk_usuario_area FOREIGN KEY (id_area) REFERENCES areas(id_area)
);

-- 3. Tabla de Clientes
CREATE TABLE clientes (
    id_cliente SERIAL PRIMARY KEY,
    rut_cliente VARCHAR(12) NOT NULL UNIQUE,
    nombre_completo VARCHAR(100) NOT NULL,
    telefono VARCHAR(20) NOT NULL,
    correo VARCHAR(100) NOT NULL
);

-- 4. Tabla Principal de Tiques
CREATE TABLE tiques (
    id_tique SERIAL PRIMARY KEY,
    codigo_tique VARCHAR(20) NOT NULL UNIQUE,
    id_cliente INT NOT NULL,
    id_tipo_tique INT NOT NULL,
    id_criticidad INT NOT NULL,
    id_area_destino INT NOT NULL,
    id_estado INT NOT NULL,
    id_usuario_creador INT NOT NULL,
    id_usuario_cierre INT,
    detalle_servicio VARCHAR(200) NOT NULL,
    detalle_problema TEXT NOT NULL,
    observacion_cierre TEXT,
    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_cierre TIMESTAMP,

    -- Claves foráneas e integridad
    CONSTRAINT fk_tique_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente),
    CONSTRAINT fk_tique_tipo FOREIGN KEY (id_tipo_tique) REFERENCES tipos_tique(id_tipo_tique),
    CONSTRAINT fk_tique_criticidad FOREIGN KEY (id_criticidad) REFERENCES criticidades(id_criticidad),
    CONSTRAINT fk_tique_area FOREIGN KEY (id_area_destino) REFERENCES areas(id_area),
    CONSTRAINT fk_tique_estado FOREIGN KEY (id_estado) REFERENCES estados_tique(id_estado),
    CONSTRAINT fk_tique_creador FOREIGN KEY (id_usuario_creador) REFERENCES usuarios(id_usuario),
    CONSTRAINT fk_tique_cierre FOREIGN KEY (id_usuario_cierre) REFERENCES usuarios(id_usuario),
    CONSTRAINT chk_fecha_cierre CHECK (fecha_cierre IS NULL OR fecha_cierre >= fecha_creacion)
);

-- 5. Poblado de Datos Iniciales
INSERT INTO perfiles (nombre_perfil, descripcion) VALUES
('Jefe de Mesa', 'Administrador global del sistema y catálogos'),
('Ejecutivo Mesa', 'Ingresa tiques y deriva a áreas específicas'),
('Ejecutivo Área', 'Resuelve tiques asignados a su departamento');

INSERT INTO estados_tique (nombre_estado) VALUES
('A resolución'),
('Resuelto'),
('No aplicable');

INSERT INTO tipos_tique (nombre_tipo) VALUES
('Felicitación'),
('Consulta'),
('Reclamo'),
('Problema');

INSERT INTO criticidades (nivel_criticidad) VALUES
('Baja'),
('Media'),
('Alta'),
('Crítica');

-- 6. Función y Trigger para Validar Cierre de Tiques
CREATE OR REPLACE FUNCTION validar_cierre_tique()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    nombre_estado_actual VARCHAR(30);
BEGIN
    SELECT nombre_estado INTO nombre_estado_actual
    FROM estados_tique
    WHERE id_estado = NEW.id_estado;

    -- Validaciones al pasar a un estado final
    IF nombre_estado_actual IN ('Resuelto', 'No aplicable') THEN
        IF NEW.observacion_cierre IS NULL OR TRIM(NEW.observacion_cierre) = '' THEN
            RAISE EXCEPTION 'La observación de cierre es obligatoria.';
        END IF;

        IF NEW.id_usuario_cierre IS NULL THEN
            RAISE EXCEPTION 'Debe registrarse el usuario que cierra el tique.';
        END IF;

        IF NEW.fecha_cierre IS NULL THEN
            NEW.fecha_cierre := CURRENT_TIMESTAMP;
        END IF;
    END IF;

    -- Limpieza en caso de reabrir el tique
    IF nombre_estado_actual = 'A resolución' THEN
        NEW.id_usuario_cierre := NULL;
        NEW.observacion_cierre := NULL;
        NEW.fecha_cierre := NULL;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validar_cierre_tique
BEFORE INSERT OR UPDATE ON tiques
FOR EACH ROW
EXECUTE FUNCTION validar_cierre_tique();