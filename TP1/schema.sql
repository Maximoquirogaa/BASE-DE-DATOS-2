-- Dominio cerrado para formas de pago
CREATE TYPE forma_pago AS ENUM ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA');

-- Tabla Categorías (R1, R7)
CREATE TABLE categorias (
    id_categoria BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE, -- R7: Baja lógica preferida antes que eliminación física
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Tabla Clientes (R2, R6)
CREATE TABLE clientes (
    id_cliente BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    correo_electronico VARCHAR(150) NOT NULL UNIQUE, -- R6: Clave candidata que identifica al cliente de forma única
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Tabla Productos (R1, R5, R7)
CREATE TABLE productos (
    id_producto BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_categoria BIGINT NOT NULL REFERENCES categorias(id_categoria) ON DELETE RESTRICT, 
    -- ON DELETE RESTRICT: Evita borrar físicamente una categoría si tiene productos, reforzando la regla R7 (baja lógica).
    nombre VARCHAR(150) NOT NULL,
    precio_actual DECIMAL(12,2) NOT NULL CHECK (precio_actual >= 0), -- R5: Precio no negativo
    stock INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0), -- R5: Stock no negativo
    activo BOOLEAN NOT NULL DEFAULT TRUE, -- R7: Baja lógica
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Tabla Pedidos (R2, R3)
CREATE TABLE pedidos (
    id_pedido BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_cliente BIGINT NOT NULL REFERENCES clientes(id_cliente) ON DELETE RESTRICT,
    -- ON DELETE RESTRICT: No se puede borrar físicamente un cliente si ya tiene un historial de pedidos asociados.
    forma_pago forma_pago NOT NULL,
    fecha_pedido TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Tabla intermedia Detalles de Pedido (R3, R4)
CREATE TABLE detalles_pedido (
    id_pedido BIGINT NOT NULL REFERENCES pedidos(id_pedido) ON DELETE CASCADE,
    -- ON DELETE CASCADE: Si se elimina un pedido (ej. cancelación inmediata y purga), sus líneas de detalle carecen de sentido y deben desaparecer.
    id_producto BIGINT NOT NULL REFERENCES productos(id_producto) ON DELETE RESTRICT,
    -- ON DELETE RESTRICT: Protege el historial (R4, R7). No se puede borrar físicamente un producto si alguna vez fue parte de un pedido.
    cantidad INTEGER NOT NULL CHECK (cantidad > 0), -- Validación extra: no se pueden pedir 0 o cantidades negativas
    precio_unitario DECIMAL(12,2) NOT NULL CHECK (precio_unitario >= 0), -- R4 y R5: Precio congelado al momento de compra
    PRIMARY KEY (id_pedido, id_producto)
);

-- Índices para optimizar consultas esperadas

-- 1. Acelera la búsqueda del historial de pedidos de un cliente en particular.
CREATE INDEX idx_pedidos_cliente ON pedidos(id_cliente);

-- 2. Acelera la carga de listados (ej. un catálogo web) filtrando rápidamente los productos que están vigentes por categoría.
CREATE INDEX idx_productos_activos_categoria ON productos(id_categoria) WHERE activo = TRUE;
