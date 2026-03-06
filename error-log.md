1. Giá âm (vi phạm CHECK (price > 0))

ERROR:  new row for relation "products" violates check constraint "products_price_check"
Failing row contains (11, Test Negative Price, -100.00, 10, 2026-03-06 09:52:35.410886).
Giai thich : price > 0

2. Name = NULL (vi phạm NOT NULL)
ERROR:  null value in column "name" of relation "products" violates not-null constraint
giai thich: ten ko duoc null

3.Trùng ID (vi phạm PRIMARY KEY)
ERROR:  duplicate key value violates unique constraint "products_pkey"

giai thich: id la Primary Key nen ko duoc trung