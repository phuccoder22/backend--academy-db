-- ============================================================
-- transaction-flow.sql
-- Luồng đặt hàng ACID + xử lý Oversell (Race Condition)
-- ============================================================

-- ============================================================
-- PHẦN 1: GIẢI THÍCH VẤN ĐỀ OVERSELL
-- ============================================================

-- Scenario không an toàn (KHÔNG dùng FOR UPDATE):
--
--   Thời điểm T1: User A đọc stock = 1  → thấy còn hàng → tiếp tục
--   Thời điểm T1: User B đọc stock = 1  → thấy còn hàng → tiếp tục  (đồng thời!)
--   Thời điểm T2: User A trừ stock → stock = 0
--   Thời điểm T2: User B trừ stock → stock = -1  ← OVERSELL! Dữ liệu sai!
--
-- Giải pháp: SELECT ... FOR UPDATE (Pessimistic Locking)
--   → Lock row lại ngay khi đọc
--   → User B phải CHỜ User A COMMIT/ROLLBACK xong mới được đọc
--   → Sau khi A commit: B đọc stock = 0 → phát hiện hết hàng → ROLLBACK

-- ============================================================
-- PHẦN 2: TRANSACTION FLOW ĐẶT HÀNG
-- Kịch bản: user_id=1 mua product_id=3 (Keychron K2, stock=1), qty=2
-- ============================================================

DO $$
DECLARE
    v_user_id    INT            := 1;
    v_product_id INT            := 3;
    v_qty        INT            := 2;
    v_stock      INT;
    v_price      NUMERIC(10, 2);
    v_order_id   INT;
BEGIN

    -- BƯỚC 1: Kiểm tra stock — FOR UPDATE để lock row ngay lập tức
    -- Mọi transaction khác cố đọc row này sẽ phải CHỜ
    SELECT stock_quantity, price
    INTO   v_stock, v_price
    FROM   products
    WHERE  id = v_product_id
    FOR UPDATE;

    -- BƯỚC 2: Validate — đủ hàng không?
    IF v_stock < v_qty THEN
        -- ROLLBACK tự động khi RAISE EXCEPTION trong DO block
        RAISE EXCEPTION
            'Không đủ tồn kho cho product_id=%. Còn: %, cần: %',
            v_product_id, v_stock, v_qty;
    END IF;

    -- BƯỚC 3: Tạo đơn hàng
    INSERT INTO orders (user_id, status, total_amount)
    VALUES (v_user_id, 'pending', v_price * v_qty)
    RETURNING id INTO v_order_id;

    -- BƯỚC 4: Tạo order_items — lưu SNAPSHOT GIÁ tại thời điểm này
    -- Không được dùng products.price khi tính lại sau này
    INSERT INTO order_items (order_id, product_id, quantity, unit_price)
    VALUES (v_order_id, v_product_id, v_qty, v_price);

    -- BƯỚC 5: Trừ stock
    UPDATE products
    SET    stock_quantity = stock_quantity - v_qty,
           updated_at     = NOW()
    WHERE  id = v_product_id;

    -- BƯỚC 6: Cập nhật trạng thái order
    UPDATE orders
    SET    status     = 'confirmed',
           updated_at = NOW()
    WHERE  id = v_order_id;

    RAISE NOTICE 'Đặt hàng thành công. order_id=%, total=%',
        v_order_id, v_price * v_qty;

EXCEPTION
    WHEN OTHERS THEN
        -- ROLLBACK toàn bộ: stock không bị trừ, order không được tạo
        -- PostgreSQL tự ROLLBACK khi có EXCEPTION trong DO block
        RAISE NOTICE 'Đặt hàng thất bại: %', SQLERRM;
        RAISE;  -- Re-throw để tầng trên biết lỗi
END $$;


-- ============================================================
-- PHẦN 3: DEMO RACE CONDITION — chạy đồng thời 2 session
-- ============================================================

-- === SESSION A (chạy trước, chưa COMMIT) ===
BEGIN;
    SELECT stock_quantity, price
    FROM   products
    WHERE  id = 3
    FOR UPDATE;          -- Lock row. Session B sẽ bị BLOCK tại đây

    -- ... xử lý tiếp ...
    -- COMMIT; hoặc ROLLBACK;


-- === SESSION B (chạy đồng thời) ===
BEGIN;
    SELECT stock_quantity, price
    FROM   products
    WHERE  id = 3
    FOR UPDATE;          -- BỊ BLOCK — phải chờ Session A kết thúc

    -- Sau khi A COMMIT: B đọc được stock mới (đã trừ)
    -- Nếu stock < qty → B sẽ ROLLBACK → không bị oversell


-- ============================================================
-- PHẦN 4: DEMO TRANSACTION THÀNH CÔNG
-- Kịch bản: user_id=2 mua product_id=2 (Chuột Logitech, stock=200), qty=1
-- ============================================================

BEGIN;

    -- Kiểm tra & lock
    SELECT stock_quantity, price
    INTO   /* v_stock, v_price */ /* thực tế dùng biến trong DO block */
    FROM   products
    WHERE  id = 2
    FOR UPDATE;

    -- Tạo order
    INSERT INTO orders (user_id, status, total_amount)
    VALUES (2, 'pending', 1200000.00);

    -- Tạo order_items với snapshot price
    INSERT INTO order_items (order_id, product_id, quantity, unit_price)
    VALUES (currval('orders_id_seq'), 2, 1, 1200000.00);

    -- Trừ stock
    UPDATE products
    SET    stock_quantity = stock_quantity - 1,
           updated_at     = NOW()
    WHERE  id = 2;

COMMIT;  -- Lưu toàn bộ. Giải phóng lock.

-- ============================================================
-- PHẦN 5: DEMO TRANSACTION THẤT BẠI (stock không đủ)
-- Kịch bản: user_id=3 mua product_id=3, qty=99 (stock chỉ còn 1 hoặc 0)
-- ============================================================

BEGIN;

    -- Giả sử sau các bước trên stock = 0
    -- FOR UPDATE lock row
    -- Kiểm tra: 0 < 99 → RAISE EXCEPTION

ROLLBACK;  -- Không có gì thay đổi. Stock giữ nguyên. Không có orphan order.
