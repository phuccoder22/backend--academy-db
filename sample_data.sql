-- ============================================================
-- sample_data.sql
-- Dữ liệu mẫu đủ để test mọi constraint và flow
-- ============================================================

-- Reset sequence nếu cần
TRUNCATE order_items, orders, products, users RESTART IDENTITY CASCADE;

-- ============================================================
-- USERS (3 người dùng)
-- password_hash = bcrypt của '123456' (chỉ để test)
-- ============================================================
INSERT INTO users (email, password_hash, full_name) VALUES
    ('alice@example.com', '$2b$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'Nguyễn Thị Alice'),
    ('bob@example.com',   '$2b$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'Trần Văn Bob'),
    ('carol@example.com', '$2b$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'Lê Thị Carol');

-- ============================================================
-- PRODUCTS (4 sản phẩm)
-- ============================================================
INSERT INTO products (name, description, price, stock_quantity) VALUES
    ('Laptop Dell XPS 15',   'Laptop cao cấp Intel Core i7, RAM 16GB, SSD 512GB', 25000000.00, 50),
    ('Chuột Logitech MX',    'Chuột không dây ergonomic, sạc USB-C',               1200000.00, 200),
    ('Bàn phím Keychron K2', 'Bàn phím cơ hot-swap 75%, switch Gateron Red',       2500000.00,   1),
    ('Tai nghe Sony WH1000', 'Chống ồn chủ động ANC, pin 30 giờ',                  8900000.00,  30);
-- Lưu ý: Keychron K2 chỉ còn stock = 1 → dùng để test oversell scenario

-- ============================================================
-- ORDERS + ORDER_ITEMS
-- Alice mua Laptop + Chuột (đã giao)
-- Bob mua Tai nghe (đang xử lý)
-- ============================================================
INSERT INTO orders (user_id, status, total_amount) VALUES
    (1, 'delivered', 26200000.00),  -- Alice: Laptop 25tr + Chuột 1.2tr
    (2, 'confirmed',  8900000.00);  -- Bob: Tai nghe 8.9tr

-- order_items cho order 1 (Alice)
-- unit_price = snapshot tại thời điểm đặt (không phụ thuộc products.price hiện tại)
INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
    (1, 1, 1, 25000000.00),
    (1, 2, 1,  1200000.00);

-- order_items cho order 2 (Bob)
INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
    (2, 4, 1, 8900000.00);

-- ============================================================
-- Test constraint: các dòng này SẼ báo lỗi (để verify constraint)
-- ============================================================

-- Test CHECK price <= 0 (sẽ lỗi):
-- INSERT INTO products (name, price, stock_quantity) VALUES ('Bad', -1000, 10);

-- Test CHECK quantity <= 0 (sẽ lỗi):
-- INSERT INTO order_items (order_id, product_id, quantity, unit_price)
-- VALUES (1, 2, 0, 1200000.00);

-- Test UNIQUE email (sẽ lỗi):
-- INSERT INTO users (email, password_hash, full_name)
-- VALUES ('alice@example.com', 'hash', 'Alice Clone');

-- Test FK user không tồn tại (sẽ lỗi):
-- INSERT INTO orders (user_id, status, total_amount) VALUES (9999, 'pending', 0);
