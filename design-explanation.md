# Design Explanation — E-commerce Database

---

## 1. Vì sao cần Foreign Key?

Foreign Key (FK) đảm bảo **referential integrity** (toàn vẹn tham chiếu):
dữ liệu ở bảng con phải trỏ đến bản ghi thực sự tồn tại ở bảng cha.

**Nếu không có FK:**
```sql
-- Có thể insert order với user_id không tồn tại
INSERT INTO orders (user_id, status, total_amount)
VALUES (99999, 'pending', 500000);  -- user 99999 không có trong users!

-- Có thể xóa user trong khi họ còn đơn hàng
DELETE FROM users WHERE id = 1;
-- → orders.user_id = 1 vẫn còn đó, nhưng user đã biến mất
-- → "Orphan data" — dữ liệu mồ côi, không join được, gây bug
```

**Với FK:**
```sql
-- Cả hai thao tác trên đều bị database TỰ ĐỘNG chặn với lỗi rõ ràng
-- Code có thể có bug, nhưng database không cho phép dữ liệu sai tồn tại
```

**Quyết định ON DELETE trong project này:**

| FK | Chiến lược | Lý do |
|----|-----------|-------|
| `orders.user_id → users.id` | `RESTRICT` | Không cho xóa user khi còn đơn hàng. Bảo toàn lịch sử mua hàng. |
| `order_items.order_id → orders.id` | `CASCADE` | Xóa order thì xóa luôn items. Items không có ý nghĩa khi order đã xóa. |
| `order_items.product_id → products.id` | `RESTRICT` | Không cho xóa product đã từng được đặt. Cần giữ để tra cứu lịch sử. |

---

## 2. Vì sao order_items lưu `unit_price` riêng? (Snapshot Price)

Giá sản phẩm trong bảng `products` **thay đổi theo thời gian**: tăng giá,
giảm giá, khuyến mãi, ngừng kinh doanh.

**Sai — join trực tiếp vào `products.price` khi tính lại:**
```sql
-- Tháng 1: user đặt hàng khi price = 1.200.000
-- Tháng 3: admin nâng giá lên 1.500.000
-- Khi xem lại hóa đơn tháng 1:
SELECT oi.quantity * p.price AS subtotal   -- = 1.500.000 ← SAI!
FROM   order_items oi
JOIN   products p ON p.id = oi.product_id;
-- Hóa đơn bị sai, khách hàng khiếu nại, kế toán sai số liệu
```

**Đúng — dùng `unit_price` đã snapshot:**
```sql
-- unit_price được lưu tại thời điểm đặt hàng = 1.200.000
SELECT oi.quantity * oi.unit_price AS subtotal  -- = 1.200.000 ← ĐÚNG
FROM   order_items oi;
-- Hóa đơn luôn chính xác, bất kể giá thay đổi bao nhiêu lần sau đó
```

**Nguyên tắc:** Hóa đơn là bằng chứng pháp lý. Nó phải bất biến sau khi tạo.

---

## 3. Vì sao cần Transaction?

Transaction đảm bảo **tính ACID** — đặc biệt quan trọng khi đặt hàng
vì một lần đặt hàng gồm nhiều bước phải thành công hoặc thất bại cùng nhau.

| Thuộc tính | Ý nghĩa trong đặt hàng |
|-----------|----------------------|
| **Atomicity** | Kiểm tra stock + tạo order + tạo items + trừ stock là một khối. Nếu bước 3 lỗi, bước 1–2 phải được hoàn tác. |
| **Consistency** | Database luôn ở trạng thái hợp lệ: stock không âm, order luôn có items. |
| **Isolation** | Hai transaction đồng thời không ảnh hưởng lẫn nhau (xem thêm phần Oversell). |
| **Durability** | Sau COMMIT, dữ liệu an toàn dù server crash ngay sau đó. |

**Ví dụ không có transaction:**
```
Bước 1: Tạo order  ← OK
Bước 2: Tạo items  ← OK
Bước 3: Trừ stock  ← SERVER CRASH!
→ Order tồn tại, items tồn tại, nhưng stock chưa bị trừ → kho sai!
```

**Với transaction:**
```
Bước 1: Tạo order  ← OK (chưa lưu)
Bước 2: Tạo items  ← OK (chưa lưu)
Bước 3: Trừ stock  ← SERVER CRASH!
→ Toàn bộ ROLLBACK → database sạch, không có dữ liệu nửa vời
```

---

## 4. Vì sao cần Index?

Index là cấu trúc dữ liệu B-Tree giúp database tìm kiếm theo `O(log n)`
thay vì scan toàn bộ bảng `O(n)`.

**Lưu ý quan trọng:**
> PostgreSQL **tự động** tạo index cho `PRIMARY KEY` và `UNIQUE`.
> PostgreSQL **KHÔNG tự động** tạo index cho `FOREIGN KEY`.
> Vì vậy các index cho FK column phải tạo thủ công.

**Tác động thực tế:**

| Index | Query được tối ưu | Không có index |
|-------|-----------------|---------------|
| `idx_users_email` | `WHERE email = ?` (đăng nhập) | Scan 1 triệu user mỗi lần login |
| `idx_orders_user_id` | `WHERE user_id = ?` (lịch sử đặt hàng) | Scan toàn bộ orders table |
| `idx_order_items_order_id` | `WHERE order_id = ?` (chi tiết đơn) | Scan toàn bộ order_items |
| `idx_order_items_product_id` | `WHERE product_id = ?` (báo cáo bán hàng) | Scan toàn bộ order_items |

**Đánh đổi:** Index tăng tốc SELECT nhưng làm chậm INSERT/UPDATE/DELETE
(phải cập nhật cả index). Chỉ tạo index cho các column thực sự hay dùng
trong WHERE, JOIN, ORDER BY.

---

## 5. Nếu bỏ constraint thì rủi ro gì?

| Constraint bị bỏ | Rủi ro cụ thể |
|-----------------|--------------|
| `NOT NULL email` | Tài khoản không có email → không thể đăng nhập, không gửi được email xác nhận đơn hàng |
| `UNIQUE email` | Hai người cùng email → cả hai đăng nhập được vào tài khoản của nhau |
| `CHECK (price > 0)` | Admin nhập nhầm giá âm → hệ thống trừ tiền khách hàng khi họ mua hàng |
| `CHECK (stock >= 0)` | Stock âm → báo cáo tồn kho sai, đặt hàng được sản phẩm không còn |
| `CHECK (quantity > 0)` | Order item với quantity = 0 → tổng tiền order sai, dữ liệu vô nghĩa |
| `FOREIGN KEY` | Orphan data → order trỏ đến user không tồn tại, không thể JOIN, gây bug khó debug |
| `NUMERIC(10,2)` (dùng FLOAT thay vào) | Sai số dấu phẩy động: 0.1 + 0.2 = 0.30000000000000004 → sai lệch tiền tệ |

**Nguyên tắc production:** Constraint là lớp bảo vệ cuối cùng.
Application code có thể có bug. Validation ở frontend có thể bị bypass.
Database constraint là thứ duy nhất không thể bị bỏ qua.

---

## 6. Xử lý Race Condition — Oversell (Production Mindset)

### Oversell là gì?

**Oversell** xảy ra khi nhiều user đồng thời mua cùng một sản phẩm
và số lượng tồn kho không đủ đáp ứng tất cả.

### Tại sao SELECT thông thường không đủ?

```
Thời điểm T1:  User A đọc stock = 1  → "còn hàng" → tiến hành
Thời điểm T1:  User B đọc stock = 1  → "còn hàng" → tiến hành  ← đồng thời!
Thời điểm T2:  User A UPDATE stock = stock - 1 = 0
Thời điểm T2:  User B UPDATE stock = stock - 1 = -1  ← Oversell! Stock âm!
```

Database cho phép điều này vì mỗi SELECT là snapshot độc lập
tại thời điểm đọc. Không có gì ngăn B đọc giá trị cũ của A.

### Giải pháp: Pessimistic Locking với `SELECT ... FOR UPDATE`

```sql
-- FOR UPDATE lock row ngay khi đọc
-- Mọi transaction khác cố đọc row này sẽ phải CHỜ

SELECT stock_quantity, price
FROM   products
WHERE  id = 3
FOR UPDATE;   -- ← Lock row này lại
```

```
Thời điểm T1:  User A: SELECT ... FOR UPDATE → giữ lock
Thời điểm T1:  User B: SELECT ... FOR UPDATE → BỊ BLOCK, phải chờ

Thời điểm T2:  User A: cập nhật stock = 0 → COMMIT → giải phóng lock
Thời điểm T2:  User B: lock được trao → đọc stock = 0
               User B: 0 < 1 (qty) → RAISE EXCEPTION → ROLLBACK
               → Không có oversell!
```

### Pessimistic vs Optimistic Locking

| | Pessimistic (`FOR UPDATE`) | Optimistic (`version` column) |
|-|--------------------------|------------------------------|
| **Cơ chế** | Lock row khi đọc | Không lock, kiểm tra lúc ghi |
| **Hiệu năng** | Chậm hơn (lock contention) | Nhanh hơn (không có lock) |
| **Độ phức tạp** | Đơn giản | Phức tạp hơn, cần retry logic |
| **Phù hợp khi** | Xung đột thường xuyên (flash sale) | Xung đột hiếm (đơn hàng bình thường) |

**Kết luận cho project này:** Dùng Pessimistic Locking (`FOR UPDATE`)
vì đơn giản, dễ hiểu, đủ dùng cho e-commerce cơ bản.
Nếu scale lên và cần xử lý flash sale với hàng nghìn request/giây,
cân nhắc chuyển sang Optimistic Locking hoặc Redis-based locking.
