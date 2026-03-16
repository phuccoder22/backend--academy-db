-- ============================================================
-- index.sql
-- Index tối ưu truy vấn — production-ready
-- ============================================================

-- QUAN TRỌNG:
-- PostgreSQL TỰ ĐỘNG tạo index cho PRIMARY KEY và UNIQUE constraint.
-- PostgreSQL KHÔNG tự tạo index cho FOREIGN KEY column.
-- => Các index dưới đây đều phải tạo thủ công.

-- ------------------------------------------------------------
-- Index 1: users.email
-- Dùng khi: đăng nhập (WHERE email = ?), kiểm tra trùng email
-- UNIQUE đã tự tạo index, nhưng khai báo rõ để tường minh
-- ------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email
    ON users(email);

-- ------------------------------------------------------------
-- Index 2: orders.user_id
-- Dùng khi: lấy lịch sử đơn hàng của một user
--   SELECT * FROM orders WHERE user_id = ? ORDER BY created_at DESC
-- ------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_orders_user_id
    ON orders(user_id);

-- ------------------------------------------------------------
-- Index 3: order_items.order_id
-- Dùng khi: lấy toàn bộ sản phẩm trong một đơn hàng
--   SELECT * FROM order_items WHERE order_id = ?
-- ------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_order_items_order_id
    ON order_items(order_id);

-- ------------------------------------------------------------
-- Index 4: order_items.product_id
-- Dùng khi: báo cáo sản phẩm bán chạy, kiểm tra trước khi xóa product
--   SELECT * FROM order_items WHERE product_id = ?
-- ------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_order_items_product_id
    ON order_items(product_id);

-- ------------------------------------------------------------
-- Index 5 (bonus production): composite index
-- Dùng khi: lấy đơn hàng mới nhất của user, sắp xếp theo thời gian
--   SELECT * FROM orders WHERE user_id = ? ORDER BY created_at DESC
-- Composite index phủ cả điều kiện lọc lẫn sắp xếp → chỉ cần 1 index scan
-- ------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_orders_user_created
    ON orders(user_id, created_at DESC);
