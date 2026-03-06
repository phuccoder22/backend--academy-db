CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    price NUMERIC(10,2) NOT NULL CHECK (price > 0),
    stock INTEGER NOT NULL CHECK (stock >= 0),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


INSERT INTO products (name, price, stock) VALUES
('Laptop Dell Inspiron 15', 1500.00, 10),
('iPhone 14 Pro', 1200.00, 15),
('Samsung Galaxy S23', 999.99, 20),
('Tai nghe Sony WH-1000XM5', 399.50, 25),
('Chuột Logitech MX Master 3', 120.75, 30);