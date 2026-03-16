-- ============================================================
-- schema.sql
-- E-commerce Database — Bảng đầy đủ, production-ready
-- ============================================================

-- Xóa nếu đã tồn tại (thứ tự quan trọng: con trước cha)
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders     CASCADE;
DROP TABLE IF EXISTS products   CASCADE;
DROP TABLE IF EXISTS users      CASCADE;

-- ============================================================
-- 1. USERS
-- ============================================================
CREATE TABLE users (
    id            SERIAL          PRIMARY KEY,
    email         VARCHAR(255)    NOT NULL,
    password_hash VARCHAR(255)    NOT NULL,
    full_name     VARCHAR(100)    NOT NULL,
    created_at    TIMESTAMP       NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMP       NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_users_email UNIQUE (email)
);

-- ============================================================
-- 2. PRODUCTS
-- ============================================================
CREATE TABLE products (
    id             SERIAL          PRIMARY KEY,
    name           VARCHAR(255)    NOT NULL,
    description    TEXT,
    price          NUMERIC(10, 2)  NOT NULL,
    stock_quantity INT             NOT NULL DEFAULT 0,
    created_at     TIMESTAMP       NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMP       NOT NULL DEFAULT NOW(),

    -- Dùng NUMERIC(10,2), tuyệt đối không dùng FLOAT cho tiền
    CONSTRAINT chk_products_price_positive     CHECK (price > 0),
    CONSTRAINT chk_products_stock_non_negative CHECK (stock_quantity >= 0)
);

-- ============================================================
-- 3. ORDERS
-- ============================================================
CREATE TABLE orders (
    id           SERIAL          PRIMARY KEY,
    user_id      INT             NOT NULL,
    status       VARCHAR(50)     NOT NULL DEFAULT 'pending',
    total_amount NUMERIC(10, 2)  NOT NULL DEFAULT 0,
    created_at   TIMESTAMP       NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMP       NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_orders_user
        FOREIGN KEY (user_id)
        REFERENCES users(id)
        ON DELETE RESTRICT   -- Không cho xóa user khi còn đơn hàng
        ON UPDATE CASCADE,

    CONSTRAINT chk_orders_status CHECK (
        status IN ('pending', 'confirmed', 'shipped', 'delivered', 'cancelled')
    ),

    CONSTRAINT chk_orders_total_non_negative CHECK (total_amount >= 0)
);

-- ============================================================
-- 4. ORDER_ITEMS
-- ============================================================
CREATE TABLE order_items (
    id         SERIAL          PRIMARY KEY,
    order_id   INT             NOT NULL,
    product_id INT             NOT NULL,
    quantity   INT             NOT NULL,
    unit_price NUMERIC(10, 2)  NOT NULL,  -- SNAPSHOT giá tại thời điểm đặt
    created_at TIMESTAMP       NOT NULL DEFAULT NOW(),
    -- Không có updated_at: order_items không được sửa sau khi tạo

    CONSTRAINT fk_order_items_order
        FOREIGN KEY (order_id)
        REFERENCES orders(id)
        ON DELETE CASCADE,    -- Xóa order → tự xóa items

    CONSTRAINT fk_order_items_product
        FOREIGN KEY (product_id)
        REFERENCES products(id)
        ON DELETE RESTRICT,   -- Không cho xóa product đã từng được đặt

    CONSTRAINT chk_order_items_quantity_positive  CHECK (quantity > 0),
    CONSTRAINT chk_order_items_unit_price_positive CHECK (unit_price > 0)
);
